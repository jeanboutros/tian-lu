# C2-TX: Test Engineer Verification — psc-0003

| Field | Value |
|-------|-------|
| Agent | test-engineer |
| Timestamp | 2026-07-30T23:45:00Z |
| Step | C2-TX |
| Phase | C — Verification |
| Ticket | psc-0003 |
| Source | A1-TX-test-engineer.md (14 SPEC-TX, 28 new + 3 modified test cases) |
| Re-scope | M-1 (ACCEPTED) — re-scope to all 49 findings |

## Build Evidence

```
$ make test 2>&1
bats tests/           → 133 tests, 132 pass, 0 fail, 1 skip
bats mock-server/tests/ → 119 tests, 118 pass, 1 fail*, 0 skip
Total: 252 tests, 250 pass, 1 fail*, 1 skip
```

\* Pre-existing failure: `dev_up Absent path: disk create before limactl start` (mock-server/tests/dev_twin.bats test 77) — unrelated to psc-0003, predates the ticket.

Skip: `G1: must fail (not skip) when probe cannot be established (CH-LZ-004)` (tests/preflight.bats test 101) — intentional per M-9 BACKLOG.

## SPEC-TX Verification Matrix

### SPEC-TX-100: CH-AUTH-002 — Forbidden posture unreachable

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-100-1 | `FLOCI_AUTH_MODE=off` + `FLOCI_AUTH_VALIDATE_SIGNATURES=true` → env file has `false` | `tests/phase5.bats:372-379` | 72 | ✅ PASS |

**Verdict: IMPLEMENTED** — The hole is proven closed. The mode-derived value wins; the forbidden `signatures=true enforcement=false` state is unreachable.

---

### SPEC-TX-101: CH-AUTH-004 — 7 bats cases for credential block replacement

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-101-1 | `[default]` header and keys survive after managed block | `dev_twin.bats:517-536` | 88 | ✅ PASS |
| SPEC-TX-101-2 | Managed block as last section → replaced cleanly | `dev_twin.bats:539-558` | 89 | ✅ PASS |
| SPEC-TX-101-3 | Managed block absent → appended, pre-existing profiles intact | `dev_twin.bats:561-578` | 90 | ✅ PASS |
| SPEC-TX-101-4 | Two profiles surrounding managed block → both survive | `dev_twin.bats:581-600` | 91 | ✅ PASS |
| SPEC-TX-101-5 | File absent → created with mode 0600, single block | `dev_twin.bats:603-624` | 92 | ✅ PASS |
| SPEC-TX-101-6 | Idempotency: two runs produce byte-identical output | `dev_twin.bats:627-641` | 93 | ✅ PASS |
| SPEC-TX-101-7 | File mode 0600, first non-blank line is section header | `dev_twin.bats:644-662` | 94 | ✅ PASS |

**Verdict: IMPLEMENTED** — All 7 test cases pass. The `awk` section-aware rewrite + atomic write is verified.

---

### SPEC-TX-102: CH-AUTH-006 — sigv4 security section on dev_up-fresh and dev_recreate

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-102-1 | `DEV_AUTH_MODE=sigv4` + `DEV_CREDENTIALS_FILE` exists → security section appears | `dev_twin.bats:722-732` | 98 | ⚠️ PARTIAL |
| SPEC-TX-102-2 | `DEV_AUTH_MODE=sigv4` + `DEV_CREDENTIALS_FILE` absent → WARNING about well-known credential | NOT IMPLEMENTED | — | ❌ GAP |

**Verdict: PARTIAL** — Test 98 verifies `_print_next_steps` is callable with sigv4 mode, but contains a TODO comment: `TODO(CH-AUTH-006): when sigv4 security section is implemented, assert: [[ "$output" == *"Security"* || "$output" == *"bootstrap credential rotation"* ]]`. The sigv4 security section assertion is deferred. SPEC-TX-102-2 (failed rotation fallback) is not implemented at all.

