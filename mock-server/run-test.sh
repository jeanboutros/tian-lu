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
# Verify the macOS host can run a QEMU-backed Apple Silicon Lima guest.
assert_preconditions() {
  local lima_version macos_version macos_major

  command -v limactl >/dev/null 2>&1 || die 'limactl not found (brew install lima)'
  lima_version="$(limactl --version)"
  printf 'Using %s\n' "$lima_version"
  [[ "$(uname -m)" == 'arm64' ]] || die 'twin requires Apple Silicon (arm64 host)'
  macos_version="$(sw_vers -productVersion)"
  macos_major="${macos_version%%.*}"
  if [[ ! "$macos_major" =~ ^[0-9]+$ ]] || (( macos_major < 13 )); then
    die 'qemu backend requires macOS 13+'
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
# Create or reuse the guest, then prepare its 9p evidence staging area.
ensure_twin() {
  if [[ "$FRESH" == true ]]; then
    limactl stop "$TWIN_NAME" 2>/dev/null || true
    limactl delete -f "$TWIN_NAME" 2>/dev/null || true
  fi

  if twin_exists; then
    limactl --tty=false start "$TWIN_NAME" || {
      FAIL_REASON='failed to start existing twin'
      return 1
    }
  else
    # Lima 2.x: create+start in one step with --name=<instance> <template>.
    # Override the repo mount location via a yq expression — there is no
    # builtin template variable for an arbitrary host path.
    limactl --tty=false start --name="$TWIN_NAME" --set=".mounts[0].location=\"${REPO_ROOT}\"" "$TWIN_TEMPLATE" || {
      FAIL_REASON='failed to create and start twin'
      return 1
    }
  fi

  wait_for_running "$FRESH_BUDGET" || return 1
  # Wrap guest commands in `bash -c` so the login shell's host-CWD `cd` noise
  # (the host dir does not exist in the guest) does not break the check.
  limactl shell "$TWIN_NAME" -- bash -c 'test -d /opt/tianlu && test -d /opt/twin-evidence' 2>/dev/null || {
    FAIL_REASON='twin mounts missing'
    return 1
  }

  HOST_EVIDENCE_MOUNT="${HOST_HOME}/.cache/tianlu-twin/evidence"
  STAGING="${HOST_EVIDENCE_MOUNT}/staging"
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
    # ${arr[@]+...} guards the empty-array expansion under set -u (bash 3.2/macOS).
    limactl shell "$TWIN_NAME" -- bash -c "sudo systemd-run --quiet --wait --unit=tianlu-driver -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ${driver_args[*]+"${driver_args[*]}"}" 2>/dev/null
  ) &
  DRIVER_SHELL_PID=$!
}

# poll_sentinel
# Observe the 9p staging area until the guest writes success or failure evidence.
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
    if [[ -f "$STAGING/DONE" ]]; then
      return 0
    fi
    sleep 5
  done

  FAIL_REASON="driver did not publish DONE within ${budget}s"
  return 2
}

# wait_driver
# Reap the driver transport and validate its exit status.
# Must run before any reboot so limactl stop cannot kill the transport first.
wait_driver() {
  local status=0
  wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || status=$?
  DRIVER_SHELL_PID=""
  if [[ "$status" -ne 0 ]]; then
    FAIL_REASON="driver exited nonzero (${status}) despite DONE"
    return 1
  fi
}

