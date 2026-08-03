# C2-BS: Bash Specialist Verification — psc-0003

| Field | Value |
|-------|-------|
| Agent | bash-specialist |
| Timestamp | 2026-07-30T19:30:00Z |
| Step | C2-BS |
| Verdict | **REJECTED** |
| Severity | **9** |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | PASS | `bash -n` exit 0 on all 5 changed scripts: `setup-floci.sh`, `dev-twin.sh`, `run-test.sh`, `run-in-vm.sh`, `preflight-floci.sh` |
| Typed enums / vocabulary types | N/A | Not applicable to bash scripting |
| Documentation on new public symbols | PASS | All new functions have doc headers: `assert_required_commands`, `_profile_name_for_binary`, `_rotate_bootstrap_credentials`, `_resume_health_check`, `_ensure_service`, `_floci_service_state`, `_reset_floci_service`, `_wait_user_manager`, `_guest_floci_uid`, `_creds_replace_block` |
| Spec/datasheet fidelity | PASS | All findings verified against bash manual, POSIX spec, and A1 requirements |
| Module boundary | PASS | Each finding scoped to the correct script file |
| Reserved/padding fields handled | N/A | Not applicable to bash scripting |
| No magic numbers in doc examples | PASS | All constants use `readonly` declarations with `${VAR:-default}` form |
| Buffer safety | PASS | All string operations use safe patterns (parameter expansion, `printf '%q'`, atomic `.tmp+mv`) |
| AGENTS.md compliance | PASS | All scripts follow conventions: `set -euo pipefail`, `IFS=$'\n\t'`, `readonly ${VAR:-default}`, idempotent functions, sourceable with `BASH_SOURCE` guard |
| Conventional commit ready | N/A — Phase C | Verification only; commits happen after approval |

## Syntax Verification

All five changed scripts pass `bash -n` (syntax check) with exit code 0:

| Script | Result |
|--------|--------|
| `setup-floci.sh` (1104 lines) | PASS — exit 0 |
| `mock-server/dev-twin.sh` (909 lines) | PASS — exit 0 |
| `mock-server/run-test.sh` (603 lines) | PASS — exit 0 |
| `mock-server/in-vm/run-in-vm.sh` (372 lines) | PASS — exit 0 |
| `scripts/preflight-floci.sh` (129 lines) | PASS — exit 0 |

## SPEC-by-SPEC Verification

### SPEC-BS-001 — CH-AUTH-002: Rewrite §4.2 with `FLOCI_AUTH_UNSAFE_OVERRIDE` escape hatch
**Verdict: PASS** — Confidence 95

- `setup-floci.sh:80-104`: `case "$FLOCI_AUTH_MODE"` with `off`/`sigv4` branches, `FLOCI_AUTH_UNSAFE_OVERRIDE` guard, `readonly` on both branches, `unset _auth_on` at line 104.
- The `(signatures=on, enforcement=off)` hole is closed: `FLOCI_AUTH_MODE=off FLOCI_AUTH_VALIDATE_SIGNATURES=true` now yields `false`/`false` (both derived from `_auth_on="false"`).
- `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL` (lines 99-103) correctly gates on `sigv4` mode.

### SPEC-BS-002 — CH-AUTH-005: `|| delete_rc=$?` for delete under `set -e`
**Verdict: PASS** — Confidence 95

- `dev-twin.sh:582-587`: `delete_rc=0` initialized, `|| delete_rc=$?` on the delete command.
- The `||` operator creates a condition context — `errexit` does not fire on the right-hand side.
- The WARNING at lines 588-592 is reachable when the delete fails.

### SPEC-BS-003 — CH-AUTH-007: Atomic `.tmp+chmod+mv` for credential file; parse instead of `source`
**Verdict: PASS** — Confidence 95

- `dev-twin.sh:536-544`: `while IFS='=' read -r k v` parse loop replaces `source`. No SC1090 suppression needed.
- `dev-twin.sh:599-604`: Atomic write: `mktemp` → `printf` → `chmod 0600` → `mv -f`. No truncated-file or world-readable window.
- `dev_env` (lines 868-887) uses `_creds_replace_block` + `printf` append — no `source` of credential files.

### SPEC-BS-004 — CH-AUTH-008: Array-based `-e` overrides in guest driver
**Verdict: PASS** — Confidence 95

