#!/usr/bin/env bash
# Drive setup-floci.sh inside the Lima Ubuntu guest and collect staged evidence.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=lib/assert.sh
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib/assert.sh"

EVIDENCE_HOST_DIR="${EVIDENCE_HOST_DIR:-/opt/twin-evidence}"
readonly REPO_MOUNT="${REPO_MOUNT:-/opt/tianlu}"
readonly SETUP_SCRIPT="${SETUP_SCRIPT:-${REPO_MOUNT}/setup-floci.sh}"
readonly HEALTH_TRIES="${HEALTH_TRIES:-30}"
readonly HEALTH_SLEEP="${HEALTH_SLEEP:-2}"
readonly HEALTH_URL="https://tianlu-floci:4566/_floci/init"
readonly FLOCI_ENV_FILE="/home/floci/.config/floci/floci.env"
readonly FLOCI_QUADLET_FILE="/home/floci/.config/containers/systemd/floci.container"
NO_SIDECAR=false
EVIDENCE_STAGING=""
EVENTS_PID=""
declare -A CRITERIA=(
  [preflight-ok]=FAIL
  [run1-exit-0]=FAIL
  [floci-service-active]=FAIL
  [health-200]=FAIL
  [s3-smoke]=FAIL
  [sidecar-delta]=FAIL
  [run2-exit-0]=FAIL
  [idempotency-hosts]=FAIL
  [idempotency-subuid]=FAIL
  [idempotency-hashes]=FAIL
  [reboot-health-200]=PENDING
  [reboot-ordering]=PENDING
)

# usage
# Print the accepted guest-driver arguments.
usage() {
  printf 'Usage: %s [--no-sidecar] [--evidence-dir=<path>]\n' "${0##*/}" >&2
}

# parse_args
# Parse host-orchestrator options before evidence staging is initialized.
parse_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --no-sidecar)
        NO_SIDECAR=true
        ;;
      --evidence-dir=*)
        EVIDENCE_HOST_DIR="${arg#--evidence-dir=}"
        if [[ -z "$EVIDENCE_HOST_DIR" ]]; then
          FAIL_REASON="usage: --evidence-dir requires a path"
          return 1
        fi
        ;;
      *)
        usage
        FAIL_REASON="usage: unknown argument ${arg}"
        return 1
        ;;
    esac
  done
}

# on_fail
# Write the driver failure marker without publishing a success sentinel.
on_fail() {
  local reason="${FAIL_REASON:-unexpected driver failure}"

  trap - ERR
  if [[ -n "$EVIDENCE_STAGING" ]]; then
    printf 'FAILED: %s\ntimestamp: %s\n' "$reason" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      >"$EVIDENCE_STAGING/FAILED"
  fi
  exit 1
}

