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
