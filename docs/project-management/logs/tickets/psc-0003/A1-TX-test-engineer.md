# A1-TX: Test Engineer Requirements — psc-0003

| Field | Value |
|-------|-------|
| Agent | test-engineer |
| Timestamp | 2026-07-30T23:00:00Z |
| Step | A1-TX |
| Phase | A — Requirements & Design |
| Source | psc-adv-0017-challenge-review (TX-relevant findings) |
| Ticket | psc-0003 |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A — Phase A, no code written | No build to verify at this stage |
| Typed enums / vocabulary types | N/A — bash scripts | Not applicable to shell scripts |
| Documentation on new public symbols | N/A — Phase A | Test specifications are the documentation |
| Spec/datasheet fidelity | yes | All findings cross-referenced to psc-adv-0017 sections |
| Module boundary | yes | Test files correctly scoped: `tests/` for installer, `mock-server/tests/` for harness |
| Reserved/padding fields handled | N/A | Not applicable to bash |
| No magic numbers in doc examples | yes | All test case counts trace to specific finding requirements |
| Buffer safety | N/A | Not applicable to test specifications |
| AGENTS.md compliance | yes | Follows `tests/AGENTS.md` and `mock-server/AGENTS.md` conventions |
| Conventional commit ready | N/A — Phase A | No commits at this stage |

## Test Requirements Analysis

### Overview

This document defines the test requirements for all TX-relevant findings from the challenge advisory `psc-adv-0017-challenge-review`. The findings span four domains: authentication plan (CH-AUTH), test harness (CH-TWIN), and landing zone (CH-LZ). Each finding is mapped to specific test files, test cases, stub requirements, and implementation dependencies.

**Total test cases required: 28 new + 3 modified across 7 test files.**

---

### SPEC-TX-100: CH-AUTH-002 — Prove the forbidden posture is unreachable

**Finding:** The `${VAR:-default}` test-injection pattern in auth plan §4.2 lets `FLOCI_AUTH_MODE=off` + `FLOCI_AUTH_VALIDATE_SIGNATURES=true` produce `signatures=true enforcement=false` — the exact state §4.1 forbids.

**Confidence:** 95 (VERIFIED)

**Test file(s) affected:**
- `tests/phase5.bats` — new test case

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-100-1 | `FLOCI_AUTH_MODE=off` + `FLOCI_AUTH_VALIDATE_SIGNATURES=true` → env file contains `FLOCI_AUTH_VALIDATE_SIGNATURES=false` | The override is **ignored**; the mode-derived value wins. The forbidden `signatures=true enforcement=false` state is unreachable. |

**Implementation detail:** After the §4.2 rewrite (with `FLOCI_AUTH_UNSAFE_OVERRIDE` escape hatch), the test sources `setup-floci.sh` with both env vars set and asserts `write_env_file` emits `FLOCI_AUTH_VALIDATE_SIGNATURES=false`. Uses the existing `_run_fn` pattern from `phase5.bats`.

**Stub requirements:** None — uses existing `_run_fn` + `STUB_OUT_OPENSSL` infrastructure.

**Dependencies on implementation:** CH-AUTH-002 rewrite of §4.2 must be implemented first. The test proves the hole is closed.

---

### SPEC-TX-101: CH-AUTH-004 — 7 bats cases for credential block replacement

**Finding:** `sed '/^\[tianlu-floci-dev\]/,/^\[/d'` destroys the *following* profile's header, orphaning its keys. Must be replaced with `awk` section-aware rewrite + atomic write.

