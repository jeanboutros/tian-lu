#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# shellcheck disable=SC2034
readonly DEV_TWIN_NAME="${DEV_TWIN_NAME:-floci-dev}"
readonly DEV_DISK_NAME="${DEV_DISK_NAME:-floci-dev-data}"
readonly DEV_DISK_SIZE="${DEV_DISK_SIZE:-30GiB}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT
readonly DEV_TEMPLATE="${SCRIPT_DIR}/lima/floci-dev.yaml"
readonly DEV_GUEST_DATA_ROOT="/mnt/lima-floci-dev-data/floci-data"
readonly DEV_HOSTS_MARKER_BEGIN="# BEGIN tianlu-floci (managed by dev-twin.sh)"
readonly DEV_HOSTS_MARKER_END="# END tianlu-floci (managed by dev-twin.sh)"
readonly DEV_HOSTS_ENTRY="127.0.0.1 tianlu-floci"
readonly DEV_HEALTH_URL="http://tianlu-floci:4566/_floci/init"
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
    'findmnt -no FSTYPE,SOURCE /mnt/lima-floci-dev-data 2>/dev/null | grep -qE "^ext4 /dev/vd[a-z][0-9]+$"' 2>/dev/null
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

_wait_running() {
  local budget="$1" deadline s
  deadline=$((SECONDS + budget))
  while (( SECONDS < deadline )); do
    s="$(limactl list --format '{{.Name}} {{.Status}}' 2>/dev/null | awk -v n="$DEV_TWIN_NAME" '$1==n{print $2}')"
    if [[ "$s" == "Running" ]]; then
      return 0
    fi
    sleep "$DEV_POLL_INTERVAL"
  done
  printf 'ERROR: timeout: instance did not reach Running state\n' >&2
  return 1
}

_health_check() {
  local i code
  for ((i = 0; i < DEV_HEALTH_TRIES; i++)); do
    code="$(curl -sk --resolve tianlu-floci:4566:127.0.0.1 -o /dev/null -w "%{http_code}" "$DEV_HEALTH_URL" 2>/dev/null || echo "000")"
    if [[ "$code" == "200" ]]; then
      return 0
    fi
    sleep "$DEV_HEALTH_SLEEP"
  done
  printf 'ERROR: health: Floci did not return HTTP 200\n' >&2
  return 1
}

assert_preconditions() {
  local arch version major
  arch="$(uname -m)"
  if [[ "$arch" != "arm64" && "$arch" != "aarch64" ]]; then
    printf 'ERROR: preconditions: dev twin requires an arm64 host\n' >&2
    return 1
  fi
  if ! version="$(limactl --version 2>/dev/null)"; then
    printf 'ERROR: preconditions: limactl is unavailable\n' >&2
    return 1
  fi
  major="$(printf '%s\n' "$version" | sed -n 's/[^0-9]*\([0-9][0-9]*\).*/\1/p')"
  if [[ -z "$major" || "$major" -lt 2 ]]; then
    printf 'ERROR: preconditions: Lima 2.x is required\n' >&2
    return 1
  fi
  if ! command -v lsof >/dev/null 2>&1; then
    printf 'ERROR: preconditions: lsof is required\n' >&2
    return 1
  fi
  if ! limactl info 2>/dev/null | grep -qi qemu && ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
    printf 'ERROR: preconditions: Lima QEMU support is required\n' >&2
    return 1
  fi
}

_install_exec_condition() {
  local uid tmpfile
  uid="$(limactl shell "$DEV_TWIN_NAME" -- bash -c 'id -u floci 2>/dev/null' 2>/dev/null)"
  tmpfile="$(mktemp /tmp/exec-condition.XXXXXX)"
  printf '[Service]\nExecCondition=/bin/bash -c '"'"'findmnt -no FSTYPE,SOURCE /mnt/lima-floci-dev-data 2>/dev/null | grep -qE "^ext4 /dev/vd[a-z][0-9]+$"'"'"'\n' > "$tmpfile"
  limactl copy "$tmpfile" "$DEV_TWIN_NAME:/tmp/mount-condition.conf" 2>/dev/null
  limactl shell "$DEV_TWIN_NAME" -- bash -c 'sudo chmod 644 /tmp/mount-condition.conf' 2>/dev/null
  limactl shell "$DEV_TWIN_NAME" -- bash -c "sudo -u floci env HOME=/home/floci XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus bash -c 'mkdir -p /home/floci/.config/systemd/user/floci.service.d && cp /tmp/mount-condition.conf /home/floci/.config/systemd/user/floci.service.d/mount-condition.conf && systemctl --user daemon-reload'" 2>/dev/null
  rm -f "$tmpfile"
}

