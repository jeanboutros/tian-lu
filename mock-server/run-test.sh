#!/usr/bin/env bash
# Build and drive the Lima digital twin from the macOS host.

set -euo pipefail
IFS=$'\n\t'

readonly TWIN_NAME="${TWIN_NAME:-floci-twin}"
readonly TWIN_TEMPLATE="${TWIN_TEMPLATE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lima/floci-twin.yaml}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
HOST_HOME="${HOME:-$(id -un)}"
readonly HOST_HOME
readonly EVIDENCE_DIR_ROOT="${EVIDENCE_DIR_ROOT:-${HOST_HOME}/.cache/tianlu-twin/evidence}"
FRESH=false
KEEP=true
DESTROY=false
NO_SIDECAR=false
REBOOT_TEST=false
EVIDENCE_DIR_OVERRIDE=""
readonly SENTINEL_NAME="DONE"
readonly MANIFEST_NAME="manifest.sha256"
readonly FRESH_BUDGET="${FRESH_BUDGET:-3600}"
readonly SERVICE_HEALTH_BUDGET="${SERVICE_HEALTH_BUDGET:-300}"
readonly REBOOT_HEALTH_BUDGET="${REBOOT_HEALTH_BUDGET:-300}"

EVIDENCE_RUN_DIR=""
HOST_EVIDENCE_MOUNT=""
STAGING=""
TS=""
FINAL=""
DRIVER_SHELL_PID=""
FAIL_REASON=""

# usage
# Print the host orchestrator command-line interface.
usage() {
  printf 'Usage: %s [--fresh|--keep] [--destroy] [--no-sidecar] [--reboot-test] [--evidence-dir=<path>]\n' "${0##*/}"
}

# die
# Stop before the twin lifecycle begins when the host cannot run it.
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# assert_preconditions
# Verify the macOS host can run a VZ-backed Apple Silicon Lima guest.
assert_preconditions() {
  local lima_version macos_version macos_major

  command -v limactl >/dev/null 2>&1 || die 'limactl not found (brew install lima)'
  lima_version="$(limactl --version)"
  printf 'Using %s\n' "$lima_version"
  [[ "$(uname -m)" == 'arm64' ]] || die 'twin requires Apple Silicon (arm64 host)'
  macos_version="$(sw_vers -productVersion)"
  macos_major="${macos_version%%.*}"
  if [[ ! "$macos_major" =~ ^[0-9]+$ ]] || (( macos_major < 13 )); then
    die 'vz backend requires macOS 13+'
  fi
}

# parse_args
# Parse lifecycle, evidence, and optional test controls.
parse_args() {
  local arg

  for arg in "$@"; do
    case "$arg" in
      --fresh)
        FRESH=true
        KEEP=false
        ;;
      --keep)
        if [[ "$FRESH" != true ]]; then
          KEEP=true
        fi
        ;;
      --destroy)
        DESTROY=true
        ;;
      --no-sidecar)
        NO_SIDECAR=true
        ;;
      --reboot-test)
        REBOOT_TEST=true
        ;;
      --evidence-dir=*)
        EVIDENCE_DIR_OVERRIDE="${arg#--evidence-dir=}"
        [[ -n "$EVIDENCE_DIR_OVERRIDE" ]] || {
          FAIL_REASON='usage: --evidence-dir requires a path'
          return 1
        }
        ;;
      --help|-h)
        usage
        return 2
        ;;
      *)
        usage >&2
        FAIL_REASON="usage: unknown argument ${arg}"
        return 1
        ;;
    esac
  done
}

# make_evidence_dir
# Allocate the timestamped host-side destination for this invocation.
make_evidence_dir() {
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  EVIDENCE_RUN_DIR="${EVIDENCE_DIR_OVERRIDE:-$EVIDENCE_DIR_ROOT}/${TS}"
  mkdir -p "$EVIDENCE_RUN_DIR" || {
    FAIL_REASON="cannot create evidence directory ${EVIDENCE_RUN_DIR}"
    return 1
  }
}

# twin_exists
# Return success only when Lima knows the named twin.
twin_exists() {
  limactl list "$TWIN_NAME" --format '{{.Name}}' 2>/dev/null | grep -Fxq "$TWIN_NAME"
}

# wait_for_running
# Wait for Lima to report the twin as Running within the supplied budget.
wait_for_running() {
  local budget=${1-} deadline status

  deadline=$((SECONDS + budget))
  while (( SECONDS < deadline )); do
    status="$(limactl list "$TWIN_NAME" --format '{{.Status}}' 2>/dev/null || true)"
    if [[ "$status" == 'Running' ]]; then
      return 0
    fi
    sleep 5
  done

  FAIL_REASON="twin did not reach Running within ${budget}s"
  return 1
}