**Confidence:** 98 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/dev_twin.bats` — 7 new test cases

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-101-1 | `[tianlu-floci-dev]` followed by `[default]` → `[default]` header **and** both of its keys survive verbatim; managed block replaced, not duplicated | Neighbouring profile intact |
| SPEC-TX-101-2 | `[tianlu-floci-dev]` as the last section → replaced cleanly, no residue | No trailing orphaned lines |
| SPEC-TX-101-3 | `[tianlu-floci-dev]` absent → block appended, all pre-existing profiles byte-identical | Append-only when absent |
| SPEC-TX-101-4 | Two pre-existing unrelated profiles surrounding the managed block → both intact | Multi-profile survival |
| SPEC-TX-101-5 | File absent → created with mode 0600, single block, `dev_env` exits 0 | Creation from scratch |
| SPEC-TX-101-6 | Idempotency: two consecutive `dev_env` runs produce byte-identical output (no accumulating blank lines, no duplicate blocks) | Idempotent rewrite |
| SPEC-TX-101-7 | Resulting file mode is 0600 and the first non-blank line is a section header | Guards the orphaned-keys failure mode directly |

**Implementation detail:** Each test sets up a `~/.aws/credentials` file in `TEST_TMP`, calls `dev_env`, and asserts the resulting file content. Tests 1–4 verify the `awk` replacement logic; test 5 verifies creation; test 6 verifies idempotency; test 7 verifies permissions and structural integrity.

**Stub requirements:** None — `dev_env` writes to `$HOME/.aws/credentials` which is redirected to `TEST_TMP` via `export HOME="${TEST_TMP}"` (existing pattern at `dev_twin.bats:491`).

**Dependencies on implementation:** CH-AUTH-004 `awk` rewrite + atomic write must be implemented in `dev-twin.sh` `dev_env()`.

---

### SPEC-TX-102: CH-AUTH-006 — bats case for sigv4 security section on both dev_up-fresh and dev_recreate

**Finding:** `_print_next_steps` sigv4 security section is unreachable because `DEV_AUTH_MODE` is never set host-side, and `dev_recreate` never calls `_print_next_steps`.

**Confidence:** 95 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/dev_twin.bats` — 2 new test cases

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-102-1 | `DEV_AUTH_MODE=sigv4` + `DEV_CREDENTIALS_FILE` exists → `_print_next_steps` output includes "Security — bootstrap credential rotation" section with credential location | sigv4 security section appears on fresh install with successful rotation |
| SPEC-TX-102-2 | `DEV_AUTH_MODE=sigv4` + `DEV_CREDENTIALS_FILE` absent → `_print_next_steps` output includes WARNING about well-known public credential | sigv4 security section appears on recreate with failed rotation fallback |

**Implementation detail:** Both tests set `DEV_AUTH_MODE=sigv4` and call `_print_next_steps`. Test 1 creates a mock `DEV_CREDENTIALS_FILE`; test 2 does not. Both assert the security section header appears. Uses existing `_print_next_steps` test pattern at `dev_twin.bats:169-191`.

**Stub requirements:** None.

**Dependencies on implementation:** CH-AUTH-006 (introduce `DEV_AUTH_MODE` constant, call `_print_next_steps` from `dev_recreate`) and CH-AUTH-011 (gate rotation on mode).

---

### SPEC-TX-103: CH-AUTH-010 — Re-derive wait_driver hang; add distinct killed-after-timeout verdict

**Finding:** SPEC-TX-013 specifies "`wait_driver` kills the transport before waiting (no hang)" but `wait_driver` treats any non-zero status as fatal, so killing the transport (exit 143) would produce `TWIN: FAIL` on every run.