_start_service() {
  local uid
  uid="$(limactl shell "$DEV_TWIN_NAME" -- bash -c 'id -u floci 2>/dev/null' 2>/dev/null)"
  limactl shell "$DEV_TWIN_NAME" -- bash -c "sudo -u floci env HOME=/home/floci XDG_RUNTIME_DIR=/run/user/${uid} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus systemctl --user start floci.service" 2>/dev/null
}

_guest_ufw_baseline() {
  limactl shell "$DEV_TWIN_NAME" -- bash -c 'sudo ufw allow OpenSSH' 2>/dev/null
  limactl shell "$DEV_TWIN_NAME" -- bash -c 'sudo ufw default deny incoming' 2>/dev/null
  limactl shell "$DEV_TWIN_NAME" -- bash -c 'sudo ufw default allow outgoing' 2>/dev/null
  limactl shell "$DEV_TWIN_NAME" -- bash -c 'sudo ufw --force enable' 2>/dev/null
}

_install_absent() {
  local skip_preflight="${1:-}" rc
  if [[ "$skip_preflight" != "SKIP_PREFLIGHT" ]]; then
    preflight_ports || { printf 'ERROR: preflight: port check failed\n' >&2; return 1; }
  fi
  if dev_disk_exists; then
    :
  else
    rc=$?
    if [[ $rc -eq 1 ]]; then
      limactl disk create "$DEV_DISK_NAME" --size "$DEV_DISK_SIZE"
    else
      return 1
    fi
  fi
  limactl start --name="$DEV_TWIN_NAME" --set=".mounts[0].location=\"${REPO_ROOT}\"" --tty=false "$DEV_TEMPLATE"
  _wait_running "$DEV_START_BUDGET_FIRST"
  verify_disk_mount || { printf 'ERROR: disk-mount: /mnt/lima-floci-dev-data is not an ext4 mount on /dev/vd*\n' >&2; return 1; }
  limactl shell "$DEV_TWIN_NAME" -- bash -c 'sudo chmod 1777 /mnt/lima-floci-dev-data' 2>/dev/null
  if [[ "$(limactl shell "$DEV_TWIN_NAME" -- bash -c 'stat -c %a /mnt/lima-floci-dev-data 2>/dev/null' 2>/dev/null)" != "1777" ]]; then
    printf 'ERROR: disk-mount: mount root mode is not 1777\n' >&2
    return 1
  fi
  _guest_ufw_baseline
  limactl shell "$DEV_TWIN_NAME" -- sudo bash -c "cd / && FLOCI_HOST_PERSISTENT_PATH=$DEV_GUEST_DATA_ROOT FLOCI_TLS_ENABLED=false FLOCI_TLS_SELF_SIGNED=false bash /opt/tianlu/setup-floci.sh" 2>/dev/null
  _install_exec_condition
  managed_hosts_add
  _health_check
  dev_env
}

dev_up() {
  assert_identity
  assert_preconditions
  local state
  state="$(dev_instance_state)" || { printf 'ERROR: dev-up: failed to query instance state\n' >&2; return 1; }
  case "$state" in
    Running)
      managed_hosts_add
      _health_check
      ;;
    Stopped)
      preflight_ports || { printf 'ERROR: preflight: port check failed\n' >&2; return 1; }
      limactl start --tty=false "$DEV_TWIN_NAME"
      _wait_running "$DEV_START_BUDGET_RESUME"
      verify_disk_mount || { printf 'ERROR: disk-mount: /mnt/lima-floci-dev-data is not an ext4 mount on /dev/vd*\n' >&2; return 1; }
      _start_service
      managed_hosts_add
      _health_check
      ;;
    absent)
      _install_absent
      ;;
    *)
      printf 'ERROR: dev-up: instance is in state %s — run make dev-recreate or make dev-reset\n' "$state" >&2
      return 1
      ;;
  esac
}

