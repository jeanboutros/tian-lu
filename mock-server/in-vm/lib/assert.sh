#!/usr/bin/env bash
# In-VM assertion and evidence helper library for the Lima digital-twin harness.
# Mirrors setup-floci.sh's run_as_floci privilege-drop pattern for guest use.
# Source this file from the guest driver; it defines helpers only and has no side effects.

set -euo pipefail
IFS=$'\n\t'

FAIL_REASON=""

# log <msg...>
# Print a timestamped message to stderr.
log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

# log_level <LEVEL> <msg...>
# Levelled colorized logger. Honors NO_COLOR and non-TTY stdout.
# Levels: INFO, WARN, PASS, FAIL. Color via tput; falls back to ANSI when
# tput is unavailable. NO_COLOR or non-TTY → plain "[LEVEL] msg".
log_level() {
  local level=${1-INFO}
  shift || true
  local msg=$*
  local color="" reset="" use_color=0

  if [[ -t 2 && -z "${NO_COLOR:-}" ]] && [[ "${CLICOLOR:-1}" != "0" ]]; then
    if command -v tput >/dev/null 2>&1 && tput setaf 0 >/dev/null 2>&1; then
      case "$level" in
        INFO) color=$(tput setaf 4 2>/dev/null || true) ;;
        WARN) color=$(tput setaf 3 2>/dev/null || true) ;;
        PASS) color=$(tput setaf 2 2>/dev/null || true) ;;
        FAIL) color=$(tput setaf 1 2>/dev/null || true) ;;
      esac
      reset=$(tput sgr0 2>/dev/null || true)
      if [[ -n "$color" ]]; then use_color=1; fi
    fi
  fi

  if (( use_color )); then
    printf '[%s] [%s] %s%s%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$color" "$msg" "$reset" >&2
  else
    printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$msg" >&2
  fi
}

# assert_eq <expected> <actual> <label>
# Compare two strings and record a failure reason on mismatch.
assert_eq() {
  local expected=${1-}
  local actual=${2-}
  local label=${3-}

  if [[ "$expected" != "$actual" ]]; then
    FAIL_REASON="FAILED ${label}: expected ${expected} got ${actual}"
    return 1
  fi

  return 0
}

# assert_contains <needle> <haystack> <label>
# Check whether a string contains another string.
assert_contains() {
  local needle=${1-}
  local haystack=${2-}
  local label=${3-}

  case "$haystack" in
    *"$needle"*)
      return 0
      ;;
    *)
      FAIL_REASON="FAILED ${label}: expected to contain ${needle} in ${haystack}"
      return 1
      ;;
  esac
}

# assert_http_200 <url> <label> <max_tries> <sleep_sec>
# Poll a URL until it returns HTTP 200 or the retry budget is exhausted.
assert_http_200() {
  local url=${1-}
  local label=${2-}
  local max_tries=${3-}
  local sleep_sec=${4-}
  local attempt=1
  local http_code

  while (( attempt <= max_tries )); do
    http_code="$(curl -sk --resolve tianlu-floci:4566:127.0.0.1 -o /dev/null -w '%{http_code}' "$url" || true)"
    if [[ "$http_code" == "200" ]]; then
      return 0
    fi

    if (( attempt < max_tries )); then
      sleep "$sleep_sec"
    fi

    attempt=$((attempt + 1))
  done

  FAIL_REASON="FAILED ${label}: expected HTTP 200 from ${url} after ${max_tries} tries"
  return 1
}

# redact_secret <text>
# Redact presign secrets from stdin and write the sanitized stream to stdout.
# Masks any FLOCI_AUTH_PRESIGN_SECRET=<value> occurrence (the value may be a
# 64-char hex secret or any non-whitespace token). Does NOT redact bare hex
# strings, which appear legitimately in evidence (sha256 digests, manifests).
redact_secret() {
  sed -E \
    -e 's/FLOCI_AUTH_PRESIGN_SECRET=[0-9a-fA-F]+/FLOCI_AUTH_PRESIGN_SECRET=REDACTED/g' \
    -e 's/FLOCI_AUTH_PRESIGN_SECRET=[^[:space:]]+/FLOCI_AUTH_PRESIGN_SECRET=REDACTED/g'
}