**Confidence:** 85 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/completion_protocol.bats` — 1 modified + 2 new test cases

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-103-1 (MODIFY) | `wait_driver` returns 0 for a successful driver (exit 0) | Existing test — verify still passes |
| SPEC-TX-103-2 (MODIFY) | `wait_driver` records a reason for a failed driver (exit 1) | Existing test — verify still records `driver exited nonzero` |
| SPEC-TX-103-3 (NEW) | `wait_driver` with killed-after-timeout (exit 143) produces distinct `killed after timeout` verdict, not `driver exited nonzero` | Distinguish timeout-kill from genuine driver failure |
| SPEC-TX-103-4 (NEW) | `wait_driver` with empty `DRIVER_SHELL_PID` (no driver launched) produces distinct verdict, not `driver exited nonzero (127)` | CH-TWIN-007 fix — empty PID must not produce misleading error |

**Implementation detail:** Test 3 launches a background `sleep 999` process, records its PID, kills it with SIGTERM, then calls `wait_driver`. Asserts `FAIL_REASON` contains "killed" or "timeout" rather than "exited nonzero". Test 4 sets `DRIVER_SHELL_PID=""` and calls `wait_driver`; asserts a distinct verdict.

**Stub requirements:** None — uses real `sleep` and `kill` commands.

**Dependencies on implementation:** CH-AUTH-010 re-derivation of `wait_driver` hang + CH-TWIN-007 fix for empty PID. The implementation must distinguish exit codes: 0 = success, 143 = killed-after-timeout, other non-zero = driver failure.

---

### SPEC-TX-104: CH-AUTH-011 — bats cases for SPEC-TX-002/003 (rotation gated off; stale file not consumed)

**Finding:** `_rotate_bootstrap_credentials` has no auth-mode gate, and §6.4 hardcodes `FLOCI_AUTH_MODE=sigv4` in the dev-twin invocation. SPEC-TX-002/003 specify off-mode behaviour that is unreachable.

**Confidence:** 90 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/dev_twin.bats` — 2 new test cases

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-104-1 (SPEC-TX-002) | `DEV_AUTH_MODE=off` → `_rotate_bootstrap_credentials` is a no-op (no `podman exec` calls, no credential file written) | Rotation gated off in `auth_mode=off` |
| SPEC-TX-104-2 (SPEC-TX-003) | `DEV_AUTH_MODE=off` + stale `DEV_CREDENTIALS_FILE` exists → `dev_env` does NOT consume the stale file; uses `test`/`test` fallback | Stale credential file not consumed in off mode |

**Implementation detail:** Test 1 sets `DEV_AUTH_MODE=off`, calls `_rotate_bootstrap_credentials`, and asserts no `podman exec` stub calls were logged. Test 2 creates a stale `DEV_CREDENTIALS_FILE` with rotated creds, sets `DEV_AUTH_MODE=off`, calls `dev_env`, and asserts the credentials file uses `test`/`test` (not the stale rotated values).

**Stub requirements:** `podman` stub must be on PATH (existing in `mock-server/tests/stubs/bin/`). `_run_as_floci_guest` must be stubbed to log calls.

**Dependencies on implementation:** CH-AUTH-011 (`DEV_AUTH_MODE` constant, gate rotation on mode, pass to installer). The `_rotate_bootstrap_credentials` function must early-return when `DEV_AUTH_MODE=off`.

---

### SPEC-TX-105: CH-TWIN-001 — Verdict on precondition failure

**Finding:** `assert_preconditions` calls `die` → `exit 1` directly, bypassing `FAIL_REASON` + `print_verdict`. CI wrappers grepping for `TWIN:` see nothing.

**Confidence:** 95 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/orchestrator_args.bats` — 2 new test cases
- `mock-server/run-test.sh` — implementation change (not test file; noted for dependency)

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-105-1 | `assert_preconditions` fails (e.g., non-arm64 host) → `main` prints `TWIN: FAIL:` with a reason, not silent exit 1 | Machine-readable verdict on precondition failure |
| SPEC-TX-105-2 | `assert_preconditions` fails → exit code is non-zero | Exit code still signals failure |

**Implementation detail:** Test 1 stubs `uname -m` to return `x86_64`, runs `main`, and asserts output contains `TWIN: FAIL:` with a reason. Test 2 asserts exit code ≠ 0. Requires the implementation change: route preconditions through `FAIL_REASON` + `print_verdict` rather than `die`.

**Stub requirements:** `uname` stub (new symlink to `_stub` in `mock-server/tests/stubs/bin/`). `STUB_OUT_UNAME` for architecture override.

**Dependencies on implementation:** CH-TWIN-001 — `assert_preconditions` must set `FAIL_REASON` and return non-zero instead of calling `die`. `main` must call `print_verdict` on the precondition failure path.

---

### SPEC-TX-106: CH-TWIN-002 — sidecar-delta in mandatory array

**Finding:** `sidecar-delta` is not in the `mandatory` array in `validate_summary`, so the `if [[ "$c" == "sidecar-delta" && "$NO_SIDECAR" == true ]]` branch is unreachable. The guest driver initialises `CRITERIA[sidecar-delta]=FAIL`, so any future path that publishes `DONE` without setting it would pass unnoticed.

**Confidence:** 92 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/completion_protocol.bats` — 2 new test cases

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-106-1 | `sidecar-delta` in summary with status `PASS` → `validate_summary` passes (when `NO_SIDECAR=false`) | sidecar-delta is now a mandatory criterion |
| SPEC-TX-106-2 | `sidecar-delta` in summary with status `SKIPPED` → `validate_summary` passes when `NO_SIDECAR=true` | SKIPPED is acceptable when sidecar test is disabled |