dev_down() {
  assert_identity
  local state next
  state="$(dev_instance_state)" || { printf 'ERROR: dev-down: failed to query instance state\n' >&2; return 1; }
  case "$state" in
    Running)
      limactl stop "$DEV_TWIN_NAME"
      local deadline=$((SECONDS + DEV_STOP_BUDGET))
      while (( SECONDS < deadline )); do
        next="$(dev_instance_state 2>/dev/null || true)"
        [[ "$next" != "Running" ]] && printf 'Instance stopped\n' && return 0
        sleep "$DEV_POLL_INTERVAL"
      done
      printf 'instance did not stop within 30s\n' >&2
      return 1
      ;;
    Stopped|absent)
      printf 'Instance already stopped\n'
      ;;
    *)
      printf 'ERROR: dev-down: instance is in state %s — run make dev-recreate or make dev-reset\n' "$state" >&2
      return 1
      ;;
  esac
}

dev_status() {
  assert_identity
  local instance disk service code
  if instance="$(dev_instance_state 2>/dev/null)"; then :; else instance=unavailable; fi
  disk="$(dev_disk_state_safe)"
  printf 'instance: %s\n' "$instance"
  printf 'disk: %s\n' "$disk"
  if [[ "$instance" == "Running" ]]; then
    # SC2016: single quotes are intentional — $(id -u floci) must expand inside the guest, not on the host
    # shellcheck disable=SC2016
    service="$(limactl shell "$DEV_TWIN_NAME" -- bash -c 'sudo -u floci env HOME=/home/floci XDG_RUNTIME_DIR=/run/user/$(id -u floci) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u floci)/bus systemctl --user is-active floci.service 2>/dev/null' 2>/dev/null | head -1 || true)"
    [[ "$service" == "active" ]] || service=unavailable
    code="$(curl -sk --resolve tianlu-floci:4566:127.0.0.1 -o /dev/null -w "%{http_code}" "$DEV_HEALTH_URL" 2>/dev/null || echo 000)"
    [[ "$code" == "200" ]] && code=healthy || code=unavailable
  else
    service=unavailable
    code=unavailable
  fi
  printf 'service: %s\nhealth: %s\n' "$service" "$code"
}

dev_shell() {
  assert_identity
  assert_preconditions
  local state
  state="$(dev_instance_state)" || { printf 'ERROR: dev-shell: failed to query instance state\n' >&2; return 1; }
  case "$state" in
    absent) printf 'dev instance not found — run make dev-up first\n' >&2; return 1 ;;
    Stopped) printf 'dev instance is stopped — run make dev-up first\n' >&2; return 1 ;;
    Running) exec limactl shell "$DEV_TWIN_NAME" ;;
    *) printf 'ERROR: dev-shell: instance is in state %s\n' "$state" >&2; return 1 ;;
  esac
}

dev_recreate() {
  assert_identity
  assert_preconditions
  local state rc
  state="$(dev_instance_state)" || { printf 'ERROR: dev-recreate: failed to query instance state\n' >&2; return 1; }
  if [[ "$state" != "absent" ]]; then
    limactl stop "$DEV_TWIN_NAME" 2>/dev/null || true
    limactl delete -f "$DEV_TWIN_NAME" 2>/dev/null || true
  fi
  if dev_disk_exists; then
    :
  else
    rc=$?
    if [[ $rc -eq 1 ]]; then
      printf 'ERROR: dev-recreate: data disk missing — run make dev-up for a fresh environment\n' >&2
    fi
    return 1
  fi
  preflight_ports || { printf 'ERROR: preflight: port check failed\n' >&2; return 1; }
  _install_absent SKIP_PREFLIGHT
}