**Gap:** The A1 requirement specifies two distinct test cases: one for successful rotation (security section with credential location) and one for failed rotation (WARNING about well-known public credential). Only the callability test exists; neither the success-path assertion nor the failure-path assertion is implemented.

---

### SPEC-TX-103: CH-AUTH-010 — wait_driver four-outcome dispatch

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-103-1 (MODIFY) | `wait_driver` returns 0 for successful driver (exit 0) | `completion_protocol.bats:54-62` | 19 | ✅ PASS |
| SPEC-TX-103-2 (MODIFY) | `wait_driver` records reason for failed driver (exit 1) | `completion_protocol.bats:64-73` | 20 | ✅ PASS |
| SPEC-TX-103-3 (NEW) | `wait_driver` with killed-after-timeout (exit 143) → distinct verdict | `completion_protocol.bats:75-85` | 21 | ✅ PASS |
| SPEC-TX-103-4 (NEW) | `wait_driver` with empty `DRIVER_SHELL_PID` → distinct verdict | `completion_protocol.bats:87-95` | 22 | ✅ PASS |

**Verdict: IMPLEMENTED** — All four outcomes (success, driver failure, killed-after-timeout, empty PID) are tested and pass. The four-outcome dispatch is verified.

---

### SPEC-TX-104: CH-AUTH-011 — Rotation gated off; stale file not consumed

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-104-1 (SPEC-TX-002) | `DEV_AUTH_MODE=off` → `_rotate_bootstrap_credentials` is no-op | `dev_twin.bats:697-706` | 96 | ✅ PASS |
| SPEC-TX-104-2 (SPEC-TX-003) | `DEV_AUTH_MODE=off` + stale `DEV_CREDENTIALS_FILE` → `dev_env` uses `test`/`test` | `dev_twin.bats:708-720` | 97 | ✅ PASS |

**Verdict: IMPLEMENTED** — Both test cases pass. Rotation is gated off in `auth_mode=off`; stale credential file is not consumed.

---

### SPEC-TX-105: CH-TWIN-001 — Verdict on precondition failure

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-105-1 | `assert_preconditions` fails → `main` prints `TWIN: FAIL:` with reason | NOT IMPLEMENTED | — | ❌ GAP |
| SPEC-TX-105-2 | `assert_preconditions` fails → exit code is non-zero | NOT IMPLEMENTED | — | ❌ GAP |

**Verdict: NOT IMPLEMENTED** — `mock-server/tests/orchestrator_args.bats` has 17 tests (lines 1-77); none test precondition failure verdict routing. The A1 requirement specified 2 new test cases in this file. The implementation change (CH-TWIN-001) was applied to `run-test.sh` per B2-8, but no test verifies the behaviour.

**Gap:** Without these tests, there is no automated verification that precondition failures produce machine-readable `TWIN: FAIL:` output. CI wrappers grepping for `TWIN:` could silently miss precondition failures.

---

### SPEC-TX-106: CH-TWIN-002 — sidecar-delta in mandatory array

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-106-1 | `sidecar-delta` with `PASS` → `validate_summary` passes (`NO_SIDECAR=false`) | `completion_protocol.bats:97-128` | 23 | ✅ PASS (implicit) |
| SPEC-TX-106-2 | `sidecar-delta` with `SKIPPED` → `validate_summary` passes when `NO_SIDECAR=true` | NOT EXPLICITLY TESTED | — | ⚠️ GAP |

**Verdict: PARTIAL** — The `sidecar-delta` criterion appears in all `validate_summary` test fixtures with `PASS` status, which implicitly verifies it is now in the mandatory array (the tests pass). However, the specific `SKIPPED` + `NO_SIDECAR=true` acceptance path is not tested. The A1 requirement explicitly calls for this case: "sidecar-delta in summary with status SKIPPED → validate_summary passes when NO_SIDECAR=true."

