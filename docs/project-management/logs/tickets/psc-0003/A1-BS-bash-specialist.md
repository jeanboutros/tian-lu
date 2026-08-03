# A1-BS: Bash Specialist Requirements — psc-0003

| Field | Value |
|-------|-------|
| Agent | bash-specialist |
| Timestamp | 2026-07-30T18:00:00Z |
| Step | A1-BS |
| Verdict | CONDITIONAL PASS |
| Severity | 8 |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A — Phase A | Requirements analysis only; no code changes produced |
| Typed enums / vocabulary types | N/A | Not applicable to bash scripting |
| Documentation on new public symbols | N/A | Not applicable to bash scripting |
| Spec/datasheet fidelity | PASS | All findings verified against bash manual, POSIX spec, and advisory evidence |
| Module boundary | PASS | Each finding scoped to the correct script file |
| Reserved/padding fields handled | N/A | Not applicable to bash scripting |
| No magic numbers in doc examples | PASS | Code sketches use named constants where applicable |
| Buffer safety | PASS | All proposed changes are safe string/array operations |
| AGENTS.md compliance | PASS | All proposals follow script conventions: `set -euo pipefail`, `readonly ${VAR:-default}`, idempotent functions |
| Conventional commit ready | N/A — Phase A | Requirements only; commits happen in Phase B |

## Bash Requirements Analysis

### SPEC-BS-001 — CH-AUTH-002: Rewrite §4.2 with `FLOCI_AUTH_UNSAFE_OVERRIDE` escape hatch

- **Script(s) affected:** `setup-floci.sh` (config block, lines ~60–170)
- **Current anti-pattern:** The `${VAR:-default}` form on individual auth sub-variables lets an exported sub-variable override the mode independently. Evidence (verified in advisory §Verification):
  ```
  FLOCI_AUTH_MODE=off FLOCI_AUTH_VALIDATE_SIGNATURES=true → signatures=true enforcement=false
  ```
  This is the forbidden `(signatures=on, enforcement=off)` state that auth plan §4.1:125 marks as *"worse than leaving both off"*. The `_auth_*` helper variables are left set in the shell after the case block and are not `readonly`, violating the AGENTS.md convention that all parameters are `readonly` in a single configuration block.

- **Required change with code sketch:**
  ```bash
  readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-sigv4}"
  case "$FLOCI_AUTH_MODE" in
    off)   _auth_on="false" ;;
    sigv4) _auth_on="true"  ;;
    *) printf 'ERROR: FLOCI_AUTH_MODE must be "off" or "sigv4" (got: %s)\n' "$FLOCI_AUTH_MODE" >&2
       exit 1 ;;
  esac
  if [[ "${FLOCI_AUTH_UNSAFE_OVERRIDE:-0}" == "1" ]]; then
    readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_auth_on}"
    readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-$_auth_on}"
  else
    readonly FLOCI_AUTH_VALIDATE_SIGNATURES="$_auth_on"
    readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="$_auth_on"
  fi
  unset _auth_on
  ```
  **Bash validation:** The `case` pattern is POSIX-compliant. The `[[ ]]` conditional is bash-specific but acceptable — the script already uses `[[ ]]` extensively and targets bash, not `/bin/sh`. The `${VAR:-default}` form on `FLOCI_AUTH_UNSAFE_OVERRIDE` is correct: it defaults to `0` (safe) when unset. The `unset _auth_on` at the end prevents the helper from leaking into the global namespace. The `readonly` declarations are placed after the conditional so both branches freeze their values.

- **Portability impact:** None. This is a bash script targeting bash 4+ (Ubuntu 24.04+). The `[[ ]]` and `${VAR:-default}` forms are standard bash. No bash 3.2 concerns — `setup-floci.sh` runs only on the Ubuntu guest, not on macOS.

- **Acceptance criteria:** Ticket item 2. Bats case proving the hole is closed: `FLOCI_AUTH_MODE=off` + `FLOCI_AUTH_VALIDATE_SIGNATURES=true` must yield `false` in the env file.

---

### SPEC-BS-002 — CH-AUTH-005: `|| delete_rc=$?` for delete under `set -e`

- **Script(s) affected:** `mock-server/dev-twin.sh` (new `_rotate_bootstrap_credentials` function, auth plan §6.5:454–464)
- **Current anti-pattern:**
  ```bash
  _run_as_floci_guest "podman exec … iam delete-access-key …"
  delete_rc=$?
  ```
  Under `errexit` (`set -e` at line 2 of `dev-twin.sh`), a bare simple command returning non-zero terminates the shell. `delete_rc=$?` is unreachable on precisely the path it exists to handle. The `if`/`&&`/`||`/`!` constructs are condition contexts that suppress `errexit`; a standalone call is not. [Spec: Bash manual, Section 4.3.1 "The Set Builtin", `-e` description]

- **Required change with code sketch:**
  ```bash
  delete_rc=0
  _run_as_floci_guest "podman exec … iam delete-access-key …" || delete_rc=$?
  ```
  The `||` operator creates a condition context — the right-hand side executes only on failure, and `errexit` does not fire because the entire `cmd || handler` is a conditional list. `delete_rc=0` initialises the variable so it is defined even if the command succeeds (the `||` branch is not taken, so `delete_rc` would otherwise be unset).

- **Portability impact:** None. `||` as a conditional list is POSIX-compliant and works identically in bash 3.2 through 5.x.

- **Acceptance criteria:** Ticket item 5. The delete-failure WARNING must actually print when the delete fails.

---

### SPEC-BS-003 — CH-AUTH-007: Atomic `.tmp+chmod+mv` for credential file; parse instead of `source`

