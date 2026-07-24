#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# shellcheck disable=SC2034
readonly DEV_TWIN_NAME="${DEV_TWIN_NAME:-floci-dev}"
readonly DEV_DISK_NAME="${DEV_DISK_NAME:-floci-dev-data}"
readonly DEV_DISK_SIZE="${DEV_DISK_SIZE:-30GiB}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly DEV_TEMPLATE="${SCRIPT_DIR}/lima/floci-dev.yaml"
readonly DEV_GUEST_DATA_ROOT="/mnt/lima-floci-dev-data/floci-data"
readonly DEV_HOSTS_MARKER_BEGIN="# BEGIN tianlu-floci (managed by dev-twin.sh)"
readonly DEV_HOSTS_MARKER_END="# END tianlu-floci (managed by dev-twin.sh)"
readonly DEV_HOSTS_ENTRY="127.0.0.1 tianlu-floci"
readonly DEV_HEALTH_URL="https://tianlu-floci:4566/_floci/init"
readonly DEV_HEALTH_TRIES=30
readonly DEV_HEALTH_SLEEP=2
readonly DEV_START_BUDGET_FIRST=600
readonly DEV_START_BUDGET_RESUME=120
readonly DEV_STOP_BUDGET=30
readonly DEV_POLL_INTERVAL=5

assert_identity() {
  if [[ "${DEV_TWIN_NAME}" == "floci-twin" || "${DEV_DISK_NAME}" == "floci-twin-data" ]]; then
    printf 'ERROR: identity: DEV_TWIN_NAME or DEV_DISK_NAME matches a protected test resource\n' >&2
    return 1
  fi
}

expand_required_ports() {
  {
    printf '%s\n' 4566
    seq 6379 6399
    seq 7001 7099
    seq 5100 5199
    seq 6500 6599
    seq 9400 9499
    seq 2200 2299
    printf '%s\n' 9169
  } | sort -n
}

preflight_ports() {
  local lsof_err lsof_out lsof_rc=0 line port required conflicts
  lsof_err="$(mktemp /tmp/lsof-err.XXXXXX)"
  lsof_out="$(lsof -nP -iTCP -sTCP:LISTEN -F pn 2>"$lsof_err")" || lsof_rc=$?
  if [[ $lsof_rc -eq 1 ]]; then
    rm -f "$lsof_err"
    return 0
  fi
  if [[ $lsof_rc -ge 2 ]]; then
    printf 'ERROR: lsof: command failed: %s\n' "$(cat "$lsof_err")" >&2
    rm -f "$lsof_err"
    return 1
  fi
  rm -f "$lsof_err"
  required="$(expand_required_ports)"
  conflicts=""
  while IFS= read -r line; do
    if [[ "$line" == n* ]]; then
      port="${line##*:}"
      if printf '%s\n' "$required" | grep -qx "$port"; then
        conflicts="${conflicts}${port}\n"
      fi
    fi
  done <<< "$lsof_out"
  if [[ -n "$conflicts" ]]; then
    printf 'ERROR: preflight: port conflicts: %s\n' "$(printf '%b' "$conflicts" | sort -nu | tr '\n' ' ')" >&2
    return 1
  fi
}

dev_instance_state() {
  local out rc=0 line
  out="$(limactl list --format '{{.Name}} {{.Status}}' 2>/dev/null)" || rc=$?
  if [[ $rc -ne 0 ]]; then
    printf 'ERROR: limactl-list: failed to query instance state\n' >&2
    return 1
  fi
  while IFS= read -r line; do
    if [[ "$line" == "${DEV_TWIN_NAME} "* ]]; then
      printf '%s\n' "${line#* }"
      return 0
    fi
  done <<< "$out"
  printf 'absent\n'
}

dev_disk_exists() {
  local out rc=0
  out="$(limactl disk list --json 2>/dev/null)" || rc=$?
  if [[ $rc -ne 0 ]]; then
    printf 'ERROR: limactl-disk-list: failed to query disk state\n' >&2
    return 1
  fi
  printf '%s' "$out" | grep -qF "\"name\":\"${DEV_DISK_NAME}\""
}

dev_disk_state_safe() {
  local out
  if out="$(limactl disk list --json 2>/dev/null)"; then
    if printf '%s' "$out" | grep -qF "\"name\":\"${DEV_DISK_NAME}\""; then
      printf 'exists\n'
    else
      printf 'absent\n'
    fi
  else
    printf 'unavailable\n'
  fi
}

verify_disk_mount() {
  limactl shell "${DEV_TWIN_NAME}" -- bash -c \
    'findmnt -no FSTYPE,SOURCE /mnt/lima-floci-dev-data 2>/dev/null | grep -qE "^ext4 /dev/vd[a-z]+$"'
}