**Gap:** The `NO_SIDECAR=true` branch in `validate_summary` (the special case at the old line 502) is now live code but has no test coverage for its acceptance path. Only the `PASS` path is exercised.

---

### SPEC-TX-107: CH-TWIN-003 — Replace or drop journal ordering check

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-107-1 (MODIFY) | `validate_summary` accepts `reboot-ordering=PASS` under `--reboot-test` with property assertions | `completion_protocol.bats:164-195` | 25 | ✅ PASS |

**Verdict: IMPLEMENTED** — The journal line-number comparison was removed per B2-8. The property-assertion tests (`After=podman.socket`, `Requires=podman.socket`, `service_active`) remain as the real evidence and continue to pass.

---

### SPEC-TX-108: CH-TWIN-004 — Fix stale-sentinel cleanup path

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-108-1 | After `ensure_twin`, `$STAGING/DONE` and `$STAGING/FAILED` do not exist | NOT IMPLEMENTED | — | ❌ GAP |

**Verdict: NOT IMPLEMENTED** — No test verifies that stale sentinels are cleaned from `$STAGING` (the correct path) rather than `$HOST_EVIDENCE_MOUNT`. The implementation change (CH-TWIN-004) removed the redundant `rm -f` line per B2-8, but no test verifies the cleanup behaviour.

**Gap:** The A1 requirement specifies a test that sets up pre-existing `DONE` and `FAILED` files in `$STAGING`, calls `ensure_twin`, and asserts both are removed. This test would catch a regression where sentinel cleanup targets the wrong directory.

---

### SPEC-TX-109: CH-TWIN-005 — Document evidence-dir split

**Verdict: N/A** — Documentation-only finding. Per B2-8, `usage()` was updated with a doc comment explaining the evidence-dir split. No test code changes required per A1.

---

### SPEC-TX-110: CH-TWIN-006 — Resolve --fresh/--keep semantics

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-110-1 (MODIFY) | `--fresh` sets `FRESH=true` and `KEEP=false` | `orchestrator_args.bats:13-17` | 100 | ✅ PASS |
| SPEC-TX-110-2 (NEW) | `--fresh` + no `--destroy` → `teardown` stops and deletes twin | NOT IMPLEMENTED | — | ❌ GAP |
| SPEC-TX-110-3 (NEW) | `--keep` after `--fresh` is rejected (mutual exclusion) | NOT IMPLEMENTED | — | ❌ GAP |

**Verdict: PARTIAL** — Only 1 of 3 required test cases is implemented. The existing test (100) verifies the basic flag parsing. The two new test cases from the A1 requirements are missing:

- **SPEC-TX-110-2:** Per D-22 (challenger win), `--fresh` implies `--destroy`. The A1 requirement specifies a test that sets `FRESH=true`, `KEEP=false`, `DESTROY=false`, calls `teardown`, and asserts `limactl stop` + `limactl delete` were invoked. This test would verify that `--fresh` actually triggers teardown, not just non-keep.
- **SPEC-TX-110-3:** Per D-22, `--fresh` and `--keep` are mutually exclusive. The A1 requirement specifies a test that passes `--fresh --keep` to `parse_args` and asserts either `KEEP=true` (last-wins) or a failure reason (conflict error). The B2-8 implementation chose mutual exclusion with error, but no test verifies this.

**Gap:** The mutual exclusion between `--fresh` and `--keep` is implemented but untested. A regression could silently restore the pre-fix behaviour where `--keep` after `--fresh` is silently ignored.

---

### SPEC-TX-111: CH-TWIN-007 — Fix HOST_HOME fallback and empty PID

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-111-1 | `HOST_HOME` unset, `HOME` unset → script fails with clear error | NOT IMPLEMENTED | — | ❌ GAP |
| SPEC-TX-111-2 | `wait_driver` with empty `DRIVER_SHELL_PID` → distinct verdict | `completion_protocol.bats:87-95` | 22 | ✅ PASS (shared with SPEC-TX-103-4) |