- **Script(s) affected:** `mock-server/dev-twin.sh` (new `_rotate_bootstrap_credentials` function, auth plan §6.5:467–470; `dev_env` function, auth plan §6.6:501–509)
- **Current anti-pattern:**
  ```bash
  printf 'DEV_BOOTSTRAP_AKID=%s\nDEV_BOOTSTRAP_SECRET=%s\n' \
    "$DEV_BOOTSTRAP_AKID" "$DEV_BOOTSTRAP_SECRET" > "$DEV_CREDENTIALS_FILE"
  chmod 0600 "$DEV_CREDENTIALS_FILE"
  ```
  Two windows: (1) a crash mid-write leaves a truncated file, and (2) the file exists at umask permissions until the `chmod`. Additionally, `dev_env` uses `source "$DEV_CREDENTIALS_FILE"` which *executes* the file — a security risk if the file is ever corrupted or tampered with. `setup-floci.sh:822–841` already demonstrates the correct atomic pattern in this codebase.

- **Required change with code sketch:**
  ```bash
  # Write atomically: .tmp → chmod → mv
  local tmp_creds
  tmp_creds="${DEV_CREDENTIALS_FILE}.tmp.$$"
  printf 'DEV_BOOTSTRAP_AKID=%s\nDEV_BOOTSTRAP_SECRET=%s\n' \
    "$DEV_BOOTSTRAP_AKID" "$DEV_BOOTSTRAP_SECRET" > "$tmp_creds"
  chmod 0600 "$tmp_creds"
  mv -f "$tmp_creds" "$DEV_CREDENTIALS_FILE"
  ```
  For parsing instead of `source`:
  ```bash
  # Parse key=value lines instead of sourcing (avoids code execution)
  if [[ -f "$DEV_CREDENTIALS_FILE" ]]; then
    while IFS='=' read -r k v; do
      case "$k" in
        DEV_BOOTSTRAP_AKID)   ak="${v:-test}" ;;
        DEV_BOOTSTRAP_SECRET) sk="${v:-test}" ;;
      esac
    done < "$DEV_CREDENTIALS_FILE"
  fi
  ```
  This also removes the SC1090 shellcheck suppressions at auth plan §6.5:417 and §6.6:502.

- **Portability impact:** None. `mktemp`-style atomic write is the standard pattern. The `while IFS='=' read` parse loop is POSIX-compliant and works in all bash versions.

- **Acceptance criteria:** Ticket item 7. Credential file must never exist in a truncated or world-readable state.

---

### SPEC-BS-004 — CH-AUTH-008: Array-based `-e` overrides in guest driver

- **Script(s) affected:** `mock-server/in-vm/run-in-vm.sh` (auth plan §6.10:604–611; call sites at lines ~194–196, ~225–230)
- **Current anti-pattern:**
  ```bash
  AWS_CREDS_ENV="-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci"
  run_as_floci_guest podman exec $AWS_CREDS_ENV tianlu-floci aws …
  ```
  Unquoted expansion splits on `IFS` only, and `IFS=$'\n\t'` (line 5) contains no space. Evidence (verified in advisory §Verification):
  ```
  $ /bin/bash -c 'IFS=$'"'"'\n\t'"'"'; V="-e A=1 -e B=2"; set -- $V; echo $#'
  1
  ```
  `podman` receives one malformed argument. The s3-smoke and Lambda steps fail in `sigv4` mode.

- **Required change with code sketch:**
  ```bash
  # Build overrides as an array — IFS=$'\n\t' does not split on spaces
  aws_creds_env=()
  if [[ "$AUTH_MODE" == "sigv4" ]]; then
    aws_creds_env=(-e AWS_ACCESS_KEY_ID=floci -e AWS_SECRET_ACCESS_KEY=floci)
  fi
  run_as_floci_guest podman exec ${aws_creds_env[@]+"${aws_creds_env[@]}"} tianlu-floci aws …
  ```
  The `${arr[@]+"${arr[@]}"}` guard is required — see SPEC-BS-005. Note the Lambda step (`run-in-vm.sh:220–238`) passes a heredoc-style `bash -c` script, so the `-e` flags must be inserted before `bash`, not inside the script.

- **Portability impact:** Bash arrays are bash-specific (not POSIX). This is acceptable — `run-in-vm.sh` uses `#!/usr/bin/env bash` and already uses `declare -A` (associative arrays, line 22). The `${arr[@]+…}` guard is bash 3.2-compatible (see SPEC-BS-005).

- **Acceptance criteria:** Ticket item 7 (second). s3-smoke and Lambda steps must pass in `sigv4` mode.

---

### SPEC-BS-005 — CH-AUTH-009: Retain `${arr[@]+…}` guard; bash-3.2 compatibility decision

- **Script(s) affected:** `mock-server/run-test.sh` (`launch_driver` function, lines 184–197)
- **Current anti-pattern:** Auth plan §6.10:636–641 asserts: *"The `${arr[@]+...}` guard is no longer needed because `printf '%q '` on an empty array produces an empty string (not an unbound-variable error)."* This is **false on bash 3.2**, which is `/bin/bash` on macOS. Evidence (verified in advisory §Verification):
  ```
  $ /bin/bash -c 'set -u; a=(); printf "%q " "${a[@]}"'
  /bin/bash: a[@]: unbound variable
  ```
  `run-test.sh` runs host-side with `#!/usr/bin/env bash`, so the interpreter is PATH-dependent — Homebrew bash 5 is fine, `/bin/bash` (3.2) is not. A default-flag run (`NO_SIDECAR` false, `AUTH_MODE` unset) yields an empty `driver_args` array and aborts before the driver launches.