_disk_instance() {
  local out line instance
  out="$(limactl disk list --json 2>/dev/null)" || { printf 'ERROR: disk-query: failed to query disk state\n' >&2; return 1; }
  line="$(printf '%s\n' "$out" | grep -F '"name":"'"$DEV_DISK_NAME"'"' | head -1)"
  [[ -n "$line" ]] || { printf 'ERROR: disk-query: disk name not found in JSON output\n' >&2; return 1; }
  [[ "$line" == *'"instance"'* ]] || { printf 'ERROR: disk-query: instance field missing from JSON output — cannot safely determine attachment state\n' >&2; return 1; }
  instance="$(printf '%s\n' "$line" | sed -n 's/.*"instance":"\([^"]*\)".*/\1/p')"
  [[ -n "$instance" || "$line" == *'"instance":""'* ]] || {
    printf 'ERROR: disk-query: instance field could not be parsed\n' >&2
    return 1
  }
  printf '%s\n' "$instance"
}

dev_reset() {
  assert_identity
  confirm_reset
  local state attachment post rc
  state="$(dev_instance_state 2>/dev/null || true)"
  if [[ -n "$state" && "$state" != "absent" ]]; then
    limactl stop "$DEV_TWIN_NAME" 2>/dev/null || true
    limactl delete -f "$DEV_TWIN_NAME" 2>/dev/null || true
  fi
  if dev_disk_exists; then
    attachment="$(_disk_instance)" || return 1
    if [[ -n "$attachment" && "$attachment" != "$DEV_TWIN_NAME" ]]; then
      printf 'ERROR: disk-reset: disk attached to another instance — refusing to force-delete\n' >&2
      return 1
    fi
    if [[ "$attachment" == "$DEV_TWIN_NAME" ]]; then
      limactl disk unlock "$DEV_DISK_NAME"
      attachment="$(_disk_instance)" || return 1
      if [[ -n "$attachment" ]]; then
        printf 'ERROR: disk-reset: disk still locked — refusing to force-delete\n' >&2
        return 1
      fi
    fi
    limactl disk delete "$DEV_DISK_NAME"
    if ! post="$(limactl disk list --json 2>/dev/null)"; then
      printf 'ERROR: disk-delete: post-delete verification query failed\n' >&2
      return 1
    fi
    if printf '%s' "$post" | grep -qF '"name":"'"$DEV_DISK_NAME"'"'; then
      printf 'ERROR: disk-delete: disk still present after deletion\n' >&2
      return 1
    fi
  else
    rc=$?
    [[ $rc -eq 1 ]] || return 1
  fi
  managed_hosts_remove
  printf 'Environment reset complete.\n'
}

dev_env() {
  assert_identity
  local export_only=false aws_dir config_file creds_file
  [[ "${1:-}" == "--export" ]] && export_only=true
  aws_dir="${HOME}/.aws"
  config_file="${aws_dir}/config"
  creds_file="${aws_dir}/credentials"
  mkdir -p "$aws_dir"
  if ! grep -q '\[profile floci-dev\]' "$config_file" 2>/dev/null; then
    printf '\n[profile floci-dev]\nregion = eu-west-1\noutput = json\nca_bundle =\n' >> "$config_file"
  fi
  if ! grep -q '\[floci-dev\]' "$creds_file" 2>/dev/null; then
    printf '\n[floci-dev]\naws_access_key_id = test\naws_secret_access_key = test\n' >> "$creds_file"
  fi
  if "$export_only"; then
    printf 'export AWS_PROFILE=floci-dev\nexport AWS_ENDPOINT_URL=https://tianlu-floci:4566\nexport AWS_DEFAULT_REGION=eu-west-1\n'
  else
    # shellcheck disable=SC2016
    printf '\n# AWS CLI configured for floci-dev twin:\n# Profile "floci-dev" added to ~/.aws/config and ~/.aws/credentials\n#\n# To connect in this shell:\nexport AWS_PROFILE=floci-dev\nexport AWS_ENDPOINT_URL=https://tianlu-floci:4566\nexport AWS_DEFAULT_REGION=eu-west-1\n#\n# Or: eval "$(make dev-env -- --export)"\n'
  fi
}

main() {
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    unset DEV_HOSTS_FILE
    assert_identity
    local cmd="${1:-}"
    shift || true
    case "$cmd" in
      up) dev_up "$@" ;;
      down) dev_down "$@" ;;
      status) dev_status "$@" ;;
      shell) dev_shell "$@" ;;
      recreate) dev_recreate "$@" ;;
      reset) dev_reset "$@" ;;
      env) dev_env "$@" ;;
      '') printf 'Usage: dev-twin.sh <up|down|status|shell|recreate|reset|env>\n' >&2; return 1 ;;
      *) printf 'ERROR: unknown subcommand: %s\n' "$cmd" >&2; return 1 ;;
    esac
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