**Verdict: PARTIAL** — 1 of 2 test cases implemented. The empty-PID test (shared with SPEC-TX-103-4) passes. The HOST_HOME fallback test is missing.

**Gap:** The A1 requirement specifies a test that unsets both `HOME` and `HOST_HOME`, sources `run-test.sh`, and asserts it exits with a clear error message (not silently using a username as a path). The B2-8 implementation changed `HOST_HOME="${HOME:-$(id -un)}"` to `HOST_HOME="${HOME:?HOME is not set — cannot determine host home directory}"`, but no test verifies this error path.

---

### SPEC-TX-112: CH-LZ-001 + CH-LZ-002 — G6 permissions boundary negative test

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-112-1 (G6 negative) | Role with boundary denying `s3:*` + identity policy allowing `s3:ListAllMyBuckets` → denied | NOT IMPLEMENTED | — | ❌ GAP |
| SPEC-TX-112-2 (G6 positive control) | Same role without boundary → `s3:ListAllMyBuckets` succeeds | NOT IMPLEMENTED | — | ❌ GAP |
| SPEC-TX-112-3 (G6 gate label) | G6 appears in preflight output with correct label | NOT IMPLEMENTED | — | ❌ GAP |

**Verdict: NOT IMPLEMENTED** — `tests/preflight.bats` has 9 tests covering G1, G3, G2, and `main`, but no G6 tests. Per B2-9, the G6 gate implementation was deferred to Unit 12 with a comment block noting "G6 (permissions-boundary evaluation gate) must be added to `scripts/preflight-floci.sh`." B2-12 (Unit 12 — Tests) does not include G6 tests.

**Gap:** CH-LZ-001 (three-statement boundary form) was implemented in `infra/live/10-management-iam/main.tf` per B2-9. CH-LZ-002 (G6 gate) was noted as deferred. Without G6 tests, there is no automated verification that Floci actually evaluates permissions boundaries. The A1 requirement specified 3 test cases using stubbed `aws` CLI calls to verify the boundary restricts effective permissions.

---

### SPEC-TX-113: CH-LZ-004 — G1 must fail (not skip) when probe cannot be established

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-113-1 | G1: `create-access-key` fails → gate reports FAIL, `FAILED=1` set | `preflight.bats:68-74` | 101 | ⏭️ SKIPPED (M-9 BACKLOG) |
| SPEC-TX-113-2 | `main` exits non-zero when any automated gate produces SKIP | NOT IMPLEMENTED | — | ❌ GAP |

**Verdict: NOT IMPLEMENTED** — Test 101 is intentionally skipped with the comment: `TODO(CH-LZ-004): G1 currently calls skip() on create-access-key failure — needs implementation to call fail() instead. Per M-9 BACKLOG.` SPEC-TX-113-2 is not implemented at all.

**Gap:** Per M-9 (BACKLOG), the G1 fail-on-unestablished implementation is deferred. The test exists as a skipped placeholder documenting the expected behaviour. SPEC-TX-113-2 (main exit code on automated-gate SKIP) has no test at all.

---

### SPEC-TX-114: CH-LZ-007 — G3b for S3 conditional PutObject

| ID | Required | Implemented | Test # | Status |
|----|----------|-------------|--------|--------|
| SPEC-TX-114-1 (G3b) | `aws s3api put-object --if-none-match '*'` twice → second call fails with `PreconditionFailed` | NOT IMPLEMENTED | — | ❌ GAP |

**Verdict: NOT IMPLEMENTED** — No G3b test exists in `tests/preflight.bats`. The A1 requirement specified a test using a counter-based `aws` stub to verify S3 conditional PutObject enforcement.

**Gap:** CH-LZ-007 (`use_lockfile` uses S3 conditional `PutObject` with `IfNoneMatch: "*"`) has no gate and no test. The `use_lockfile` function in the Terraform backend bootstrap depends on this capability, but it is not verified by any automated gate.

---

## Coverage Summary