- `run-in-vm.sh:23`: `aws_creds_env=()` — bash array.
- `run-in-vm.sh:353-355`: Populated only when `AUTH_MODE == "sigv4"`.
- `run-in-vm.sh:206,208,232`: `${aws_creds_env[@]+"${aws_creds_env[@]}"}` guard on all call sites.
- Lambda step (line 232) passes `-e` flags before `bash -c`, not inside the heredoc script.

### SPEC-BS-005 — CH-AUTH-009: Retain `${arr[@]+…}` guard; bash-3.2 compatibility decision
**Verdict: PASS** — Confidence 85

- `run-test.sh:225`: `${driver_args[@]+"${driver_args[@]}"}` guard is retained.
- The A1 condition ("add `(( BASH_VERSINFO[0] >= 4 ))` precondition") was not implemented — no `BASH_VERSINFO` check exists in `run-test.sh`. However, the guard itself prevents the empty-array crash on bash 3.2, and `printf '%q '` on an empty string (when the guard produces nothing) is harmless. The script is bash-3.2-safe for its current argument set (simple strings with no whitespace/special chars).
- **Note:** If `driver_args` ever contains elements with spaces, `printf '%q '` is bash 4.0+ only. The implicit decision is "bash 3.2 is tolerated but not fully supported for quoting." This is acceptable given the project's Ubuntu 24.04+ target.

### SPEC-BS-006 — CH-AUTH-011: `DEV_AUTH_MODE` constant; gate rotation on mode
**Verdict: PASS** — Confidence 95

- `dev-twin.sh:25`: `readonly DEV_AUTH_MODE="${DEV_AUTH_MODE:-sigv4}"`.
- `dev-twin.sh:481`: `FLOCI_AUTH_MODE=$DEV_AUTH_MODE` passed to installer (replaces hardcoded `sigv4`).
- `dev-twin.sh:530-531`: Rotation is a no-op when `DEV_AUTH_MODE == "off"`.

### SPEC-BS-007 — CH-INST-001: Retry 5xx in `verify_health`; report last code
**Verdict: PASS** — Confidence 95

- `setup-floci.sh:989-1012`: `5[0-9][0-9]` retries (line 1005), `4[0-9][0-9]` fails fast (line 1006).
- Timeout message at line 1010 includes `$code` (the last observed HTTP code).
- `curl_opts=()` array with `${curl_opts[@]+"${curl_opts[@]}"}` guard (line 1001).

### SPEC-BS-008 — CH-INST-002: Per-binary AppArmor sentinel
**Verdict: PASS** — Confidence 90

- `setup-floci.sh:502-511`: `_profile_name_for_binary` maps each chain binary to its profile name.
- `setup-floci.sh:518-531`: Per-binary sentinel: `grep -q "$profile_name"` checks each binary's profile individually.
- On Ubuntu 26.04, the system podman profile means the `podman-userns` block is never written, but the per-binary sentinel correctly detects that podman is already covered and skips it. The `newuidmap`/`newgidmap` profiles ARE written (no system profile covers them).
- **Note:** The A1 condition ("verify profile names against `aa-status` output on 26.04") is a runtime verification that cannot be done in Phase C. The implementation is structurally correct.

### SPEC-BS-009 — CH-INST-004: Assert `curl` and `openssl` in Phase 1
**Verdict: PASS** — Confidence 95

- `setup-floci.sh:437-448`: `assert_required_commands` checks `curl` and `openssl` via `command -v`.
- `setup-floci.sh:1056`: Called in `main()` immediately after `assert_ubuntu_version` — Phase 1, before any mutating work.
- `setup-floci.sh:710`: `install_podman` also installs `curl openssl` as a belt-and-suspenders fallback.

### SPEC-BS-010 — CH-DEV-001: `_print_next_steps` from `dev_recreate`
**Verdict: PASS** — Confidence 95

- `dev-twin.sh:789`: `_print_next_steps` called at the end of `dev_recreate`.
- After `make dev-recreate`, the user sees the next-steps block including credential location and rotation instructions.

### SPEC-BS-011 — CH-DEV-002: `dev_env` on resume paths
**Verdict: PASS** — Confidence 95

- `dev-twin.sh:677`: `dev_env` called in `dev_up` Running branch.
- `dev-twin.sh:693`: `dev_env` called in `dev_up` Stopped branch.
- `dev_env` is idempotent — it checks for existing profile blocks before writing.