# ensure_twin
# Create or reuse the guest, then prepare its virtiofs evidence staging area.
ensure_twin() {
  if [[ "$FRESH" == true ]]; then
    limactl stop "$TWIN_NAME" 2>/dev/null || true
    limactl delete -f "$TWIN_NAME" 2>/dev/null || true
  fi

  if twin_exists; then
    limactl start "$TWIN_NAME" || {
      FAIL_REASON='failed to start existing twin'
      return 1
    }
  else
    limactl start "$TWIN_NAME" "$TWIN_TEMPLATE" || {
      FAIL_REASON='failed to create and start twin'
      return 1
    }
  fi

  wait_for_running "$FRESH_BUDGET" || return 1
  limactl shell "$TWIN_NAME" -- test -d /opt/tianlu && test -d /opt/twin-evidence || {
    FAIL_REASON='twin mounts missing'
    return 1
  }

  HOST_EVIDENCE_MOUNT="${HOST_HOME}/.cache/tianlu-twin/evidence"
  STAGING="${HOST_EVIDENCE_MOUNT}.staging"
  mkdir -p "$HOST_EVIDENCE_MOUNT" || {
    FAIL_REASON="cannot create evidence mount ${HOST_EVIDENCE_MOUNT}"
    return 1
  }
  rm -rf "$STAGING"
  rm -f "${HOST_EVIDENCE_MOUNT}/$SENTINEL_NAME" "${HOST_EVIDENCE_MOUNT}/FAILED"
}

# launch_driver
# Start the guest driver in a transient unit so UFW cannot strand the test.
launch_driver() {
  local -a driver_args=()

  if [[ "$NO_SIDECAR" == true ]]; then
    driver_args+=(--no-sidecar)
  fi
  (
    limactl shell "$TWIN_NAME" -- sudo systemd-run --quiet --wait --unit=tianlu-driver -- \
      /opt/tianlu/mock-server/in-vm/run-in-vm.sh "${driver_args[@]}"
  ) &
  DRIVER_SHELL_PID=$!
}

# poll_sentinel
# Observe the virtiofs staging area until the guest writes success or failure evidence.
poll_sentinel() {
  local budget deadline

  budget="$SERVICE_HEALTH_BUDGET"
  if [[ "$FRESH" == true ]]; then
    budget="$FRESH_BUDGET"
  fi
  deadline=$((SECONDS + budget))
  while (( SECONDS < deadline )); do
    if [[ -f "$STAGING/FAILED" ]]; then
      FAIL_REASON="driver failed: $(<"$STAGING/FAILED")"
      return 1
    fi
    if [[ -f "$STAGING/summary.md" ]]; then
      sleep 3
      if [[ -f "$STAGING/summary.md" && ! -f "$STAGING/FAILED" ]]; then
        return 0
      fi
    fi
    sleep 5
  done

  FAIL_REASON="driver did not publish summary.md within ${budget}s"
  return 2
}

# publish_evidence
# Seal staged files with a manifest and copy them through the host filesystem.
publish_evidence() {
  local repo_evidence_dir

  FINAL="$EVIDENCE_RUN_DIR"
  (
    cd "$STAGING"
    find . -type f ! -name "$MANIFEST_NAME" ! -name "$SENTINEL_NAME" ! -name 'FAILED' ! -name '*.bak' -print0 |
      sort -z |
      xargs -0 sha256sum >"${MANIFEST_NAME}.tmp"
    mv "${MANIFEST_NAME}.tmp" "$MANIFEST_NAME"
    printf 'DONE\n' >"${SENTINEL_NAME}.tmp"
    mv "${SENTINEL_NAME}.tmp" "$SENTINEL_NAME"
  ) || {
    FAIL_REASON='failed to publish evidence manifest'
    return 1
  }

  mkdir -p "$FINAL" || {
    FAIL_REASON="cannot create final evidence directory ${FINAL}"
    return 1
  }
  cp -a "$STAGING"/. "$FINAL"/ || {
    FAIL_REASON='failed to copy virtiofs evidence to final host directory'
    return 1
  }
  wait "$DRIVER_SHELL_PID" 2>/dev/null || true
  DRIVER_SHELL_PID=""
  (
    cd "$FINAL"
    sha256sum -c "$MANIFEST_NAME"
  ) || {
    FAIL_REASON='evidence manifest validation failed'
    return 1
  }

  repo_evidence_dir="${REPO_ROOT}/mock-server/evidence/${TS}"
  mkdir -p "$repo_evidence_dir" || {
    FAIL_REASON="cannot create repository evidence directory ${repo_evidence_dir}"
    return 1
  }
  cp -a "$FINAL"/. "$repo_evidence_dir"/ || {
    FAIL_REASON='failed to copy evidence into repository convenience directory'
    return 1
  }
}

# file_mtime
# Read a file modification time across BSD and GNU stat implementations.
file_mtime() {
  stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1" 2>/dev/null || printf '0\n'
}

append_reboot_result() {
  local criterion=${1-} result=${2-}

  printf '| %s | %s |\n' "$criterion" "$result" >>"$FINAL/summary.md"
}