- **Required change with code sketch:**
  ```bash
  launch_driver() {
    local -a driver_args=()
    if [[ "$NO_SIDECAR" == true ]]; then
      driver_args+=(--no-sidecar)
    fi
    if [[ -n "${AUTH_MODE:-}" ]]; then
      driver_args+=(--auth-mode="$AUTH_MODE")
    fi
    (
      # ${arr[@]+"${arr[@]}"} guards empty-array expansion under set -u on bash 3.2.
      # ${#arr[@]} is safe in 3.2; ${arr[@]} and ${arr[*]} are not.
      local driver_args_quoted
      driver_args_quoted="$(printf '%q ' ${driver_args[@]+"${driver_args[@]}"})"
      limactl shell "$TWIN_NAME" -- bash -c \
        "sudo systemd-run --quiet --wait --unit=tianlu-driver -- /opt/tianlu/mock-server/in-vm/run-in-vm.sh ${driver_args_quoted}" 2>/dev/null
    ) &
    DRIVER_SHELL_PID=$!
  }
  ```
  The `printf '%q '` pattern (replacing `${driver_args[*]}`) is a genuine improvement — it shell-escapes each element individually, preserving argument boundaries when elements contain whitespace. The guard must be retained.

- **Portability impact:** The `${arr[@]+"${arr[@]}"}` guard is bash 3.2-compatible. The `printf '%q '` is bash 4.0+ — it is not available in bash 3.2. If bash 3.2 support is required, an alternative quoting mechanism is needed. **Decision required:** The ticket (item 8) says "decide bash-3.2 support explicitly." My recommendation: add an explicit `(( BASH_VERSINFO[0] >= 4 ))` precondition at the top of `run-test.sh` and document that bash 4+ is required. This is consistent with the project's Ubuntu 24.04+ target and avoids the complexity of a bash-3.2-compatible quoting fallback.

- **Acceptance criteria:** Ticket item 8. Either the guard is retained and bash 3.2 works, or a bash-4+ precondition is added and documented.

---

### SPEC-BS-006 — CH-AUTH-011: `DEV_AUTH_MODE` constant; gate rotation on mode

- **Script(s) affected:** `mock-server/dev-twin.sh` (constants block, `_install_absent`, new `_rotate_bootstrap_credentials`)
- **Current anti-pattern:** No `DEV_AUTH_MODE` constant exists. `_install_absent` hardcodes `FLOCI_AUTH_MODE=sigv4` (line 484). Rotation has no mode check — it always runs. SPEC-TX-002/003 specify off-mode behaviour that is unreachable.

- **Required change with code sketch:**
  ```bash
  # In constants block (after DEV_POLL_INTERVAL, line ~26):
  readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"

  # In _install_absent (line 484), replace hardcoded sigv4:
  limactl shell "$DEV_TWIN_NAME" -- sudo bash -c \
    "cd / && FLOCI_HOST_PERSISTENT_PATH=$DEV_GUEST_DATA_ROOT \
     FLOCI_TLS_ENABLED=false FLOCI_TLS_SELF_SIGNED=false \
     FLOCI_AUTH_MODE=$DEV_AUTH_MODE \
     bash /opt/tianlu/setup-floci.sh" 2>/dev/null

  # In _rotate_bootstrap_credentials, gate on mode:
  _rotate_bootstrap_credentials() {
    if [[ "$DEV_AUTH_MODE" == "off" ]]; then
      return 0
    fi
    # … rest of rotation logic
  }
  ```
  This also supplies the variable that CH-AUTH-006 needs (see SPEC-BS-007).

- **Portability impact:** None. Simple variable assignment and `[[ ]]` comparison.

- **Acceptance criteria:** Ticket item 10. Rotation must be a no-op when `DEV_AUTH_MODE=off`. The dev twin must be configurable between `off` and `sigv4` via a single env var.

---

### SPEC-BS-007 — CH-INST-001: Retry 5xx in `verify_health`; report last code

- **Script(s) affected:** `setup-floci.sh` (`verify_health` function, lines 903–929)
- **Current anti-pattern:**
  ```bash
  case "$code" in
    200) return 0 ;;
    000) sleep "$HEALTH_POLL_SLEEP" ;;
    *)   printf 'ERROR: health check failed (HTTP %s)\n' "$code" >&2; exit 1 ;;
  esac
  # …
  printf 'ERROR: health check timed out after %s tries\n' "$HEALTH_POLL_TRIES" >&2
  ```
  Only `000` (connection refused/timeout) is retried. A JVM emulator returning `503` while warming up, or `404` before the health route is registered, kills a run that would have succeeded seconds later. The timeout message discards the last observed HTTP code — the one datum needed to diagnose the failure.

- **Required change with code sketch:**
  ```bash
  verify_health() {
    local i code scheme curl_opts=() last_code=""
    if [[ "$FLOCI_TLS_ENABLED" == "true" ]]; then
      scheme="https"
      curl_opts+=(-k)
    else
      scheme="http"
    fi
    for (( i=1; i<=HEALTH_POLL_TRIES; i++ )); do
      code="$(curl -s -o /dev/null -w '%{http_code}' \
        --resolve "${FLOCI_HOSTNAME}:${FLOCI_API_PORT}:127.0.0.1" \
        --connect-timeout 5 --max-time 10 \
        "${curl_opts[@]+"${curl_opts[@]}"}" "${scheme}://${FLOCI_HOSTNAME}:${FLOCI_API_PORT}${FLOCI_HEALTH_PATH}")" || code=000
      last_code="$code"
      case "$code" in
        200) return 0 ;;
        000|[5][0-9][0-9]) sleep "$HEALTH_POLL_SLEEP" ;;   # retry: connection refused + server errors
        4[0-9][0-9]) printf 'ERROR: health check failed (HTTP %s) — client error, not retrying\n' "$code" >&2; exit 1 ;;
        *)   printf 'ERROR: health check failed (HTTP %s)\n' "$code" >&2; exit 1 ;;
      esac
    done
    printf 'ERROR: health check timed out after %s tries (last code: %s)\n' \
      "$HEALTH_POLL_TRIES" "${last_code:-none}" >&2
    exit 1
  }
  ```
  **Pattern rationale:** `[5][0-9][0-9]` matches 500–599 (server errors — transient, worth retrying). `4[0-9][0-9]` matches 400–499 (client errors — not transient, fail fast). The `last_code` variable captures the final observed code for the timeout message.