**Implementation detail:** Test 1 adds `sidecar-delta` with `PASS` to the summary, sets `NO_SIDECAR=false`, and asserts `validate_summary` returns 0. Test 2 adds `sidecar-delta` with `SKIPPED`, sets `NO_SIDECAR=true`, and asserts `validate_summary` returns 0. Both tests also verify that `sidecar-delta` with `FAIL` is rejected.

**Stub requirements:** None — uses existing summary.md fixture pattern.

**Dependencies on implementation:** CH-TWIN-002 — add `sidecar-delta` to the `mandatory` array in `run-test.sh:451`.

---

### SPEC-TX-107: CH-TWIN-003 — Replace or drop journal ordering check

**Finding:** The journal line-number comparison at `run-test.sh:394-402` compares the first `grep -n` match of `podman.socket` against `floci.service` in a single-boot journal. Journal line order is not activation order, and any earlier *mention* of the socket satisfies it regardless of actual start sequence.

**Confidence:** 85 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/completion_protocol.bats` — 1 modified test case
- `mock-server/run-test.sh` — implementation change (not test file; noted for dependency)

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-107-1 (MODIFY) | `validate_summary` accepts `reboot-ordering=PASS` under `--reboot-test` when property assertions (`After=podman.socket`, `Requires=podman.socket`, `service_active`) are satisfied | The property assertions are the real evidence; journal comparison is removed |

**Implementation detail:** The existing `validate_summary accepts reboot-ordering=PASS under --reboot-test` test (completion_protocol.bats:142-173) continues to work unchanged — it already tests the property-based assertions. The journal comparison code in `run-test.sh:394-402` is removed, so no new test is needed for the removed code. The existing test proves the property assertions are sufficient.

**Stub requirements:** None.

**Dependencies on implementation:** CH-TWIN-003 — remove the journal line-number comparison from `run_reboot_test` (lines 394-402). The property assertions at lines 376-391 are the real evidence and remain.

---

### SPEC-TX-108: CH-TWIN-004 — Fix stale-sentinel cleanup path

**Finding:** `rm -f "${HOST_EVIDENCE_MOUNT}/DONE" "${HOST_EVIDENCE_MOUNT}/FAILED"` at `run-test.sh:181` targets the wrong directory — sentinels live in `$STAGING`. Harmless because `rm -rf "$STAGING"` at line 180 does the real work, but reads as a guard that is not one.

**Confidence:** 100 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/completion_protocol.bats` — 1 new test case

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-108-1 | After `ensure_twin`, `$STAGING/DONE` and `$STAGING/FAILED` do not exist (stale sentinels cleaned from correct path) | Sentinels cleaned from staging, not evidence mount |

**Implementation detail:** Test sets up `STAGING` with pre-existing `DONE` and `FAILED` files, calls `ensure_twin` (with stubbed `limactl`), and asserts both files are removed from `$STAGING`. Also asserts the `HOST_EVIDENCE_MOUNT` path is NOT touched for sentinel cleanup.