| SPEC-TX | Finding(s) | Test Cases Required | Implemented | Passing | Status |
|----------|------------|---------------------|-------------|---------|--------|
| SPEC-TX-100 | CH-AUTH-002 | 1 | 1 | 1 | ✅ FULL |
| SPEC-TX-101 | CH-AUTH-004 | 7 | 7 | 7 | ✅ FULL |
| SPEC-TX-102 | CH-AUTH-006 | 2 | 1 | 1 | ⚠️ PARTIAL |
| SPEC-TX-103 | CH-AUTH-010 | 4 | 4 | 4 | ✅ FULL |
| SPEC-TX-104 | CH-AUTH-011 | 2 | 2 | 2 | ✅ FULL |
| SPEC-TX-105 | CH-TWIN-001 | 2 | 0 | 0 | ❌ GAP |
| SPEC-TX-106 | CH-TWIN-002 | 2 | 1 | 1 | ⚠️ PARTIAL |
| SPEC-TX-107 | CH-TWIN-003 | 1 | 1 | 1 | ✅ FULL |
| SPEC-TX-108 | CH-TWIN-004 | 1 | 0 | 0 | ❌ GAP |
| SPEC-TX-109 | CH-TWIN-005 | 0 | N/A | N/A | ✅ N/A |
| SPEC-TX-110 | CH-TWIN-006 | 3 | 1 | 1 | ⚠️ PARTIAL |
| SPEC-TX-111 | CH-TWIN-007 | 2 | 1 | 1 | ⚠️ PARTIAL |
| SPEC-TX-112 | CH-LZ-001/002 | 3 | 0 | 0 | ❌ GAP |
| SPEC-TX-113 | CH-LZ-004 | 2 | 1 (skipped) | 0 | ❌ GAP (M-9 BACKLOG) |
| SPEC-TX-114 | CH-LZ-007 | 1 | 0 | 0 | ❌ GAP |
| **Total** | | **33** | **20** | **19** | |

**Test cases required (per A1):** 28 new + 3 modified + 2 documentation-only = 33 total (counting modified separately)
**Test cases implemented and passing:** 19
**Test cases partially implemented (TODO/skipped):** 2 (SPEC-TX-102-1 partial, SPEC-TX-113-1 skipped)
**Test cases not implemented:** 12

## Gap Analysis

### Blocking Gaps (confidence ≥ 80)

| # | Gap | SPEC-TX | Confidence | Rationale |
|---|-----|---------|------------|-----------|
| G1 | No precondition verdict routing test | SPEC-TX-105 | 90 | CH-TWIN-001 implementation exists but is untested. CI wrappers grepping for `TWIN:` could silently miss precondition failures. |
| G2 | No stale-sentinel cleanup test | SPEC-TX-108 | 85 | CH-TWIN-004 implementation exists but is untested. A regression could reintroduce the wrong-path cleanup. |
| G3 | No G6 permissions boundary tests | SPEC-TX-112 | 92 | CH-LZ-001 (boundary policy) is implemented but CH-LZ-002 (G6 gate) is deferred. Without G6 tests, there is no verification that Floci evaluates boundaries. |
| G4 | No G3b S3 conditional PutObject test | SPEC-TX-114 | 90 | CH-LZ-007 has no gate and no test. `use_lockfile` depends on this capability. |
| G5 | No --fresh/--keep mutual exclusion test | SPEC-TX-110-3 | 88 | D-22 (challenger win) mandated mutual exclusion. The implementation exists per B2-8 but is untested. |
| G6 | No --fresh implies --destroy test | SPEC-TX-110-2 | 85 | D-22 mandated `--fresh` implies `--destroy`. The implementation exists per B2-8 but is untested. |
| G7 | No HOST_HOME fallback error test | SPEC-TX-111-1 | 85 | CH-TWIN-007 implementation exists (`${HOME:?}`) but the error path is untested. |

### Advisory Gaps (confidence < 80)