- **Portability impact:** None. The `[5][0-9][0-9]` glob pattern in `case` is POSIX-compliant. The `${last_code:-none}` default expansion is standard bash.

- **Acceptance criteria:** Ticket item 16. A `503` during JVM warmup must be retried, not treated as fatal. The timeout message must include the last observed HTTP code.

---

### SPEC-BS-008 — CH-INST-002: Per-binary AppArmor sentinel

- **Script(s) affected:** `setup-floci.sh` (`assert_userns_allowed` function, lines 420–506)
- **Current anti-pattern:**
  ```bash
  local need_install=false
  for bin in "$PODMAN_BIN" "$CRUN_BIN" "$PASTA_BIN" "$NEWUIDMAP_BIN" "$NEWGIDMAP_BIN"; do
    [[ -f "$bin" ]] || continue
    if ! _system_profile_grants_userns "$bin" \
      && ! grep -q 'podman-userns' "${APPARMOR_PROFILES_FILE:-/dev/null}" 2>/dev/null; then
      need_install=true
      break
    fi
  done
  ```
  The sentinel is `grep -q 'podman-userns'` — a single string check. On Ubuntu 26.04, the `apparmor-profiles` package ships a podman profile, so `_system_profile_grants_userns "$PODMAN_BIN"` succeeds at line 492 and the `podman-userns` block is **never written**. The sentinel therefore can never match, `need_install` stays `true`, and every run rewrites `/etc/apparmor.d/podman-userns` and runs `apparmor_parser -r`. Outcome-idempotent, not action-idempotent.

- **Required change with code sketch:**
  ```bash
  # Per-binary sentinel: check whether each block's profile name is loaded.
  # The old single-string sentinel (grep -q 'podman-userns') fails on 26.04
  # because the system podman profile means the podman-userns block is never
  # written, so the sentinel never matches.
  _profile_loaded() {
    local profile_name="$1"
    grep -q "^${profile_name} " "${APPARMOR_PROFILES_FILE:-/dev/null}" 2>/dev/null
  }

  # In assert_userns_allowed, replace the sentinel check:
  local need_install=false
  for bin in "$PODMAN_BIN" "$CRUN_BIN" "$PASTA_BIN" "$NEWUIDMAP_BIN" "$NEWGIDMAP_BIN"; do
    [[ -f "$bin" ]] || continue
    if _system_profile_grants_userns "$bin"; then
      continue   # system profile already covers this binary
    fi
    # Determine the profile name this binary would get
    local pname
    case "$bin" in
      "$PODMAN_BIN")     pname="podman-userns" ;;
      "$CRUN_BIN")       pname="podman-userns-crun" ;;
      "$PASTA_BIN")      pname="podman-userns-pasta" ;;
      "$NEWUIDMAP_BIN")  pname="newuidmap-userns" ;;
      "$NEWGIDMAP_BIN")  pname="newgidmap-userns" ;;
      *) continue ;;
    esac
    if ! _profile_loaded "$pname"; then
      need_install=true
      break
    fi
  done
  ```
  The twin's hash set must also be extended to include the AppArmor profile so the regression is guarded (per the advisory's fix instruction).

- **Portability impact:** None. `grep -q` and `case` are POSIX-compliant.

- **Acceptance criteria:** Ticket item 17. On Ubuntu 26.04, a converged re-run must not rewrite the AppArmor profile or reload it via `apparmor_parser -r`.

---

### SPEC-BS-009 — CH-INST-004: Assert `curl` and `openssl` in Phase 1

- **Script(s) affected:** `setup-floci.sh` (Phase 1 functions, lines 340–396; `install_podman`, lines 629–636)
- **Current anti-pattern:** `install_podman` only installs `podman uidmap`. `generate_presign_secret` (Phase 5, line 803) needs `openssl`. `verify_health` (Phase 6, line 917) needs `curl`. Neither is asserted in Phase 1 nor installed in Phase 3. On a minimal Ubuntu image, the run fails in Phase 6 after all mutating work is done.

- **Required change with code sketch:**
  ```bash
  # In Phase 1, add after assert_ubuntu_version:
  assert_required_commands() {
    local cmd missing=()
    for cmd in curl openssl; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
      fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
      printf 'ERROR: required commands not found: %s\n' "${missing[*]}" >&2
      exit 1
    fi
  }

  # In main(), add after assert_ubuntu_version:
  assert_required_commands
  ```
  Alternatively, add `curl openssl` to the `apt-get install` list in `install_podman` (line 635). The assertion approach is preferred — it fails fast before any mutating work, and on a standard Ubuntu server both are already present.

- **Portability impact:** None. `command -v` is POSIX-compliant. The array-based missing-command collection is bash-specific but acceptable.

- **Acceptance criteria:** Ticket item 19. The script must fail in Phase 1 (not Phase 6) when `curl` or `openssl` is missing.

---

### SPEC-BS-010 — CH-DEV-001: `_print_next_steps` from `dev_recreate`

- **Script(s) affected:** `mock-server/dev-twin.sh` (`dev_recreate` function, lines 681–701)
- **Current anti-pattern:** `dev_recreate` calls `_install_absent SKIP_PREFLIGHT` (line 700) and returns without printing next steps. `_print_next_steps` is reachable only from `dev_up` (lines 594, 608, 612). The user follows `make dev-recreate` to change auth mode, rotation runs, the well-known key is deleted — and they are never told where the new credential is.

- **Required change with code sketch:**
  ```bash
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
    _print_next_steps   # ← ADDED
  }
  ```

- **Portability impact:** None. Simple function call.