**Stub requirements:** `limactl` stub (existing in `mock-server/tests/stubs/bin/`). `STUB_OUT_LIMACTL` for twin status.

**Dependencies on implementation:** CH-TWIN-004 — fix the sentinel cleanup path to target `$STAGING` instead of `$HOST_EVIDENCE_MOUNT`, or remove the redundant lines since `rm -rf "$STAGING"` already handles it.

---

### SPEC-TX-109: CH-TWIN-005 — Document evidence-dir split

**Finding:** `--evidence-dir` only relocates the final copy; `HOST_EVIDENCE_MOUNT` and `STAGING` are hardcoded to `${HOST_HOME}/.cache/tianlu-twin/evidence` because that path is the 9p mount. `usage` implies the flag moves the evidence directory.

**Confidence:** 95 (VERIFIED)

**Test file(s) affected:**
- No test code changes — documentation-only finding. The `usage` text and `docs/design/digital-twin-testing-design.md` must be updated.

**Test cases needed:** None. This is a documentation fix. The existing `--evidence-dir` test at `orchestrator_args.bats:43-46` continues to verify the flag is parsed correctly.

**Stub requirements:** None.

**Dependencies on implementation:** CH-TWIN-005 — update `usage()` in `run-test.sh` and `docs/design/digital-twin-testing-design.md` to document the split: `--evidence-dir` relocates the final copy only; the 9p staging path is fixed.

---

### SPEC-TX-110: CH-TWIN-006 — Resolve --fresh/--keep semantics

**Finding:** `--fresh` sets `KEEP=false` but `teardown` does nothing when `DESTROY=false` and `KEEP=false` — the VM is left running exactly as with `--keep`. `usage` presents them as alternatives but they are not opposites. Also order-dependent: `--keep` after `--fresh` is ignored but `--fresh` after `--keep` wins.