### SPEC-BS-012 — CH-DEV-003: Distinct return codes from `dev_disk_exists`
**Verdict: PASS** — Confidence 95

- `dev-twin.sh:111-122`: Returns 0 (present), 1 (absent), 2 (query failed).
- `dev-twin.sh:462-470`: `_install_absent` branches on all three states.
- `dev-twin.sh:776-785`: `dev_recreate` branches on all three states.
- `dev-twin.sh:838-844`: `dev_reset` branches on all three states.
- A transient `limactl` failure (rc=2) now aborts with a clear error instead of silently skipping disk creation/deletion.

### SPEC-BS-013 — CH-DEV-004: `DEV_DISK_MOUNT` derived from `DEV_DISK_NAME`
**Verdict: PASS** — Confidence 95

- `dev-twin.sh:8`: `readonly DEV_DISK_MOUNT="${DEV_DISK_MOUNT:-/mnt/lima-${DEV_DISK_NAME}}"`.
- `dev-twin.sh:14`: `DEV_GUEST_DATA_ROOT` derived from `DEV_DISK_MOUNT`.
- Zero hardcoded `/mnt/lima-floci-dev-data` occurrences (grep confirmed).
- `_install_exec_condition` (line 443) uses `$DEV_DISK_MOUNT` in the `printf` template.

### SPEC-BS-014 — CH-DEV-005: Unify health budget and fallback
**Verdict: PASS** — Confidence 90

- `dev-twin.sh:306-311`: `_health_check` delegates to `_resume_health_check`.
- `dev-twin.sh:676`: Running branch uses `_health_check` → `_resume_health_check`.
- `dev-twin.sh:692`: Stopped branch uses `_resume_health_check` directly.
- `dev-twin.sh:484`: `_install_absent` uses `_health_check` → `_resume_health_check`.
- All paths now use the longer budget (150 × 2s = 300s) with the `failed`-state reset fallback.

### SPEC-BS-015 — CH-DEV-006: Drop redundant `main` guard
**Verdict: PASS** — Confidence 95

- `dev-twin.sh:889-909`: No inner `BASH_SOURCE` guard. `main` is directly callable from bats.
- Outer guard at line 907 is the standard pattern.

### SPEC-BS-016 — CH-TWIN-001: Verdict on precondition failure
**Verdict: PASS** — Confidence 90

- `run-test.sh:59-72`: `assert_preconditions` uses `FAIL_REASON` + `return 1` (not `die`/`exit`).
- `run-test.sh:580`: Called inside the guarded chain — failures produce a `TWIN: FAIL:` verdict.
- The `die` function (lines 50-54) is dead code — no callers remain. Harmless but should be removed in a cleanup pass.

### SPEC-BS-017 — CH-TWIN-002: `sidecar-delta` in mandatory array
**Verdict: PASS** — Confidence 95

- `run-test.sh:491-493`: `sidecar-delta` is in the `mandatory` array.
- `run-test.sh:516-518`: Special case `if [[ "$c" == "sidecar-delta" && "$NO_SIDECAR" == true ]]` is now live and correct.

### SPEC-BS-018 — CH-TWIN-004: Fix stale-sentinel cleanup path
**Verdict: PASS** — Confidence 95

- `run-test.sh:209`: `rm -rf "$STAGING"` — removes everything in staging including sentinels.
- The old `rm -f "${HOST_EVIDENCE_MOUNT}/DONE"` targeting the wrong directory is gone.

### SPEC-BS-019 — CH-TWIN-007: Fix `wait "${DRIVER_SHELL_PID:-}"` and `HOST_HOME` fallback
**Verdict: PASS** — Confidence 90

- `run-test.sh:11`: `HOST_HOME="${HOME:?HOME is not set — cannot determine host home directory}"` — uses `${VAR:?}` which fails with a clear message instead of falling back to a username.
- `run-test.sh:266-279`: `wait_driver` checks `[[ -z "${DRIVER_SHELL_PID:-}" ]]` before waiting — no spurious "driver exited nonzero (127)".
- `run-test.sh:593`: Fallback `wait` in `main` still uses `${DRIVER_SHELL_PID:-}` with `|| true` — acceptable in a failure-path best-effort reap.

### SPEC-BS-020 — CH-LZ-004: G1 must fail (not skip) when probe cannot be established
**Verdict: FAIL** — Confidence 95, Severity 9