- **Acceptance criteria:** Ticket item 21. `make dev-recreate` must print the next-steps block including credential location and rotation instructions.

---

### SPEC-BS-011 — CH-DEV-002: `dev_env` on resume paths

- **Script(s) affected:** `mock-server/dev-twin.sh` (`dev_up` function, lines 584–619)
- **Current anti-pattern:** `dev_env` runs only from `_install_absent` (line 488). The `Running` and `Stopped` branches of `dev_up` do not call it. After `dev-down`/`dev-up`, `~/.aws/credentials` is whatever it was. Once the credential cache exists, cache and profile can diverge with no reconciliation.

- **Required change with code sketch:**
  ```bash
  dev_up() {
    # …
    case "$state" in
      Running)
        managed_hosts_add
        dev_env              # ← ADDED: refresh AWS profile on resume
        _health_check
        _print_next_steps
        ;;
      Stopped)
        preflight_ports || { … }
        limactl start --tty=false "$DEV_TWIN_NAME"
        _wait_running "$DEV_START_BUDGET_RESUME"
        verify_disk_mount || { … }
        _wait_user_manager
        _ensure_service
        managed_hosts_add
        dev_env              # ← ADDED: refresh AWS profile on resume
        _resume_health_check
        _print_next_steps
        ;;
      # …
    esac
  }
  ```
  `dev_env` is idempotent by design — it checks for existing profile blocks before writing. The CH-AUTH-004 fix (SPEC-BS-013, not in my scope but noted) must preserve this idempotency.

- **Portability impact:** None.

- **Acceptance criteria:** Ticket item 22. After `make dev-down && make dev-up`, `~/.aws/credentials` must reflect the current rotated credentials.

---

### SPEC-BS-012 — CH-DEV-003: Distinct return codes from `dev_disk_exists`

- **Script(s) affected:** `mock-server/dev-twin.sh` (`dev_disk_exists` function, lines 112–120; callers at lines 465–474, 690–698, 726–752)
- **Current anti-pattern:**
  ```bash
  dev_disk_exists() {
    local out rc=0
    out="$(limactl disk list --json 2>/dev/null)" || rc=$?
    if [[ $rc -ne 0 ]]; then
      printf 'ERROR: limactl-disk-list: failed to query disk state\n' >&2
      return 1    # ← same return code as "absent"
    fi
    printf '%s' "$out" | grep -qF "\"name\":\"${DEV_DISK_NAME}\""
  }
  ```
  Returns `1` for both "absent" and "query failed". All three callers branch on `rc -eq 1` as though it meant "absent". A transient `limactl` failure takes the "create the disk" path in `_install_absent`, and in `dev_reset` it takes the "no disk to delete" path — silently skipping the delete the user just confirmed.

- **Required change with code sketch:**
  ```bash
  dev_disk_exists() {
    local out rc=0
    out="$(limactl disk list --json 2>/dev/null)" || rc=$?
    if [[ $rc -ne 0 ]]; then
      printf 'ERROR: limactl-disk-list: failed to query disk state\n' >&2
      return 2    # ← distinct: query failure
    fi
    if printf '%s' "$out" | grep -qF "\"name\":\"${DEV_DISK_NAME}\""; then
      return 0    # present
    else
      return 1    # absent
    fi
  }
  ```
  Callers must be updated to branch on all three states:
  ```bash
  # In _install_absent (line 465):
  if dev_disk_exists; then
    :   # disk present
  else
    rc=$?
    if [[ $rc -eq 1 ]]; then
      limactl disk create "$DEV_DISK_NAME" --size "$DEV_DISK_SIZE"
    else
      return 1   # query failed — abort
    fi
  fi

  # In dev_reset (line 726):
  if dev_disk_exists; then
    # … delete logic
  else
    rc=$?
    if [[ $rc -eq 1 ]]; then
      :   # absent — nothing to delete
    else
      return 1   # query failed — abort
    fi
  fi
  ```

- **Portability impact:** None. Return code convention is standard shell.

- **Acceptance criteria:** Ticket item 23. A transient `limactl` failure must not silently skip disk creation or deletion.

---

### SPEC-BS-013 — CH-DEV-004: `DEV_DISK_MOUNT` derived from `DEV_DISK_NAME`

- **Script(s) affected:** `mock-server/dev-twin.sh` (constants block, lines 7–8; hardcoded paths at lines 13, 137, 446, 478, 479, 599)
- **Current anti-pattern:** `DEV_DISK_NAME` is overridable via `${DEV_DISK_NAME:-floci-dev-data}` (line 7), but the mount path `/mnt/lima-floci-dev-data` is hardcoded at 6 sites. Overriding `DEV_DISK_NAME` — which the `${VAR:-default}` form explicitly invites — breaks `verify_disk_mount`, the mode-1777 assertion, and the systemd `ExecCondition` silently. Lima derives the mount from the disk name, so the two cannot be independent.

- **Required change with code sketch:**
  ```bash
  readonly DEV_DISK_NAME="${DEV_DISK_NAME:-floci-dev-data}"
  readonly DEV_DISK_MOUNT="${DEV_DISK_MOUNT:-/mnt/lima-${DEV_DISK_NAME}}"
  readonly DEV_GUEST_DATA_ROOT="${DEV_DISK_MOUNT}/floci-data"
  ```
  Then replace all 6 hardcoded `/mnt/lima-floci-dev-data` occurrences with `$DEV_DISK_MOUNT`. The `_install_exec_condition` function (line 446) embeds the path inside a nested-quoted `printf` for the drop-in file — that one needs care:
  ```bash
  _install_exec_condition() {
    local uid tmpfile
    uid="$(limactl shell "$DEV_TWIN_NAME" -- bash -c 'id -u floci 2>/dev/null' 2>/dev/null)"
    tmpfile="$(mktemp /tmp/exec-condition.XXXXXX)"
    printf '[Service]\nExecCondition=/bin/bash -c '"'"'findmnt -no FSTYPE,SOURCE %s 2>/dev/null | grep -qE "^ext4 /dev/vd[a-z][0-9]+$"'"'"'\n' \
      "$DEV_DISK_MOUNT" > "$tmpfile"
    # …
  }
  ```