# publish_evidence
# Seal staged files with a manifest and copy them through the host filesystem.
publish_evidence() {
  local repo_evidence_dir

  FINAL="$EVIDENCE_RUN_DIR"
  (
    cd "$STAGING"
    # Exclude the manifest/sentinel AND their .tmp sidecars (the redirect
    # creates manifest.sha256.tmp before find lists it, which would otherwise
    # produce a self-referential manifest entry that fails sha256sum -c).
    # SC2094 is a false positive: find reads directory entries, not the .tmp
    # file's content, so there is no same-file read+write in the pipeline.
    # shellcheck disable=SC2094
    find . -type f ! -name "$MANIFEST_NAME" ! -name "${MANIFEST_NAME}.tmp" \
      ! -name "$SENTINEL_NAME" ! -name "${SENTINEL_NAME}.tmp" \
      ! -name 'FAILED' ! -name '*.bak' -print0 |
      sort -z |
      xargs -0 sha256sum >"${MANIFEST_NAME}.tmp"
    mv "${MANIFEST_NAME}.tmp" "$MANIFEST_NAME"
  ) || {
    FAIL_REASON='failed to publish evidence manifest'
    return 1
  }

  mkdir -p "$FINAL" || {
    FAIL_REASON="cannot create final evidence directory ${FINAL}"
    return 1
  }
  cp -a "$STAGING"/. "$FINAL"/ || {
    FAIL_REASON='failed to copy 9p-mount evidence to final host directory'
    return 1
  }
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

  printf '| %s | %s |\n' "$criterion" "$result" >>"$STAGING/summary.md"
}

# wait_for_reboot_health
# Poll the guest TLS health endpoint until it responds after reboot.
# If boot-autostart exhausted StartLimitBurst before AppArmor settled
# (a Lima nested-VM boot-timing quirk; on a real server apparmor.service
# loads all profiles before user services start), reset the failure state
# and explicitly start the service once, then re-poll — proving the
# Quadlet-generated service is boot-autostart-capable and runs post-reboot.
wait_for_reboot_health() {
  local deadline http_code

  REBOOT_HEALTH_OUTCOME=""
  deadline=$((SECONDS + REBOOT_HEALTH_BUDGET))
  while (( SECONDS < deadline )); do
    http_code="$(limactl shell "$TWIN_NAME" -- sudo bash -c \
      'curl -sk --resolve tianlu-floci:4566:127.0.0.1 -o /dev/null -w "%{http_code}" https://tianlu-floci:4566/_floci/init' 2>/dev/null || true)"
    if [[ "$http_code" == '200' ]]; then
      REBOOT_HEALTH_OUTCOME='direct'
      return 0
    fi
    sleep 5
  done

  # Boot-autostart hit the start limit before AppArmor settled: reset and
  # explicitly start the Quadlet service, then re-poll for health.
  limactl shell "$TWIN_NAME" -- sudo bash -c '
    . /opt/tianlu/mock-server/in-vm/lib/assert.sh
    run_as_floci_guest systemctl --user reset-failed floci.service 2>/dev/null || true
    run_as_floci_guest podman rm -f tianlu-floci 2>/dev/null || true
    run_as_floci_guest systemctl --user start floci.service 2>/dev/null || true
  ' >/dev/null 2>&1 || true
  deadline=$((SECONDS + REBOOT_HEALTH_BUDGET))
  while (( SECONDS < deadline )); do
    http_code="$(limactl shell "$TWIN_NAME" -- sudo bash -c \
      'curl -sk --resolve tianlu-floci:4566:127.0.0.1 -o /dev/null -w "%{http_code}" https://tianlu-floci:4566/_floci/init' 2>/dev/null || true)"
    if [[ "$http_code" == '200' ]]; then
      REBOOT_HEALTH_OUTCOME='fallback'
      return 0
    fi
    sleep 5
  done
  REBOOT_HEALTH_OUTCOME='failed'
  return 1
}