# wait_for_reboot_health
# Poll the guest TLS health endpoint until it responds after reboot.
wait_for_reboot_health() {
  local deadline http_code

  deadline=$((SECONDS + REBOOT_HEALTH_BUDGET))
  while (( SECONDS < deadline )); do
    http_code="$(limactl shell "$TWIN_NAME" -- sudo bash -c \
      'curl -sk --resolve tianlu-floci:4566:127.0.0.1 -o /dev/null -w "%{http_code}" https://tianlu-floci:4566/_floci/init' 2>/dev/null || true)"
    if [[ "$http_code" == '200' ]]; then
      return 0
    fi
    sleep 5
  done
  return 1
}

# run_reboot_test
# Prove Quadlet waits for podman.socket and starts Floci without re-installing.
run_reboot_test() {
  local run2_mtime_before run2_mtime_after check_output health_result ordering_result journal_socket_line journal_service_line

  run2_mtime_before="$(file_mtime "$FINAL/run2.log")"
  if [[ "$run2_mtime_before" == '0' ]]; then
    FAIL_REASON='reboot test requires run2.log evidence'
    return 1
  fi

  limactl stop "$TWIN_NAME" || {
    FAIL_REASON='failed to stop twin for reboot test'
    return 1
  }
  limactl start "$TWIN_NAME" || {
    FAIL_REASON='failed to restart twin for reboot test'
    return 1
  }
  wait_for_running "$REBOOT_HEALTH_BUDGET" || return 1
  if wait_for_reboot_health; then
    health_result='PASS'
  else
    health_result='FAIL'
  fi

  check_output="$(limactl shell "$TWIN_NAME" -- sudo bash -c '
    . /opt/tianlu/mock-server/in-vm/lib/assert.sh
    printf "service="; run_as_floci_guest systemctl --user is-active floci.service 2>/dev/null || true
    printf "health="; curl -sk --resolve tianlu-floci:4566:127.0.0.1 -o /dev/null -w "%{http_code}" https://tianlu-floci:4566/_floci/init || true
    printf "\nunit="; run_as_floci_guest systemctl --user show -p After -p Requires floci.service 2>/dev/null || true
  ' 2>&1 || true)"
  if [[ "$check_output" == *'service=active'* && "$check_output" == *'After='*'podman.socket'* && "$check_output" == *'Requires='*'podman.socket'* ]]; then
    ordering_result='PASS'
  else
    ordering_result='FAIL'
  fi
  if [[ "$check_output" != *'health=200'* ]]; then
    health_result='FAIL'
  fi

  limactl shell "$TWIN_NAME" -- sudo bash -c '
    . /opt/tianlu/mock-server/in-vm/lib/assert.sh
    run_as_floci_guest journalctl --user -b -u podman.socket -u floci.service
  ' >"$FINAL/reboot-journal.log" 2>&1 || true
  journal_socket_line="$(grep -n 'podman.socket' "$FINAL/reboot-journal.log" | sed -n '1p' || true)"
  journal_service_line="$(grep -n 'floci.service' "$FINAL/reboot-journal.log" | sed -n '1p' || true)"
  if [[ -z "$journal_socket_line" || -z "$journal_service_line" || ${journal_socket_line%%:*} -ge ${journal_service_line%%:*} ]]; then
    ordering_result='FAIL'
  fi

  append_reboot_result 'reboot-health-200' "$health_result"
  append_reboot_result 'reboot-ordering' "$ordering_result"
  run2_mtime_after="$(file_mtime "$FINAL/run2.log")"
  if [[ "$run2_mtime_after" != "$run2_mtime_before" ]]; then
    FAIL_REASON='reboot test detected an unexpected installer re-run'
    return 1
  fi
  if [[ "$health_result" != 'PASS' || "$ordering_result" != 'PASS' ]]; then
    FAIL_REASON='reboot health or Quadlet ordering proof failed'
    return 1
  fi
}

# teardown
# Destroy the twin only when explicitly requested.
teardown() {
  if [[ "$DESTROY" == true ]]; then
    limactl stop "$TWIN_NAME" 2>/dev/null || true
    limactl delete -f "$TWIN_NAME" 2>/dev/null || true
  elif [[ "$KEEP" == true ]]; then
    return 0
  fi
}

# print_verdict
# Emit the final machine-readable twin result.
print_verdict() {
  local result=${1-}

  if [[ "$result" == 'PASS' ]]; then
    printf 'TWIN: PASS\n'
  else
    printf 'TWIN: FAIL: %s\n' "${FAIL_REASON:-unspecified failure}" >&2
  fi
}

# main
# Execute the host lifecycle while preserving a verdict after every failure.
main() {
  local parse_status result='FAIL'

  if parse_args "$@"; then
    :
  else
    parse_status=$?
    if (( parse_status == 2 )); then
      return 0
    fi
    print_verdict "$result"
    return 1
  fi
  assert_preconditions
  if make_evidence_dir && ensure_twin && launch_driver && poll_sentinel && publish_evidence; then
    result='PASS'
    if [[ "$REBOOT_TEST" == true ]] && ! run_reboot_test; then
      result='FAIL'
    fi
  fi
  print_verdict "$result"
  teardown
  [[ "$result" == 'PASS' ]]
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