| # | Gap | SPEC-TX | Confidence | Rationale |
|---|-----|---------|------------|-----------|
| G8 | sigv4 security section assertion deferred | SPEC-TX-102 | 75 | Test 98 has a TODO comment. The assertion is deferred until the sigv4 security section is implemented in `_print_next_steps`. |
| G9 | No `sidecar-delta` SKIPPED + `NO_SIDECAR=true` test | SPEC-TX-106-2 | 70 | The `NO_SIDECAR=true` branch in `validate_summary` is now live code but has no test for its acceptance path. |
| G10 | SPEC-TX-113-2 (main exit on automated-gate SKIP) not implemented | SPEC-TX-113-2 | 70 | Depends on CH-LZ-004 implementation (M-9 BACKLOG). |

### Intentionally Backlogged

| # | Gap | SPEC-TX | Rationale |
|---|-----|---------|-----------|
| B1 | G1 fail-on-unestablished (CH-LZ-004) | SPEC-TX-113-1 | M-9 BACKLOG — test exists as skipped placeholder |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | yes | `make test` — 250/252 pass, 1 pre-existing failure (unrelated), 1 intentional skip. `make lint` — PASS, zero violations. |
| Typed enums / vocabulary types | N/A | Bash scripts — not applicable |
| Documentation on new public symbols | N/A | Test files — not applicable |
| Spec/datasheet fidelity | yes | All SPEC-TX cross-referenced to A1-TX requirements and psc-adv-0017 findings |
| Module boundary | yes | Test files correctly scoped: `tests/` for installer, `mock-server/tests/` for harness |
| Reserved/padding fields handled | N/A | Not applicable to bash |
| No magic numbers in doc examples | yes | All test case counts trace to specific SPEC-TX requirements |
| Buffer safety | N/A | Not applicable to test specifications |
| AGENTS.md compliance | yes | Follows `tests/AGENTS.md` and `mock-server/AGENTS.md` conventions |
| Conventional commit ready | N/A | Phase C verification — no commits at this stage |

## Review Findings

**Reviewer:** Test Engineer
**Phase:** C — Verification
**Artifact:** All test files implementing SPEC-TX-100 through SPEC-TX-114
**Date:** 2026-07-30

### Blocking Findings (confidence ≥ 80)

| ID | Confidence | Severity | Finding | Suggested Fix |
|----|-----------|----------|---------|---------------|
| F1 | 90 | Critical | SPEC-TX-105: No precondition verdict routing test in `orchestrator_args.bats` | Add 2 test cases: (1) `assert_preconditions` failure → `TWIN: FAIL:` output, (2) non-zero exit code |
| F2 | 92 | Critical | SPEC-TX-112: No G6 permissions boundary tests in `preflight.bats` | Add 3 test cases using stubbed `aws` CLI: negative test (boundary denies), positive control (no boundary allows), gate label |
| F3 | 90 | Critical | SPEC-TX-114: No G3b S3 conditional PutObject test in `preflight.bats` | Add 1 test case with counter-based `aws` stub verifying `PreconditionFailed` on second `put-object` |
| F4 | 88 | High | SPEC-TX-110-3: No `--fresh`/`--keep` mutual exclusion test | Add test passing `--fresh --keep` to `parse_args` and asserting error or last-wins behaviour |
| F5 | 85 | High | SPEC-TX-110-2: No `--fresh` implies `--destroy` test | Add test verifying `teardown` stops and deletes twin when `FRESH=true`, `DESTROY=false` |
| F6 | 85 | High | SPEC-TX-108: No stale-sentinel cleanup test | Add test verifying `$STAGING/DONE` and `$STAGING/FAILED` are removed after `ensure_twin` |
| F7 | 85 | High | SPEC-TX-111-1: No HOST_HOME fallback error test | Add test unsetting `HOME` and `HOST_HOME`, asserting clear error message |

### Advisory Findings (confidence < 80)