# select_unprivileged_user
# Pick a conventional non-root account for the AppArmor negative probe.
select_unprivileged_user() {
  local candidate
  for candidate in nobody Daemon "${SUDO_USER:-}"; do
    if [[ -n "$candidate" ]] && id -u "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# step_preflight
# Confirm the VM exercises the installer's systemd, firewall, and AppArmor paths.
step_preflight() {
  local aa probe_user podman_command=podman

  systemctl is-system-running >/dev/null 2>&1 || systemctl is-active default.target >/dev/null 2>&1 || {
    FAIL_REASON="preflight: systemd not running"
    return 1
  }
  loginctl >/dev/null 2>&1 || {
    FAIL_REASON="preflight: loginctl"
    return 1
  }
  nft list ruleset >/dev/null 2>&1 || {
    FAIL_REASON="preflight: nftables"
    return 1
  }

  aa="$(aa-status 2>/dev/null || true)"
  printf '%s' "$aa" | grep -qiE 'apparmor module is loaded|profiles are loaded' || {
    FAIL_REASON="preflight: AppArmor not enabled"
    return 1
  }
  [[ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null || echo 0)" == "1" ]] || {
    FAIL_REASON="preflight: userns restriction not enforced"
    return 1
  }
  if probe_user="$(select_unprivileged_user)"; then
    sudo -u "$probe_user" unshare -rU true 2>/dev/null && {
      FAIL_REASON="preflight: userns negative probe succeeded (should fail)"
      return 1
    }
  else
    log "preflight: no non-root account available for userns negative probe"
  fi

  ! command -v "$podman_command" >/dev/null 2>&1 || {
    FAIL_REASON="preflight: podman-present"
    return 1
  }
  if grep -q podman-userns /sys/kernel/security/apparmor/profiles 2>/dev/null; then
    FAIL_REASON="preflight: podman-userns already installed"
    return 1
  fi

  printf 'PREFLIGHT OK\n' | tee "$EVIDENCE_STAGING/preflight.log"
  CRITERIA[preflight-ok]=PASS
}

# step_operator_prereqs
# Establish the UFW baseline that setup-floci.sh deliberately asserts.
step_operator_prereqs() {
  log "operator prereq: ufw allow OpenSSH"
  ufw allow OpenSSH
  log "operator prereq: ufw default deny incoming"
  ufw default deny incoming
  log "operator prereq: ufw default allow outgoing"
  ufw default allow outgoing
  log "operator prereq: ufw --force enable"
  ufw --force enable
}

# hash_floci_file
# Hash a floci-owned file without exposing its contents to root-owned evidence.
hash_floci_file() {
  local file=${1-}
  local out_file=${2-}

  run_as_floci_guest cat "$file" | sha256sum | awk -v name="${file##*/}" '{print $1 "  " name}' >"$out_file"
}

# step_run1
# Execute the first installation and prove the resulting Floci service is usable.
step_run1() {
  local rc svc image buckets

  # `sudo bash` rather than `sudo "$SETUP_SCRIPT"`: the repo is mounted
  # read-only via virtiofs and the file may not carry the executable bit.
  set +e
  sudo bash "$SETUP_SCRIPT" 2>&1 | tee "$EVIDENCE_STAGING/run1.log"
  rc=${PIPESTATUS[0]}
  set -e
  assert_eq "0" "$rc" "run1-exit"
  CRITERIA[run1-exit-0]=PASS

  svc="$(run_as_floci_guest systemctl --user is-active floci.service 2>/dev/null || true)"
  assert_eq "active" "$svc" "floci-service-active"
  CRITERIA[floci-service-active]=PASS

  image="$(run_as_floci_guest podman ps --filter name=tianlu-floci --format '{{.Image}}' 2>/dev/null || true)"
  assert_eq "docker.io/floci/floci:1.5.33-compat" "$image" "floci-image"

  assert_http_200 "$HEALTH_URL" "health-200" "$HEALTH_TRIES" "$HEALTH_SLEEP"
  CRITERIA[health-200]=PASS
  curl -sk --resolve tianlu-floci:4566:127.0.0.1 -o "$EVIDENCE_STAGING/health-init.json" "$HEALTH_URL" 2>/dev/null || true
  log "GAP-009 body captured"

  sleep 5
  run_as_floci_guest podman exec tianlu-floci aws --endpoint-url https://localhost:4566 --no-verify-ssl s3 mb s3://twin \
    2>&1 | tee -a "$EVIDENCE_STAGING/s3-smoke.log" || true
  buckets="$(run_as_floci_guest podman exec tianlu-floci aws --endpoint-url https://localhost:4566 --no-verify-ssl s3 ls \
    2>&1 | tee -a "$EVIDENCE_STAGING/s3-smoke.log")"
  assert_contains "twin" "$buckets" "s3-smoke"
  CRITERIA[s3-smoke]=PASS

  snapshot_state "$EVIDENCE_STAGING/snapshot-run1.txt"
  hash_floci_file "$FLOCI_ENV_FILE" "$EVIDENCE_STAGING/env-hash-run1.txt"
  hash_floci_file "$FLOCI_QUADLET_FILE" "$EVIDENCE_STAGING/quadlet-hash-run1.txt"
}

# step_sidecar
# Invoke an arm64 Lambda while recording create/start events before the invoke.
step_sidecar() {
  if [[ "$NO_SIDECAR" == true ]]; then
    CRITERIA[sidecar-delta]=SKIPPED
    return 0
  fi

  # Start the event stream before invocation so short-lived Lambda sidecars cannot race sampling.
  run_as_floci_guest podman events --filter event=create --filter event=start --format '{{json .}}' \
    >"$EVIDENCE_STAGING/podman-events.ndjson" &
  EVENTS_PID=$!

  # shellcheck disable=SC2016
  run_as_floci_guest podman exec tianlu-floci bash -c '
    set -e
    mkdir -p /tmp/lambda-test && cd /tmp/lambda-test
    printf "def handler(event, context):\n    return {\"ok\": True}\n" > handler.py
    python3 -c "import zipfile; z=zipfile.ZipFile(\"fn.zip\",\"w\"); z.write(\"handler.py\"); z.close()"
    aws --no-verify-ssl --endpoint-url https://localhost:4566 lambda create-function \
      --function-name twin-smoke --runtime python3.12 \
      --role arn:aws:iam::000000000000:role/lambda-role \
      --handler handler.handler --zip-file fileb://fn.zip || true
    aws --no-verify-ssl --endpoint-url https://localhost:4566 lambda invoke \
      --function-name twin-smoke /tmp/invoke-out.json
    grep -q "\"ok\".*true" /tmp/invoke-out.json
    cat /tmp/invoke-out.json
  ' >"$EVIDENCE_STAGING/invoke-out.json"

  sleep 5
  kill "$EVENTS_PID" 2>/dev/null || true
  EVENTS_PID=""
  if ! grep -q '"create"' "$EVIDENCE_STAGING/podman-events.ndjson" ||
    ! grep -q '"start"' "$EVIDENCE_STAGING/podman-events.ndjson" ||
    ! grep -qiE 'lambda|aws' "$EVIDENCE_STAGING/podman-events.ndjson"; then
    FAIL_REASON="sidecar: missing create/start event"
    return 1
  fi
  grep -q '"ok".*true' "$EVIDENCE_STAGING/invoke-out.json" || {
    FAIL_REASON="sidecar: invoke result mismatch"
    return 1
  }
  CRITERIA[sidecar-delta]=PASS
}

# step_semantic_convergence
# Re-run the installer and require canonical state and sensitive hashes to converge.
step_semantic_convergence() {
  local rc2 blocks su sg env_hash_run1 env_hash_run2 quadlet_hash_run1 quadlet_hash_run2

  # `sudo bash` rather than `sudo "$SETUP_SCRIPT"`: see step_run1 (ro mount).
  set +e
  sudo bash "$SETUP_SCRIPT" 2>&1 | tee "$EVIDENCE_STAGING/run2.log"
  rc2=${PIPESTATUS[0]}
  set -e
  assert_eq "0" "$rc2" "run2-exit-0"
  CRITERIA[run2-exit-0]=PASS

  snapshot_state "$EVIDENCE_STAGING/snapshot-run2.txt"
  diff -u "$EVIDENCE_STAGING/snapshot-run1.txt" "$EVIDENCE_STAGING/snapshot-run2.txt" \
    >"$EVIDENCE_STAGING/semantic-convergence-diff.txt" || true
  if [[ -s "$EVIDENCE_STAGING/semantic-convergence-diff.txt" ]]; then
    FAIL_REASON="semantic-convergence: snapshot differs"
    return 1
  fi

  blocks="$(awk '/^# BEGIN tianlu-floci/{c++} END{print c}' /etc/hosts)"
  assert_eq "1" "$blocks" "idempotency-hosts"
  CRITERIA[idempotency-hosts]=PASS
  su="$(grep -c '^floci:' /etc/subuid || true)"
  assert_eq "1" "$su" "idempotency-subuid"
  sg="$(grep -c '^floci:' /etc/subgid || true)"
  assert_eq "1" "$sg" "idempotency-subgid"
  CRITERIA[idempotency-subuid]=PASS

  hash_floci_file "$FLOCI_ENV_FILE" "$EVIDENCE_STAGING/env-hash-run2.txt"
  hash_floci_file "$FLOCI_QUADLET_FILE" "$EVIDENCE_STAGING/quadlet-hash-run2.txt"
  env_hash_run1="$(<"$EVIDENCE_STAGING/env-hash-run1.txt")"
  env_hash_run2="$(<"$EVIDENCE_STAGING/env-hash-run2.txt")"
  quadlet_hash_run1="$(<"$EVIDENCE_STAGING/quadlet-hash-run1.txt")"
  quadlet_hash_run2="$(<"$EVIDENCE_STAGING/quadlet-hash-run2.txt")"
  assert_eq "$env_hash_run1" "$env_hash_run2" "idempotency-env-hash"
  assert_eq "$quadlet_hash_run1" "$quadlet_hash_run2" "idempotency-quadlet-hash"
  CRITERIA[idempotency-hashes]=PASS
}

# write_summary
# Write the final staged criterion report after all other evidence is complete.
write_summary() {
  {
    printf '# Lima digital-twin evidence summary\n\n'
    printf '| Criterion | Status |\n| --- | --- |\n'
    printf '| preflight-ok | %s |\n' "${CRITERIA[preflight-ok]}"
    printf '| run1-exit-0 | %s |\n' "${CRITERIA[run1-exit-0]}"
    printf '| floci-service-active | %s |\n' "${CRITERIA[floci-service-active]}"
    printf '| health-200 | %s |\n' "${CRITERIA[health-200]}"
    printf '| s3-smoke | %s |\n' "${CRITERIA[s3-smoke]}"
    printf '| sidecar-delta | %s |\n' "${CRITERIA[sidecar-delta]}"
    printf '| run2-exit-0 | %s |\n' "${CRITERIA[run2-exit-0]}"
    printf '| idempotency-hosts | %s |\n' "${CRITERIA[idempotency-hosts]}"
    printf '| idempotency-subuid | %s |\n' "${CRITERIA[idempotency-subuid]}"
    printf '| idempotency-hashes | %s |\n' "${CRITERIA[idempotency-hashes]}"
    printf '| reboot-health-200 | %s |\n' "${CRITERIA[reboot-health-200]}"
    printf '| reboot-ordering | %s |\n' "${CRITERIA[reboot-ordering]}"
  } >"$EVIDENCE_STAGING/summary.md"
}

# step_evidence
# Collect redacted service, runtime, firewall, AppArmor, and platform evidence.
step_evidence() {
  run_as_floci_guest systemctl --user status floci.service >"$EVIDENCE_STAGING/service-status.txt" 2>&1 || true
  run_as_floci_guest journalctl --user -u floci.service >"$EVIDENCE_STAGING/service-journal.log" 2>&1 || true
  run_as_floci_guest podman ps -a >"$EVIDENCE_STAGING/podman-ps.txt" 2>&1 || true
  run_as_floci_guest podman images >"$EVIDENCE_STAGING/podman-images.txt" 2>&1 || true
  run_as_floci_guest podman info --format json >"$EVIDENCE_STAGING/podman-info.json" 2>&1 || true
  ufw status verbose >"$EVIDENCE_STAGING/ufw-status.txt" 2>&1 || true
  cp /etc/hosts "$EVIDENCE_STAGING/hosts.txt" 2>/dev/null || true
  run_as_floci_guest cat "$FLOCI_ENV_FILE" 2>/dev/null | redact_secret >"$EVIDENCE_STAGING/floci.env" || true
  run_as_floci_guest cat "$FLOCI_QUADLET_FILE" >"$EVIDENCE_STAGING/floci.container" 2>/dev/null || true
  cp /etc/subuid "$EVIDENCE_STAGING/subuid.txt" 2>/dev/null || true
  cp /etc/subgid "$EVIDENCE_STAGING/subgid.txt" 2>/dev/null || true
  aa-status >"$EVIDENCE_STAGING/aa-status.txt" 2>&1 || true
  cat /etc/apparmor.d/podman-userns >"$EVIDENCE_STAGING/podman-userns-profile.txt" 2>/dev/null || true
  cat /sys/kernel/security/apparmor/profiles >"$EVIDENCE_STAGING/apparmor-profiles.txt" 2>/dev/null || true
  uname -r >"$EVIDENCE_STAGING/uname-r.txt"
  uname -m >"$EVIDENCE_STAGING/uname-m.txt"
  lsb_release -a >"$EVIDENCE_STAGING/lsb-release.txt" 2>&1 || true
  run_as_floci_guest podman inspect tianlu-floci --format '{{.Architecture}}' >"$EVIDENCE_STAGING/floci-arch.txt" 2>&1 || true
  write_summary
}

# main
# Run each guest-driver stage in order, leaving publication to the host wrapper.
main() {
  parse_args "$@"
  EVIDENCE_STAGING="${EVIDENCE_HOST_DIR}/staging"
  mkdir -p "$EVIDENCE_STAGING"
  trap 'on_fail' ERR

  step_preflight
  step_operator_prereqs
  step_run1
  step_sidecar
  step_semantic_convergence
  step_evidence
  log "DRIVER COMPLETE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