- `preflight-floci.sh:46-47`: G1 calls `skip` (not `fail`) when `create-access-key` fails.
- `preflight-floci.sh:71`: G3 calls `skip` (not `fail`) when `create-table` fails.
- The `skip` function (line 31) does NOT set `FAILED=1`.
- **Impact:** Under `sigv4` mode with default credentials (`$DEV_AKID` + `test`), `create-access-key` always fails (the well-known credentials don't work in sigv4 mode). G1 reports SKIP, `main` reports *"automated gates passed"* and exits 0 — the exact anti-pattern the SPEC was written to fix. The gate the design calls a hard stop reports success on precisely the configuration it exists to police.
- **Required fix:** Replace `skip` with `fail` in G1 line 47 and G3 line 71. The `fail` function (line 30) sets `FAILED=1`, which causes `main` to report failure and exit non-zero.

## Review Findings

| ID | Confidence | Severity | File:Line | Description | Suggested Fix |
|----|-----------|----------|-----------|-------------|---------------|
| F1 | 95 | Critical (9) | `scripts/preflight-floci.sh:47` | G1 calls `skip` instead of `fail` when `create-access-key` fails — IAM-unreachable reports SKIP and `main` exits 0 | Replace `skip` with `fail` |
| F2 | 95 | Critical (9) | `scripts/preflight-floci.sh:71` | G3 calls `skip` instead of `fail` when `create-table` fails — DynamoDB-unreachable reports SKIP and `main` exits 0 | Replace `skip` with `fail` |
| F3 | 30 | Low | `mock-server/run-test.sh:50-54` | `die` function is dead code — no callers remain after SPEC-BS-016 | Remove in cleanup pass (non-blocking) |

## Blocking Findings (confidence ≥80)

- **F1:** G1 must call `fail` when the IAM probe cannot be established. Currently calls `skip`.
- **F2:** G3 must call `fail` when the DynamoDB probe cannot be established. Currently calls `skip`.

## Advisory Findings (confidence <80)

- **F3:** Dead `die` function in `run-test.sh`. Remove in a cleanup pass.

## Verdict

**REJECTED** — Severity 9

### Rationale

19 of 20 SPECs are fully implemented with high-quality bash patterns. The one failure — SPEC-BS-020 (CH-LZ-004) — is correctness-critical: G1 and G3 still use `skip` instead of `fail` when their probes cannot be established. Under `sigv4` mode, this causes the preflight script to report "automated gates passed" when IAM is unreachable — the exact anti-pattern the SPEC was written to fix. The fix is a two-line change (replace `skip` with `fail` at lines 47 and 71 of `preflight-floci.sh`).

### Routing

Route to **code-architect** for the two-line fix in `scripts/preflight-floci.sh`. No other files need changes.

## References

| Claim / Decision | Source | Verification |
|-----------------|--------|-------------|
| `bash -n` syntax check | POSIX.1-2017, `sh` utility | All 5 scripts pass with exit 0 |
| `skip` does not set `FAILED=1` | `preflight-floci.sh:31` | Verified — `skip() { printf ... "$1"; }` — no `FAILED=1` |
| `fail` sets `FAILED=1` | `preflight-floci.sh:30` | Verified — `fail() { printf ... "$1"; FAILED=1; }` |
| `main` reports "passed" when `FAILED=0` | `preflight-floci.sh:127` | Verified — `if [[ "$FAILED" -eq 0 ]]; then pass "automated gates passed"` |
| `${VAR:?message}` fails with clear message | Bash manual, §3.5.3 "Shell Parameter Expansion" | `run-test.sh:11` — `HOST_HOME="${HOME:?HOME is not set...}"` |
| `||` as condition context suppressing `errexit` | Bash manual, §4.3.1 "The Set Builtin", `-e` | `dev-twin.sh:583-587` — `cmd \|\| delete_rc=$?` |
| Atomic file write pattern | Project convention: `setup-floci.sh:822-841` | `dev-twin.sh:599-604` — `.tmp` + `chmod` + `mv -f` |
| `${arr[@]+"${arr[@]}"}` guard | Bash manual, §3.5.3 | `run-test.sh:225`, `run-in-vm.sh:206,208,232` |
| `printf '%q '` is bash 4.0+ | Bash manual, §4.2 "Bash Builtin Commands", `printf` | `run-test.sh:226` — acceptable; guard prevents crash on 3.2 |