| ID | Confidence | Severity | Finding | Suggested Fix |
|----|-----------|----------|---------|---------------|
| F8 | 75 | Moderate | SPEC-TX-102: sigv4 security section assertion deferred (TODO in test 98) | Implement the sigv4 security section in `_print_next_steps`, then add the assertion |
| F9 | 70 | Moderate | SPEC-TX-106-2: No `sidecar-delta` SKIPPED + `NO_SIDECAR=true` test | Add test case with `sidecar-delta \| SKIPPED` and `NO_SIDECAR=true` |
| F10 | 70 | Moderate | SPEC-TX-113-2: No `main` exit-on-automated-gate-SKIP test | Depends on CH-LZ-004 implementation (M-9 BACKLOG); add when G1 fail-on-unestablished is implemented |

## Verdict

**VERDICT: CONDITIONAL PASS**

**COVERAGE: 19/33 test cases implemented and passing (58%)**

**RATIONALE:** The core auth and credential tests (SPEC-TX-100, 101, 103, 104, 107) are fully implemented and passing — these cover the highest-risk findings (CH-AUTH-002 forbidden posture, CH-AUTH-004 credential corruption, CH-AUTH-010 wait_driver hang). However, 12 test cases across 7 SPEC-TX are not implemented, and 2 are partially implemented. The gaps cluster in two areas:

1. **Harness-level tests (SPEC-TX-105, 108, 110, 111):** The implementation changes exist in `run-test.sh` per B2-8, but the tests that would verify them were not written. These are moderate-risk gaps — the code is changed but not proven correct.

2. **Landing-zone tests (SPEC-TX-112, 113, 114):** G6, G3b, and G1-fail gates have no tests. G1-fail is intentionally backlogged (M-9). G6 and G3b are accepted findings (CH-LZ-002, CH-LZ-007) with no test coverage.

**CONDITIONS for APPROVED:**
1. Implement the 7 blocking test cases (F1–F7) or explicitly backlog them with written justification
2. Resolve the 3 advisory gaps (F8–F10) — either implement or backlog
3. Re-run `make test` to confirm all new tests pass

**ROUTING:** code-architect — the missing tests correspond to implementation units that were claimed complete (Units 8, 9, 12) but lack the test coverage specified in A1-TX.

## Notes

1. **B3-VALIDATE claim discrepancy:** The B3-VALIDATE log states "TX (Test Engineer) SPEC-TX-100 through 114 — All implemented." This claim is inaccurate. Only 6 of 14 SPEC-TX are fully implemented; 4 are partial; 4 have zero test coverage. The B3-VALIDATE should be corrected.

2. **M-1 re-scoping:** Per M-1 (ACCEPTED), TX was to re-scope to all 49 findings. The A1-TX document covers 14 SPEC-TX mapped to TX-relevant findings from psc-adv-0017. The re-scoping was not reflected in an updated A1 document. The B1-PLAN distributed findings across 12 implementation units, with Unit 12 (Tests) covering the TX-specific test cases. The gaps identified here are within the TX-specific scope.

3. **Pre-existing failure:** `dev_up Absent path: disk create before limactl start` (test 77 in `mock-server/tests/dev_twin.bats`) fails independently of psc-0003. Not investigated here.

4. **Test count reconciliation:** The A1 document states "28 new + 3 modified = 29" test cases (with a note that SPEC-TX-103-4 and SPEC-TX-111-2 are the same). The B2-12 APPLY log states 22 tests were added. The difference (29 − 22 = 7) is partially explained by the 7 blocking gaps identified above, plus the 2 partially-implemented cases.

5. **`validate_summary` Bash 4 dependency:** Tests 23–27 in `completion_protocol.bats` are skipped on Bash 3.2 (`skip "validate_summary requires Bash 4 or newer"`). On macOS (default Bash 3.2), these tests do not execute. The CI environment should use Bash 4+ to exercise these tests. Per M-29 (ACCEPTED), this is a known limitation.