- **Portability impact:** None. Simple variable substitution.

- **Acceptance criteria:** Ticket item 24. Changing `DEV_DISK_NAME` must update all mount-path references consistently.

---

### SPEC-BS-014 — CH-DEV-005: Unify health budget and fallback

- **Script(s) affected:** `mock-server/dev-twin.sh` (`_health_check`, lines 304–315; `_resume_health_check`, lines 503–521; `dev_up` call sites)
- **Current anti-pattern:** Fresh install uses `_health_check` (60 × 2s = 120s, no failed-unit fallback). Resume uses `_resume_health_check` (150 × 2s = 300s + `failed`-state reset). The AppArmor race is documented at 2–3 minutes (`digital-twin-findings.md §9`) and applies to first boot as much as to resume. A fresh `dev-up` on a cold QEMU arm64 boot can therefore time out where a resume would recover.

- **Required change with code sketch:**
  ```bash
  # In _install_absent (line 487), replace:
  #   _health_check
  # with:
  #   _resume_health_check

  # In dev_up Running branch (line 592), replace:
  #   _health_check
  # with:
  #   _resume_health_check
  ```
  Then `_health_check` can be removed entirely, or kept as a thin wrapper for backward compatibility. The `_resume_health_check` function is already the more correct implementation — it has the longer budget and the `failed`-state reset fallback. The distinct error strings ("after resume" vs generic) should be preserved or parameterised.

- **Portability impact:** None.

- **Acceptance criteria:** Ticket item 25. A fresh `dev-up` on a cold QEMU arm64 boot must not time out due to the AppArmor race.

---

### SPEC-BS-015 — CH-DEV-006: Drop redundant `main` guard

- **Script(s) affected:** `mock-server/dev-twin.sh` (`main` function, lines 779–801)
- **Current anti-pattern:**
  ```bash
  main() {
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then    # ← INNER GUARD (line 780)
      unset DEV_HOSTS_FILE
      assert_identity
      # … dispatch logic
    fi
  }

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then      # ← OUTER GUARD (line 799)
    main "$@"
  fi
  ```
  The inner guard duplicates the outer guard and makes `main` uncallable from bats, so argument dispatch cannot be tested. The outer guard at line 799 is the standard pattern used by `setup-floci.sh` (line 1018).

- **Required change with code sketch:**
  ```bash
  main() {
    unset DEV_HOSTS_FILE
    assert_identity
    local cmd="${1:-}"
    shift || true
    case "$cmd" in
      up) dev_up "$@" ;;
      # …
    esac
  }

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
  fi
  ```
  Remove the inner `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` block (lines 780 and 796) and un-indent the body.

- **Portability impact:** None. This is a structural fix.

- **Acceptance criteria:** Ticket item 26. `main` must be callable from bats for argument-dispatch testing.

---

### SPEC-BS-016 — CH-TWIN-001: Verdict on precondition failure

- **Script(s) affected:** `mock-server/run-test.sh` (`assert_preconditions`, lines 47–61; `main`, lines 526–559)
- **Current anti-pattern:** `assert_preconditions` calls `die` (line 42) which does `exit 1` directly. `main`'s docstring promises *"a verdict after every failure"*, and `print_verdict` (line 514) is the machine-readable contract — any CI wrapper grepping for `TWIN:` sees nothing. The call at line 539 is outside the guarded block that sets `FAIL_REASON`.

- **Required change with code sketch:**
  ```bash
  # Replace die() calls in assert_preconditions with FAIL_REASON + return 1:
  assert_preconditions() {
    local lima_version macos_version macos_major

    command -v limactl >/dev/null 2>&1 || { FAIL_REASON='limactl not found (brew install lima)'; return 1; }
    lima_version="$(limactl --version)"
    printf 'Using %s\n' "$lima_version"
    [[ "$(uname -m)" == 'arm64' ]] || { FAIL_REASON='twin requires Apple Silicon (arm64 host)'; return 1; }
    macos_version="$(sw_vers -productVersion)"
    macos_major="${macos_version%%.*}"
    if [[ ! "$macos_major" =~ ^[0-9]+$ ]] || (( macos_major < 13 )); then
      FAIL_REASON='qemu backend requires macOS 13+'
      return 1
    fi
  }

  # In main(), move assert_preconditions inside the guarded block:
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
    # assert_preconditions moved inside the chain so its failures produce a verdict:
    if assert_preconditions && make_evidence_dir && ensure_twin && launch_driver && poll_sentinel; then
      # …
    else
      wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || true
      DRIVER_SHELL_PID=""
    fi
    print_verdict "$result"
    teardown
    [[ "$result" == 'PASS' ]]
  }
  ```
  The `die` function can be removed entirely after this change — all its call sites are in `assert_preconditions`.

- **Portability impact:** None.

- **Acceptance criteria:** Ticket item 27. A missing `limactl` must produce `TWIN: FAIL: limactl not found`, not silent exit 1.

---

### SPEC-BS-017 — CH-TWIN-002: `sidecar-delta` in mandatory array