**Confidence:** 95 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/orchestrator_args.bats` — 2 new + 1 modified test case

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-110-1 (MODIFY) | `--fresh` sets `FRESH=true` and `KEEP=false` | Existing test — verify semantics are consistent after fix |
| SPEC-TX-110-2 (NEW) | `--fresh` + no `--destroy` → `teardown` stops and deletes the twin (fresh implies teardown) | `--fresh` implies cleanup, not just non-keep |
| SPEC-TX-110-3 (NEW) | `--keep` after `--fresh` is rejected (order-independent: last wins, or error on conflict) | No silent precedence — either last-wins or error |

**Implementation detail:** Test 2 sets `FRESH=true`, `KEEP=false`, `DESTROY=false`, calls `teardown`, and asserts `limactl stop` + `limactl delete` were invoked. Test 3 passes `--fresh --keep` to `parse_args` and asserts either `KEEP=true` (last-wins) or a failure reason (conflict error). The user decision on semantics determines which assertion.

**Stub requirements:** `limactl` stub (existing).

**Dependencies on implementation:** CH-TWIN-006 — resolve the `--fresh`/`--keep` semantics. Decision needed: does `--fresh` imply teardown, or is it just "don't reuse"? The test cases adapt to either decision.

---

### SPEC-TX-111: CH-TWIN-007 — Fix wait "${DRIVER_SHELL_PID:-}" and HOST_HOME fallback

**Finding:** Two robustness gaps:
1. `wait "${DRIVER_SHELL_PID:-}"` with an empty PID yields 127, producing `driver exited nonzero (127) despite DONE`
2. `HOST_HOME="${HOME:-$(id -un)}"` falls back to a *username* where a path is required

**Confidence:** 90 (VERIFIED)

**Test file(s) affected:**
- `mock-server/tests/completion_protocol.bats` — 1 new test case (covered by SPEC-TX-103-4)
- `mock-server/tests/orchestrator_args.bats` — 1 new test case

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-111-1 | `HOST_HOME` unset, `HOME` unset → script fails with clear error, not a username-derived path | `HOST_HOME` fallback must be a path, not a username |
| SPEC-TX-111-2 | `wait_driver` with empty `DRIVER_SHELL_PID` → distinct verdict, not `driver exited nonzero (127)` | Covered by SPEC-TX-103-4 |

**Implementation detail:** Test 1 unsets both `HOME` and `HOST_HOME`, sources `run-test.sh`, and asserts it exits with a clear error message (not silently using a username as a path). This requires the implementation to `die` or set `FAIL_REASON` when `HOME` is unset.

**Stub requirements:** None — tests the script's own error handling.

**Dependencies on implementation:** CH-TWIN-007 — fix `HOST_HOME` fallback to fail instead of using `$(id -un)`. Fix `wait_driver` to handle empty PID.

---

### SPEC-TX-112: CH-LZ-001 + CH-LZ-002 — G6 permissions boundary negative test

**Finding:** `DenyAllExceptBoundary` is an unconditional deny (CH-LZ-001). The permissions-boundary *evaluation* is claimed as enforced but never gated (CH-LZ-002). Need a G6 gate that proves the boundary actually restricts permissions.

**Confidence:** 92 (CH-LZ-001), 85 (CH-LZ-002)

**Test file(s) affected:**
- `tests/preflight.bats` (NEW) — 3 new test cases

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-112-1 (G6 negative) | Mint a role with a boundary denying `s3:*`, attach an identity policy allowing `s3:ListAllMyBuckets`, assume the role, call `s3:ListAllMyBuckets` → **denied** | Permissions boundary is evaluated and restricts effective permissions |
| SPEC-TX-112-2 (G6 positive control) | Same role without the boundary → `s3:ListAllMyBuckets` **succeeds** | Identity policy alone would allow the call; boundary is the restricting factor |
| SPEC-TX-112-3 (G6 gate label) | G6 appears in preflight output with correct label referencing both `FLOCI_AUTH_VALIDATE_SIGNATURES` and `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` | Gate is discoverable and correctly documented |

**Implementation detail:** These tests are **stubbed unit tests** — they test the `gate_g6_boundary()` function in `scripts/preflight-floci.sh` by stubbing `aws` CLI calls. Test 1 stubs `aws iam create-role`, `aws iam put-role-policy`, `aws iam create-access-key`, `aws sts assume-role`, and `aws s3 list-buckets` to return `AccessDenied`. Test 2 stubs the same sequence but with the boundary detached, returning success. Test 3 sources the script and greps for G6 in the output.

**Stub requirements:** `aws` stub (existing symlink to `_stub` in `tests/stubs/bin/`). Need `STUB_OUT_AWS` with per-subcommand control (similar to `podman` stub pattern) for the multi-step IAM workflow. Alternatively, use a dedicated `aws` stub that reads `STUB_OUT_AWS_CREATE_ROLE`, `STUB_OUT_AWS_ASSUME_ROLE`, etc.

**Dependencies on implementation:** CH-LZ-001 (three-statement boundary form in `10-management-iam/main.tf`) + CH-LZ-002 (G6 gate function in `scripts/preflight-floci.sh`). The G6 gate must be implemented before the test can be written.

---

### SPEC-TX-113: CH-LZ-004 — G1 must fail (not skip) when probe cannot be established

**Finding:** If `create-access-key` fails, G1 calls `skip` and returns. `skip` does not set `FAILED`, so `main` reports "automated gates passed" and exits 0. Under `sigv4` with default credentials the call always fails (CH-AUTH-001), so the gate the design calls a hard stop reports success.

**Confidence:** 95 (VERIFIED)

**Test file(s) affected:**
- `tests/preflight.bats` (NEW) — 2 new test cases

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-113-1 | G1: `create-access-key` fails → gate reports FAIL (not SKIP), `FAILED=1` is set | Unestablished gate is a failure, not a skip |
| SPEC-TX-113-2 | `main` exits non-zero when any automated gate (G1, G3) produces SKIP | SKIP on automated gates is treated as failure at the script level |

**Implementation detail:** Test 1 stubs `aws iam create-access-key` to fail (exit 1), runs `gate_g1_signatures`, and asserts `FAILED=1` and the output contains `FAIL` not `SKIP`. Test 2 stubs G1 to skip and G3 to pass, runs `main`, and asserts exit code ≠ 0.

**Stub requirements:** `aws` stub (existing). `STUB_RC_AWS` for failure injection.

**Dependencies on implementation:** CH-LZ-004 — G1 must call `fail` instead of `skip` when the probe cannot be established. `main` must exit non-zero on any SKIP among automated gates.

---

### SPEC-TX-114: CH-LZ-007 — G3b for S3 conditional PutObject

**Finding:** `use_lockfile` uses S3 conditional `PutObject` with `IfNoneMatch: "*"` — a distinct capability from the DynamoDB conditional write G3 verifies. No gate exists for it.

**Confidence:** 90 (CITED)

**Test file(s) affected:**
- `tests/preflight.bats` (NEW) — 1 new test case

**Test cases needed:**

| ID | Test Case | Assertion |
|----|-----------|-----------|
| SPEC-TX-114-1 (G3b) | `aws s3api put-object --if-none-match '*'` twice on the same key → second call fails with `PreconditionFailed` | S3 conditional PutObject is enforced; `use_lockfile` is safe |

**Implementation detail:** Test stubs `aws s3api create-bucket`, `aws s3api put-object` (first call succeeds, second fails with `PreconditionFailed` error), runs `gate_g3b_s3_lock()`, and asserts PASS.

**Stub requirements:** `aws` stub with per-subcommand output control. `STUB_OUT_AWS_S3API_PUT_OBJECT_1` and `STUB_OUT_AWS_S3API_PUT_OBJECT_2` for the two calls, or a counter-based approach.

**Dependencies on implementation:** CH-LZ-007 — add `gate_g3b_s3_lock()` function to `scripts/preflight-floci.sh`.

---

## Test File Summary

| Test File | New Tests | Modified Tests | Total | Findings Covered |
|-----------|-----------|----------------|-------|------------------|
| `tests/phase5.bats` | 1 | 0 | 1 | CH-AUTH-002 |
| `mock-server/tests/dev_twin.bats` | 11 | 0 | 11 | CH-AUTH-004 (7), CH-AUTH-006 (2), CH-AUTH-011 (2) |
| `mock-server/tests/completion_protocol.bats` | 4 | 2 | 6 | CH-AUTH-010 (2+2mod), CH-TWIN-002 (2), CH-TWIN-004 (1), CH-TWIN-007 (1, shared with SPEC-TX-103-4) |
| `mock-server/tests/orchestrator_args.bats` | 4 | 1 | 5 | CH-TWIN-001 (2), CH-TWIN-006 (2+1mod), CH-TWIN-007 (1) |
| `tests/preflight.bats` (NEW) | 6 | 0 | 6 | CH-LZ-001/002 (3), CH-LZ-004 (2), CH-LZ-007 (1) |
| **Total** | **26** | **3** | **29** | |

Note: SPEC-TX-103-4 and SPEC-TX-111-2 are the same test case (empty PID handling) — counted once.

## Stub Requirements Summary

### New stubs needed in `tests/stubs/bin/`:

| Stub | Purpose | Control Variables |
|------|---------|-------------------|
| `aws` (enhanced) | Per-subcommand output/rc control for multi-step IAM workflows in preflight tests | `STUB_OUT_AWS_IAM_CREATE_ROLE`, `STUB_OUT_AWS_STS_ASSUME_ROLE`, `STUB_RC_AWS_IAM_CREATE_ACCESS_KEY`, etc. |

The existing `aws` symlink to `_stub` may need enhancement to support per-subcommand control, similar to the `podman` stub pattern. Alternatively, the preflight tests can use a dedicated `aws` wrapper that reads subcommand-specific env vars.

### New stubs needed in `mock-server/tests/stubs/bin/`:

| Stub | Purpose | Control Variables |
|------|---------|-------------------|
| `uname` | Architecture override for precondition failure tests | `STUB_OUT_UNAME` |

### Existing stubs sufficient:

- `limactl` — already in `mock-server/tests/stubs/bin/`
- `podman` — already in `mock-server/tests/stubs/bin/`
- `systemctl` — already in `mock-server/tests/stubs/bin/`
- `_run_as_floci_guest` — stubbed in dev_twin.bats test helper

## Implementation Dependencies

Tests must be written in TDD order: RED (write failing test) → implementation → GREEN (test passes).

| Priority | Finding | Depends On | Blocks |
|----------|---------|------------|--------|
| 1 | CH-AUTH-002 | §4.2 rewrite with `FLOCI_AUTH_UNSAFE_OVERRIDE` | Nothing — can be written first |
| 2 | CH-AUTH-004 | `awk` rewrite + atomic write in `dev_env()` | Nothing — can be written first |
| 3 | CH-AUTH-006 | `DEV_AUTH_MODE` constant + `_print_next_steps` from `dev_recreate` | CH-AUTH-011 |
| 4 | CH-AUTH-011 | `DEV_AUTH_MODE` constant + rotation gate | CH-AUTH-006 |
| 5 | CH-AUTH-010 | `wait_driver` re-derivation | CH-TWIN-007 |
| 6 | CH-TWIN-001 | Precondition routing through `FAIL_REASON` | Nothing |
| 7 | CH-TWIN-002 | `sidecar-delta` in `mandatory` array | Nothing |
| 8 | CH-TWIN-003 | Journal comparison removal | Nothing |
| 9 | CH-TWIN-004 | Sentinel cleanup path fix | Nothing |
| 10 | CH-TWIN-006 | `--fresh`/`--keep` semantics decision | Nothing |
| 11 | CH-TWIN-007 | `HOST_HOME` fallback + empty PID fix | CH-AUTH-010 |
| 12 | CH-LZ-001/002 | G6 gate implementation + boundary fix | Nothing |
| 13 | CH-LZ-004 | G1 fail-on-unestablished | Nothing |
| 14 | CH-LZ-007 | G3b gate implementation | Nothing |

## Verdict

**VERDICT: APPROVED**

**COVERAGE: 16/16 TX-relevant findings have test specifications**

**GAPS: None** — every TX-relevant finding from psc-adv-0017 has been analysed and mapped to specific test cases with file locations, stub requirements, and implementation dependencies.

**ROUTING: N/A** — Phase A analysis is complete. Proceed to Phase B (parallel test writing) when implementation of each finding begins.

## Notes

1. **CH-TWIN-005** (evidence-dir split documentation) requires no test code changes — it is a documentation-only fix to `usage()` and `docs/design/digital-twin-testing-design.md`. Included in scope for completeness.

2. **CH-TWIN-003** (journal ordering check) — the recommended fix is to *remove* the journal comparison code. The existing property-assertion tests in `completion_protocol.bats` already cover the real evidence. No new test is needed for removed code.

3. **Preflight test file** (`tests/preflight.bats`) is new. It follows the existing `tests/AGENTS.md` conventions: `_run_fn` subshell pattern, `STUB_BIN` on PATH, `aws` stub for CLI isolation.

4. **`aws` stub enhancement** — the preflight tests (G1, G3b, G6) require per-subcommand output control for multi-step IAM workflows. The existing `aws` symlink to `_stub` may need to be replaced with a subcommand-aware stub similar to `tests/stubs/bin/podman`. This is a Phase B implementation detail.

5. **Test count reconciliation with auth plan §6.11** — the auth plan §6.11 lists 40 test cases for psc-0002. This document adds 29 test cases for psc-0003 (the challenge-advisory remediation). Some psc-0002 tests (SPEC-TX-002, SPEC-TX-003, SPEC-TX-006, SPEC-TX-013) are modified or superseded by psc-0003 findings; the implementation phase must reconcile the two sets.