_validate_hosts_markers() {
  local file="$1" begin_count end_count begin_line end_line
  begin_count="$(grep -cF "$DEV_HOSTS_MARKER_BEGIN" "$file" 2>/dev/null || true)"
  end_count="$(grep -cF "$DEV_HOSTS_MARKER_END" "$file" 2>/dev/null || true)"
  if [[ $begin_count -eq 0 && $end_count -eq 0 ]]; then
    return 0
  fi
  if [[ $begin_count -eq 1 && $end_count -eq 1 ]]; then
    begin_line="$(grep -nF "$DEV_HOSTS_MARKER_BEGIN" "$file" | cut -d: -f1 | head -1)"
    end_line="$(grep -nF "$DEV_HOSTS_MARKER_END" "$file" | cut -d: -f1 | head -1)"
    if [[ $begin_line -lt $end_line ]]; then
      return 0
    fi
  fi
  printf 'ERROR: hosts: malformed managed marker block in %s — resolve manually\n' "$file" >&2
  return 1
}

_write_hosts_file() {
  local tmpfile="$1" hosts_file="$2"
  if [[ "$hosts_file" == "/etc/hosts" ]]; then
    sudo install -m 0644 -o root -g wheel "$tmpfile" "$hosts_file"
  else
    cp "$tmpfile" "$hosts_file"
  fi
}

managed_hosts_add() {
  local hosts_file="${DEV_HOSTS_FILE:-/etc/hosts}" current new_content tmpfile
  _validate_hosts_markers "$hosts_file"
  current="$(cat "$hosts_file" 2>/dev/null || true)"
  new_content="$(printf '%s\n' "$current" | awk \
    -v b="$DEV_HOSTS_MARKER_BEGIN" -v e="$DEV_HOSTS_MARKER_END" '
    { line=$0; sub(/\r$/, "", line) }
    line==b {inblock=1; next}
    line==e {inblock=0; next}
    inblock {next}
    {print}
  ')"
  new_content="$(printf '%s\n%s\n%s\n%s\n' "$new_content" \
    "$DEV_HOSTS_MARKER_BEGIN" "$DEV_HOSTS_ENTRY" "$DEV_HOSTS_MARKER_END")"
  tmpfile="$(mktemp /tmp/dev-twin-hosts.XXXXXX)"
  printf '%s\n' "$new_content" > "$tmpfile"
  if cmp -s "$tmpfile" "$hosts_file"; then
    rm -f "$tmpfile"
    return 0
  fi
  _write_hosts_file "$tmpfile" "$hosts_file"
  rm -f "$tmpfile"
}

managed_hosts_remove() {
  local hosts_file="${DEV_HOSTS_FILE:-/etc/hosts}" current new_content tmpfile
  _validate_hosts_markers "$hosts_file"
  current="$(cat "$hosts_file" 2>/dev/null || true)"
  new_content="$(printf '%s\n' "$current" | awk \
    -v b="$DEV_HOSTS_MARKER_BEGIN" -v e="$DEV_HOSTS_MARKER_END" '
    { line=$0; sub(/\r$/, "", line) }
    line==b {inblock=1; next}
    line==e {inblock=0; next}
    inblock {next}
    {print}
  ')"
  tmpfile="$(mktemp /tmp/dev-twin-hosts.XXXXXX)"
  printf '%s\n' "$new_content" > "$tmpfile"
  if cmp -s "$tmpfile" "$hosts_file"; then
    rm -f "$tmpfile"
    return 0
  fi
  _write_hosts_file "$tmpfile" "$hosts_file"
  rm -f "$tmpfile"
}

confirm_reset() {
  local is_tty=0 response="" rc=0 stdin_file timeout
  if [[ "${CONFIRM:-}" == "reset" ]]; then
    return 0
  fi
  if [[ "${DEV_CONFIRM_STDIN_TTY:-}" == "1" || ( -z "${DEV_CONFIRM_STDIN_TTY:-}" && -t 0 ) ]]; then
    is_tty=1
  fi
  if [[ $is_tty -eq 0 ]]; then
    printf 'dev-reset requires CONFIRM=reset in non-interactive mode\n' >&2
    return 1
  fi
  printf "This will permanently delete the floci-dev-data disk and all AWS state. Type 'reset' to confirm: "
  stdin_file="${DEV_CONFIRM_STDIN_FILE:-/dev/stdin}"
  timeout="${DEV_CONFIRM_READ_TIMEOUT:-30}"
  read -t "$timeout" -r response < "$stdin_file" || rc=$?
  if [[ $rc -gt 128 ]]; then
    printf 'confirmation timed out\n' >&2
    return 1
  elif [[ $rc -eq 1 && -z "$response" ]]; then
    printf 'confirmation required (EOF received)\n' >&2
    return 1
  elif [[ $rc -eq 0 && "$response" == "reset" ]]; then
    return 0
  fi
  printf 'confirmation did not match\n' >&2
  return 1
}

main() {
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    unset DEV_HOSTS_FILE
    assert_identity
    local cmd="${1:-}"
    case "$cmd" in
      '') printf 'Usage: dev-twin.sh <up|down|status|shell|recreate|reset|env>\n' >&2; return 1 ;;
      *) printf 'ERROR: unknown subcommand: %s\n' "$cmd" >&2; return 1 ;;
    esac
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