- **Script(s) affected:** `mock-server/run-test.sh` (`validate_summary`, lines 444–499)
- **Current anti-pattern:**
  ```bash
  local mandatory=(preflight-ok run1-exit-0 floci-service-active health-200 s3-smoke
                   run2-exit-0 idempotency-hosts idempotency-subuid idempotency-hashes)
  # …
  for c in "${mandatory[@]}"; do
    if [[ "$c" == "sidecar-delta" && "$NO_SIDECAR" == true ]]; then
      [[ "$val" == "SKIPPED" || "$val" == "PASS" ]] && continue
    fi
    # …
  done
  ```
  `sidecar-delta` is not in `mandatory`, so the `for c in "${mandatory[@]}"` loop never iterates over it, and the special case `if [[ "$c" == "sidecar-delta" && "$NO_SIDECAR" == true ]]` can never be reached. The guest driver does fail the run via the `FAILED` sentinel (`run-in-vm.sh:241,245`), so this is not an open hole today — but the host-side code reads as coverage that does not exist.

- **Required change with code sketch:**
  ```bash
  local mandatory=(preflight-ok run1-exit-0 floci-service-active health-200 s3-smoke
                   sidecar-delta run2-exit-0 idempotency-hosts idempotency-subuid idempotency-hashes)
  ```
  The special case then becomes live and correct: when `NO_SIDECAR=true`, `sidecar-delta` with status `SKIPPED` or `PASS` is accepted; otherwise it must be `PASS`.

- **Portability impact:** None. Array element addition.

- **Acceptance criteria:** Ticket item 28. The `sidecar-delta` criterion must be validated by the host, not only by the guest driver.

---

### SPEC-BS-018 — CH-TWIN-004: Fix stale-sentinel cleanup path

- **Script(s) affected:** `mock-server/run-test.sh` (`ensure_twin`, lines 143–182)
- **Current anti-pattern:**
  ```bash
  rm -f "${HOST_EVIDENCE_MOUNT}/DONE" "${HOST_EVIDENCE_MOUNT}/FAILED"
  ```
  The sentinels live in `$STAGING` (set at line 175: `STAGING="${HOST_EVIDENCE_MOUNT}/staging"`), not in `$HOST_EVIDENCE_MOUNT` directly. The `rm -f` targets the wrong directory. Harmless because `rm -rf "$STAGING"` (line 180) does the real work, but it reads as a guard that is not one, and would mask a real bug if line 180 were ever removed.

- **Required change with code sketch:**
  ```bash
  rm -rf "$STAGING"
  rm -f "${STAGING}/DONE" "${STAGING}/FAILED"
  ```
  Or, more simply, just rely on `rm -rf "$STAGING"` (which already removes everything in staging) and drop the separate `rm -f` line entirely. The `rm -rf` is sufficient — it removes the directory and all contents including sentinels. The `mkdir -p "$HOST_EVIDENCE_MOUNT"` on line 176 creates the parent; `STAGING` is recreated by the guest driver.

- **Portability impact:** None.

- **Acceptance criteria:** Ticket item 30. The sentinel cleanup must target the correct directory.

---

### SPEC-BS-019 — CH-TWIN-007: Fix `wait "${DRIVER_SHELL_PID:-}"` and `HOST_HOME` fallback

- **Script(s) affected:** `mock-server/run-test.sh` (`wait_driver`, line 229; `HOST_HOME`, line 11; `main` fallback, line 553)
- **Current anti-pattern:**
  ```bash
  # Line 229 — wait_driver:
  wait "${DRIVER_SHELL_PID:-}" 2>/dev/null || status=$?
  ```
  When `DRIVER_SHELL_PID` is empty (e.g., `launch_driver` was never called because `ensure_twin` failed), `wait ""` returns 127 ("command not found"), producing `driver exited nonzero (127) despite DONE` — which misattributes the failure.

  ```bash
  # Line 11:
  HOST_HOME="${HOME:-$(id -un)}"
  ```
  Falls back to a *username* where a path is required. Every derived path (`EVIDENCE_DIR_ROOT`, `HOST_EVIDENCE_MOUNT`) would be relative and land in the CWD.

- **Required change with code sketch:**
  ```bash
  # Fix 1: Guard wait with a non-empty check
  wait_driver() {
    local status=0
    if [[ -n "${DRIVER_SHELL_PID:-}" ]]; then
      wait "${DRIVER_SHELL_PID}" 2>/dev/null || status=$?
    fi
    DRIVER_SHELL_PID=""
    if [[ "$status" -ne 0 ]]; then
      FAIL_REASON="driver exited nonzero (${status}) despite DONE"
      return 1
    fi
  }

  # Fix 2: Fail instead of falling back to a username
  if [[ -z "${HOME:-}" ]]; then
    FAIL_REASON='HOME is not set — cannot determine host home directory'
    return 1
  fi
  HOST_HOME="$HOME"
  readonly HOST_HOME
  ```
  The same guard must be applied to the fallback `wait` in `main` (line 553):
  ```bash
  if [[ -n "${DRIVER_SHELL_PID:-}" ]]; then
    wait "${DRIVER_SHELL_PID}" 2>/dev/null || true
  fi
  DRIVER_SHELL_PID=""
  ```

- **Portability impact:** None. `[[ -n ]]` is standard bash.

- **Acceptance criteria:** Ticket item 33. An empty `DRIVER_SHELL_PID` must not produce a spurious "driver exited nonzero (127)" message. An unset `HOME` must produce a clear failure, not a relative-path fallback.

---

### SPEC-BS-020 — CH-LZ-004: G1 must fail (not skip) when probe cannot be established

- **Script(s) affected:** `scripts/preflight-floci.sh` (`gate_g1_signatures`, lines 42–59; `skip` function, line 31; `main`, lines 119–128)
- **Current anti-pattern:**
  ```bash
  skip() { printf '  \033[33mSKIP\033[0m %s\n' "$1"; }
  # skip does NOT set FAILED=1

  gate_g1_signatures() {
    # …
    if ! out=$(aws_admin iam create-access-key --user-name "$user" 2>/dev/null); then
      skip "could not create access key (is IAM up?) — verify manually"; return
    fi
    # …
  }

  main() {
    # …
    if [[ "$FAILED" -eq 0 ]]; then
      pass "automated gates passed (finish G2/G4/G5 on a live cluster/DB)"
    else
      fail "one or more gates FAILED — fix before applying stages"; exit 1
    fi
  }
  ```
  If `create-access-key` fails, G1 calls `skip` and returns. `skip` does not set `FAILED`, so `main` reports *"automated gates passed"* and exits 0. Under `sigv4` with the default credentials (`$DEV_AKID` + `test`), the call always fails (see CH-AUTH-001), so the gate the design calls a hard stop reports success on precisely the configuration it exists to police.

