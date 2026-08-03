# B2-3: APPLY Unit 3 — Credential Rotation Fixes

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T23:45:00Z |
| Step | B2-3 |
| Phase | B — Build |
| Ticket | psc-0003 |
| Unit | 3 — Credential Rotation Fixes |
| Target file | mock-server/dev-twin.sh |

## Implementation Plan

### Acceptance Criteria
1. `delete_rc=0; _run_as_floci_guest "… delete-access-key …" || delete_rc=$?` — handler reachable under `set -e`
2. Credential file written atomically: `.tmp` → `chmod 0600` → `mv -f`
3. Credential file parsed with `while IFS='=' read -r k v` instead of `source` (removes SC1090 suppressions)
4. `readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"` in constants block
5. `_rotate_bootstrap_credentials` early-returns when `DEV_AUTH_MODE=off`
6. `FLOCI_AUTH_MODE="$DEV_AUTH_MODE"` passed to installer (not hardcoded `sigv4`)
7. `_print_next_steps` called at end of `dev_recreate`

### Logical Units
| # | Unit | Files | AC Satisfied |
|---|------|-------|-------------|
| 1 | Add constants (DEV_CREDENTIALS_FILE, DEV_REGION, DEV_AUTH_MODE) | dev-twin.sh | AC-4 |
| 2 | Add _rotate_bootstrap_credentials function | dev-twin.sh | AC-1, AC-2, AC-3, AC-5 |
| 3 | Modify _install_absent (pass FLOCI_AUTH_MODE, call rotation) | dev-twin.sh | AC-6 |
| 4 | Modify dev_recreate (call _print_next_steps) | dev-twin.sh | AC-7 |

### Findings covered
- CH-AUTH-005 — `|| delete_rc=$?` for delete under `set -e`
- CH-AUTH-006 — Introduce `DEV_AUTH_MODE`; call `_print_next_steps` from `dev_recreate`
- CH-AUTH-007 — Atomic `.tmp+chmod+mv` for credential file; parse instead of `source`
- CH-AUTH-011 — `DEV_AUTH_MODE` constant; gate rotation on mode; pass to installer

---

## Unit 1: Add Constants

| Unit | 1 |
| Build result | PASS — exit 0, 0 warnings |
| Files changed | mock-server/dev-twin.sh (+3 lines) |

Added after `DEV_POLL_INTERVAL` (line 26):
```bash
readonly DEV_CREDENTIALS_FILE="${DEV_CREDENTIALS_FILE:-${HOME}/.cache/tianlu-twin/dev-credentials.env}"
readonly DEV_REGION="${DEV_REGION:-eu-west-2}"
readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"
```

---

## Unit 2: Add _rotate_bootstrap_credentials Function

| Unit | 2 |
| Build result | PASS — exit 0, 0 warnings |
| Files changed | mock-server/dev-twin.sh (+86 lines) |

Inserted between `_resume_health_check` and `_print_next_steps` (line 527-611).

Key implementation details:

**CH-AUTH-005 fix (delete_rc reachable under set -e):**
```bash
delete_rc=0
_run_as_floci_guest "… iam delete-access-key …" || delete_rc=$?
```
The `||` makes this a condition context, so `set -e` does not terminate the shell on failure. `delete_rc=$?` is now reachable.

**CH-AUTH-007 fix (atomic write + parse instead of source):**
- Credential file parsed with `while IFS='=' read -r k v; case "$k" in …` instead of `source "$DEV_CREDENTIALS_FILE"`. This removes the SC1090 suppression and the injection risk.
- Credential file written atomically: `mktemp` → `printf … > "$tmp"` → `chmod 0600 "$tmp"` → `mv -f "$tmp" "$DEV_CREDENTIALS_FILE"`. No window where the file exists at umask permissions or is truncated.

**CH-AUTH-011 fix (auth-mode gate):**
```bash
if [[ "$DEV_AUTH_MODE" == "off" ]]; then
  return 0
fi
```
Rotation is a no-op when auth is off — no IAM enforcement, no credential to rotate.

---

## Unit 3: Modify _install_absent

| Unit | 3 |
| Build result | PASS — exit 0, 0 warnings |
| Files changed | mock-server/dev-twin.sh (2 lines changed) |

Changed the installer invocation from:
```bash
FLOCI_TLS_ENABLED=false FLOCI_TLS_SELF_SIGNED=false bash /opt/tianlu/setup-floci.sh
```
to:
```bash
FLOCI_TLS_ENABLED=false FLOCI_TLS_SELF_SIGNED=false FLOCI_AUTH_MODE=$DEV_AUTH_MODE bash /opt/tianlu/setup-floci.sh
```

Added `_rotate_bootstrap_credentials` call after `_health_check` and before `dev_env`:
```bash
_health_check
_rotate_bootstrap_credentials
dev_env
```

---

## Unit 4: Modify dev_recreate

| Unit | 4 |
| Build result | PASS — exit 0, 0 warnings |
| Files changed | mock-server/dev-twin.sh (+1 line) |

Added `_print_next_steps` call at the end of `dev_recreate`:
```bash
_install_absent SKIP_PREFLIGHT
_print_next_steps
```

---

## VALIDATE

| Full build | PASS — exit 0, 0 warnings |
| AC coverage | 7/7 acceptance criteria satisfied |

### AC Evidence

| # | AC | Evidence |
|---|----|----------|
| 1 | `delete_rc=0; cmd \|\| delete_rc=$?` | dev-twin.sh:588-593 — `delete_rc=0` before the call, `\|\| delete_rc=$?` after |
| 2 | Atomic credential file write | dev-twin.sh:605-610 — `mktemp` → `printf > "$tmp"` → `chmod 0600 "$tmp"` → `mv -f "$tmp" "$DEV_CREDENTIALS_FILE"` |
| 3 | Parse instead of source | dev-twin.sh:545-550 — `while IFS='=' read -r k v; case "$k" in …` |
| 4 | DEV_AUTH_MODE constant | dev-twin.sh:29 — `readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"` |
| 5 | Rotation early-returns on off | dev-twin.sh:536-538 — `if [[ "$DEV_AUTH_MODE" == "off" ]]; then return 0; fi` |
| 6 | FLOCI_AUTH_MODE from DEV_AUTH_MODE | dev-twin.sh:487 — `FLOCI_AUTH_MODE=$DEV_AUTH_MODE` (not hardcoded `sigv4`) |
| 7 | _print_next_steps from dev_recreate | dev-twin.sh:791 — `_print_next_steps` at end of `dev_recreate` |

### Build Verification
```sh
$ shellcheck mock-server/dev-twin.sh
(exit 0, no output — zero warnings)
```

### Files Changed Summary
- `mock-server/dev-twin.sh`: +90 lines, 3 lines modified
  - Lines 27-29: Added `DEV_CREDENTIALS_FILE`, `DEV_REGION`, `DEV_AUTH_MODE` constants
  - Lines 527-611: Added `_rotate_bootstrap_credentials` function
  - Line 487: Modified installer invocation to pass `FLOCI_AUTH_MODE=$DEV_AUTH_MODE`
  - Lines 490-491: Added `_rotate_bootstrap_credentials` call in `_install_absent`
  - Line 791: Added `_print_next_steps` call in `dev_recreate`