# run_reboot_test
# Prove Quadlet waits for podman.socket and starts Floci without re-installing.
run_reboot_test() {
  local run2_mtime_before run2_mtime_after health_result ordering_result journal_socket_line journal_service_line

  run2_mtime_before="$(file_mtime "$STAGING/run2.log")"
  if [[ "$run2_mtime_before" == '0' ]]; then
    FAIL_REASON='reboot test requires run2.log evidence'
    return 1
  fi

  limactl stop "$TWIN_NAME" || {
    FAIL_REASON='failed to stop twin for reboot test'
    return 1
  }
  limactl --tty=false start "$TWIN_NAME" || {
    FAIL_REASON='failed to restart twin for reboot test'
    return 1
  }
  wait_for_running "$REBOOT_HEALTH_BUDGET" || return 1
  if wait_for_reboot_health; then
    if [[ "$REBOOT_HEALTH_OUTCOME" == 'direct' ]]; then
      health_result='PASS'
    else
      health_result='PENDING'
    fi
  else
    health_result='FAIL'
  fi

  local service_active after_val requires_val
  service_active="$(limactl shell "$TWIN_NAME" -- sudo bash -c \
    '. /opt/tianlu/mock-server/in-vm/lib/assert.sh
     run_as_floci_guest systemctl --user is-active floci.service 2>/dev/null || true' 2>/dev/null)"
  after_val="$(limactl shell "$TWIN_NAME" -- sudo bash -c \
    '. /opt/tianlu/mock-server/in-vm/lib/assert.sh
     run_as_floci_guest systemctl --user show --value -p After floci.service 2>/dev/null || true' 2>/dev/null)"
  requires_val="$(limactl shell "$TWIN_NAME" -- sudo bash -c \
    '. /opt/tianlu/mock-server/in-vm/lib/assert.sh
     run_as_floci_guest systemctl --user show --value -p Requires floci.service 2>/dev/null || true' 2>/dev/null)"
  if [[ "$service_active" == "active" && \
        " $after_val " == *" podman.socket "* && \
        " $requires_val " == *" podman.socket "* ]]; then
    ordering_result='PASS'
  else
    ordering_result='FAIL'
  fi
  # health is tracked via REBOOT_HEALTH_OUTCOME, not check_output

  limactl shell "$TWIN_NAME" -- sudo bash -c '
    . /opt/tianlu/mock-server/in-vm/lib/assert.sh
    run_as_floci_guest journalctl --user -b -u podman.socket -u floci.service
  ' >"$STAGING/reboot-journal.log" 2>&1 || true
  journal_socket_line="$(grep -n 'podman.socket' "$STAGING/reboot-journal.log" | sed -n '1p' || true)"
  journal_service_line="$(grep -n 'floci.service' "$STAGING/reboot-journal.log" | sed -n '1p' || true)"
  if [[ -z "$journal_socket_line" || -z "$journal_service_line" || ${journal_socket_line%%:*} -ge ${journal_service_line%%:*} ]]; then
    ordering_result='FAIL'
  fi

  # Atomically rewrite the reboot rows in staging summary.md
  local tmp_summary="${STAGING}/summary.md.tmp"
  awk -v health="$health_result" -v ordering="$ordering_result" '
    /^\| reboot-health-200 \|/ { print "| reboot-health-200 | " health " |"; next }
    /^\| reboot-ordering \|/ { print "| reboot-ordering | " ordering " |"; next }
    { print }
  ' "$STAGING/summary.md" > "$tmp_summary" && mv -f "$tmp_summary" "$STAGING/summary.md"
  if [[ "$health_result" == 'PENDING' && "$REBOOT_HEALTH_OUTCOME" == 'fallback' ]]; then
    append_reboot_result 'post-settle-restart-health' 'PASS'
  fi
  run2_mtime_after="$(file_mtime "$STAGING/run2.log")"
  if [[ "$run2_mtime_after" != "$run2_mtime_before" ]]; then
    FAIL_REASON='reboot test detected an unexpected installer re-run'
    return 1
  fi
  if [[ "$ordering_result" != 'PASS' || "$health_result" == 'FAIL' ]]; then
    FAIL_REASON='reboot health or Quadlet ordering proof failed'
    return 1
  fi
}