- **Required change with code sketch:**
  ```bash
  # Distinguish automated gates (must not skip) from manual-notes gates (skip is acceptable)
  AUTOMATED_SKIPS=0

  skip() {
    local reason="$1"
    printf '  \033[33mSKIP\033[0m %s\n' "$reason"
    # Automated gates (G1, G3) must not skip — a skipped gate is a failed gate.
    # Manual-notes gates (G2, G4, G5) may skip.
  }

  gate_g1_signatures() {
    hdr "G1  IAM authorization is enforced (FLOCI_AUTH_VALIDATE_SIGNATURES=true + FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true)"
    local user="preflight-nopolicy-$$" ak sk out
    aws_admin iam create-user --user-name "$user" >/dev/null 2>&1 || true
    if ! out=$(aws_admin iam create-access-key --user-name "$user" 2>/dev/null); then
      fail "could not create access key — IAM may be unreachable or disabled. G1 cannot be established. HARD STOP."
      return
    fi
    # … rest of gate
  }

  gate_g3_dynamodb_lock() {
    # …
    aws_admin dynamodb create-table … || { fail "could not create table — DynamoDB may be unreachable. G3 cannot be established."; return; }
    # …
  }

  main() {
    # …
    gate_g1_signatures
    gate_g3_dynamodb_lock
    gate_g2_iam_db_auth     # may skip — manual gate
    gate_g4_g5_cluster_notes # may skip — manual gate
    hdr "Result"
    if [[ "$FAILED" -eq 0 ]]; then
      pass "automated gates passed (finish G2/G4/G5 on a live cluster/DB)"
    else
      fail "one or more gates FAILED — fix before applying stages"; exit 1
    fi
  }
  ```
  The key change: G1 and G3 call `fail` (which sets `FAILED=1`) instead of `skip` when they cannot establish their probe. G2, G4, G5 continue to use `skip` — they are manual-notes gates that require a live RDS/k3s cluster.

- **Portability impact:** None.

- **Acceptance criteria:** Ticket item 37. When IAM is unreachable, G1 must report FAIL and `main` must exit non-zero. The message must distinguish "IAM unreachable" from "IAM reachable and permissive."

---

## Verdict

**CONDITIONAL PASS** — Severity 8

### Rationale

All 20 findings in the BS scope have been analyzed with concrete code sketches, portability assessments, and acceptance criteria. The requirements are well-specified and actionable. The severity of 8 reflects that several findings (CH-AUTH-002, CH-AUTH-005, CH-AUTH-008, CH-LZ-004) are correctness-critical — they would cause silent failures or security bypasses if not fixed.

### Conditions

1. **SPEC-BS-005 (CH-AUTH-009):** The bash-3.2 compatibility decision must be made explicitly before implementation. My recommendation: add `(( BASH_VERSINFO[0] >= 4 ))` precondition to `run-test.sh` and document bash 4+ as a requirement. This is consistent with the project's Ubuntu 24.04+ target.

2. **SPEC-BS-008 (CH-INST-002):** The per-binary sentinel must be verified against the actual Ubuntu 26.04 AppArmor profile names. The `_profile_loaded` helper assumes profile names match the pattern `podman-userns`, `podman-userns-crun`, etc. — verify these against `aa-status` output on 26.04.

3. **SPEC-BS-020 (CH-LZ-004):** The distinction between automated gates (G1, G3 — must not skip) and manual-notes gates (G2, G4, G5 — may skip) must be documented in `landing-zone-design.md` §10.1.

### Routing

This analysis is complete for Phase A. The code-architect and test-engineer will implement these requirements in Phase B. No findings require PM escalation — all are covered by the accepted ticket items.

## References

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| `errexit` behaviour on bare simple commands | [Spec: Bash manual, Section 4.3.1 "The Set Builtin", `-e`] | Verified — `delete_rc=$?` is unreachable after a failing bare command |
| `IFS=$'\n\t'` does not split on spaces | [Spec: POSIX Shell, Section 2.6 "Word Expansions"] | Verified in advisory §Verification — `set -- $V` yields 1 argument |
| bash 3.2 `${a[@]}` under `set -u` is unbound | [Spec: Bash 3.2 changelog; tested on macOS `/bin/bash`] | Verified in advisory §Verification — `a[@]: unbound variable` |
| `printf '%q '` is bash 4.0+ | [Spec: Bash manual, Section 4.2 "Bash Builtin Commands", `printf`] | `%q` format specifier introduced in bash 4.0 |
| `command -v` is POSIX-compliant | [Spec: POSIX.1-2017, `command` utility] | Standard — preferred over `which` or `type` |
| `case` glob patterns are POSIX | [Spec: POSIX Shell, Section 2.9.4 "Case Conditional Construct"] | `[5][0-9][0-9]` is a valid POSIX pattern |
| Atomic file write pattern | [Source: `setup-floci.sh:822–841` — existing project convention] | `.tmp` + `chmod` + `mv -f` already used in `write_env_file` and `write_quadlet_unit` |
| `||` as condition context suppressing `errexit` | [Spec: Bash manual, Section 4.3.1, `-e` description: "The shell does not exit if the command that fails is … part of any command executed in a && or \|\| list"] | Verified — `cmd \|\| handler` is a conditional list |