# snapshot_state <out_file>
# Capture a canonical state snapshot from the guest environment.
snapshot_state() {
  local out_file=${1-}

  {
    printf '### /etc/hosts managed block\n'
    awk '
      /^# BEGIN tianlu-floci \(managed by setup-floci.sh\)$/ { in_block = 1 }
      in_block { print }
      /^# END tianlu-floci \(managed by setup-floci.sh\)$/ { in_block = 0 }
    ' /etc/hosts
    printf '\n'

    printf '### /etc/subuid and /etc/subgid floci lines\n'
    grep '^floci:' /etc/subuid /etc/subgid 2>/dev/null || true
    printf '\n'

    printf '### ufw status numbered\n'
    ufw status numbered
    printf '\n'

    printf '### /etc/apparmor.d/podman-userns\n'
    if [[ -f /etc/apparmor.d/podman-userns ]]; then
      cat /etc/apparmor.d/podman-userns
    fi
    printf '\n'

    printf '### loginctl show-user floci -p Linger\n'
    loginctl show-user floci -p Linger
    printf '\n'

    printf '### run_as_floci_guest systemctl --user is-active floci.service\n'
    run_as_floci_guest systemctl --user is-active floci.service
    printf '\n'

    printf '### ownership and mode of key Floci paths\n'
    for _p in /home/floci /home/floci/floci-data /home/floci/floci.env /home/floci/.config/containers/systemd/floci.container; do
      if [[ -e "$_p" ]]; then
        stat -c '%n %a %U:%G' "$_p"
      else
        printf '%s NOT_FOUND\n' "$_p"
      fi
    done
    printf '\n'
  } >"$out_file"
}

# hash_state <file> <out_file>
# Write a sha256 digest line for a file unless it is a .bak file.
hash_state() {
  local file=${1-}
  local out_file=${2-}
  local sum

  if [[ "$file" == *.bak ]]; then
    return 0
  fi

  sum="$(sha256sum "$file" | awk '{print $1}')"
  printf '%s  %s\n' "$sum" "$(basename "$file")" >"$out_file"
}

# write_sentinel <path>
# Atomically write a DONE sentinel.
write_sentinel() {
  local path=${1-}

  printf 'DONE\n' >"${path}.tmp"
  mv -f "${path}.tmp" "$path"
}

# assert_pinned_user
# Assert the VM's Lima-pinned default user is floci-runner (uid 1001) and that
# no host-derived user exists in the non-system uid range 1000-65533.
# NOTE: this checks the PINNED USER IDENTITY (from floci-twin.yaml user:),
# NOT the driver's runtime user — the driver runs as root via
# `sudo systemd-run` (run-test.sh launch_driver), so `whoami` is always
# root here. Query getent passwd instead. Standalone so it can be unit-tested
# without pulling in all of step_preflight.
assert_pinned_user() {
  local expected_user="floci-runner"
  local expected_uid=1001
  local entry uid

  entry="$(getent passwd "$expected_user" 2>/dev/null || true)"
  if [[ -z "$entry" ]]; then
    FAIL_REASON="pinned-user: expected user ${expected_user} not present in /etc/passwd"
    return 1
  fi
  uid="$(printf '%s' "$entry" | cut -d: -f3)"
  if [[ "$uid" != "$expected_uid" ]]; then
    FAIL_REASON="pinned-user: ${expected_user} uid=${uid} expected ${expected_uid}"
    return 1
  fi

  local non_system_users
  non_system_users="$(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}')"
  local user_count
  user_count="$(printf '%s\n' "$non_system_users" | grep -c .)" 2>/dev/null || user_count=0
  if [[ "$user_count" -ne 1 || "$non_system_users" != "$expected_user" ]]; then
    FAIL_REASON="pinned-user: non-system users in uid 1000-65533: [${non_system_users}] expected only [${expected_user}]"
    return 1
  fi

  log "preflight: pinned-user=${expected_user}(uid ${uid}) ok"
  return 0
}

# run_as_floci_guest <cmd> [args...]
# Drop privileges to the floci user with the same env contract as setup-floci.sh.
# No trailing `--` before "$@": GNU coreutils 9.4 `env` treats
# `env VAR=val -- cmd` as if `--` were the command (it only accepts `--`
# before VAR=val assignments). The installer's run_as_floci has the same
# shape; the twin surfaces this as an installer bug to report, not patch.
run_as_floci_guest() {
  local uid

  uid="$(id -u floci)"
  sudo -u floci env \
    HOME=/home/floci \
    USER=floci \
    PATH=/usr/local/bin:/usr/bin:/bin \
    XDG_RUNTIME_DIR="/run/user/${uid}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
    "$@"
}

# main
# This library is sourceable; direct execution only prints a usage hint.
main() {
  : "${FAIL_REASON-}"
  printf 'assert.sh is a sourced library; source it instead of executing\n' >&2
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