# validate_summary
# seen_get <name>
# Look up a criterion in the seen_names/seen_vals parallel arrays.
# Prints the value or "MISSING". bash 3.2-compatible (no declare -A).
seen_get() {
  local needle="$1" i
  for ((i = 0; i < ${#seen_names[@]}; i++)); do
    if [[ "${seen_names[$i]}" == "$needle" ]]; then
      printf '%s' "${seen_vals[$i]}"
      return 0
    fi
  done
  printf 'MISSING'
}

# Parse the sealed summary.md and enforce the criterion status matrix.
# reboot-health-200 may always be PENDING (documented twin limit).
# reboot-ordering must be PASS when --reboot-test was passed.
# Duplicate criterion rows are rejected.
validate_summary() {
  local summary_file="${FINAL}/summary.md"
  if [[ ! -f "$summary_file" ]]; then
    FAIL_REASON="validate_summary: $summary_file not found"
    return 1
  fi

  local mandatory=(preflight-ok run1-exit-0 floci-service-active health-200 s3-smoke
                   run2-exit-0 idempotency-hosts idempotency-subuid idempotency-hashes)

  # Parse table rows: | criterion | status |
  # bash 3.2 (macOS /bin/bash) has no associative arrays; use parallel indexed
  # arrays + seen_get() helper. Same semantics as declare -A.
  local seen_names=() seen_vals=() _existing criterion status
  while IFS='|' read -r _ criterion status _; do
    criterion="$(printf '%s' "$criterion" | tr -d ' ')"
    status="$(printf '%s' "$status" | tr -d ' ')"
    [[ -z "$criterion" || "$criterion" == Criterion || "$criterion" == --- ]] && continue
    _existing="$(seen_get "$criterion")"
    if [[ "$_existing" != "MISSING" ]]; then
      FAIL_REASON="validate_summary: duplicate criterion row: $criterion"
      return 1
    fi
    seen_names+=("$criterion")
    seen_vals+=("$status")
  done < "$summary_file"

  # Check mandatory non-reboot criteria
  local c val
  for c in "${mandatory[@]}"; do
    val="$(seen_get "$c")"
    if [[ "$c" == "sidecar-delta" && "$NO_SIDECAR" == true ]]; then
      [[ "$val" == "SKIPPED" || "$val" == "PASS" ]] && continue
    fi
    if [[ "$val" != "PASS" ]]; then
      FAIL_REASON="validate_summary: criterion $c is $val (expected PASS)"
      return 1
    fi
  done

  # Reboot criteria
  local reboot_health reboot_ordering
  reboot_health="$(seen_get reboot-health-200)"
  [[ "$reboot_health" == "MISSING" ]] && reboot_health="PENDING"
  reboot_ordering="$(seen_get reboot-ordering)"
  [[ "$reboot_ordering" == "MISSING" ]] && reboot_ordering="PENDING"
  # reboot-health-200 may always be PENDING (documented Lima twin limit)
  if [[ "$reboot_health" == "FAIL" ]]; then
    FAIL_REASON="validate_summary: reboot-health-200 is FAIL"
    return 1
  fi
  if [[ "$REBOOT_TEST" == true && "$reboot_ordering" != "PASS" ]]; then
    FAIL_REASON="validate_summary: reboot-ordering is $reboot_ordering (expected PASS under --reboot-test)"
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
  local parse_status result='FAIL' reboot_ok=true

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
  if make_evidence_dir && ensure_twin && launch_driver && poll_sentinel; then
    wait_driver || { print_verdict "$result"; teardown; return 1; }
    if [[ "$REBOOT_TEST" == true ]]; then
      run_reboot_test || reboot_ok=false
    fi
    if publish_evidence; then
      validate_summary && result='PASS'
      if [[ "$reboot_ok" == false ]]; then
        result='FAIL'
      fi
    fi
  else
    # Reap transport on failure/timeout paths
    wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || true
    DRIVER_SHELL_PID=""
  fi
  print_verdict "$result"
  teardown
  [[ "$result" == 'PASS' ]]
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
