# C2-TX: Test Engineer Verification — psc-0002

| Field | Value |
|-------|-------|
| Agent | test-engineer |
| Timestamp | 2026-07-30T12:00:00Z |
| Step | C2-TX |
| Verdict | CONDITIONAL PASS |
| Coverage | 13/13 SPEC-TX items have test specifications in §6.11 |

## Self-Audit Checklist

| Category | Checked? | Finding or PASS |
|----------|----------|-----------------|
| Build passes (exit 0, no warnings) | N/A | No code written — verification of design document only |
| Typed enums / vocabulary types | N/A | Bash project — not applicable |
| Documentation on new public symbols | N/A | Design document review — not applicable |
| Spec/datasheet fidelity | PASS | All 13 SPEC-TX items cross-referenced against A1-TX-test-engineer.md (authoritative source) and §6.11 |
| Module boundary | PASS | Test files are correctly placed: installer tests in `tests/`, dev-twin tests in `mock-server/tests/` |
| Reserved/padding fields handled | N/A | Not applicable |
| No magic numbers in doc examples | PASS | All values are named (e.g., `DEV_CREDENTIALS_FILE`, `FLOCI_AUTH_MODE`, `STUB_OUT_JQ`) |
| Buffer safety | N/A | Not applicable |
| AGENTS.md compliance | PASS | Follows log format from pipeline skill; references authoritative sources |
| Conventional commit ready | N/A | No code to commit |

## Verification Results

### 1. SPEC-TX Coverage in §6.11

| SPEC | Status | Detail |
|------|--------|--------|
| SPEC-TX-001 | PASS | All 5 test cases covered: fresh install, dev-recreate, fallback, partial failure, file permissions (§6.11 lines 821-825) |
| SPEC-TX-002 | PASS | Rotation gated off in auth_mode=off covered (§6.11 line 826) |
| SPEC-TX-003 | PASS | Stale DEV_CREDENTIALS_FILE not consumed in off mode covered (§6.11 line 827) |
| SPEC-TX-004 | PASS | All 9 test cases covered: 5 orchestrator flag parsing (§6.11 lines 833-837) + 4 guest driver behavior (§6.11 lines 840-843) |
| SPEC-TX-005 | PASS | FLOCI_AUTH_MODE invalid value exits 1 covered (§6.11 line 809) |
| SPEC-TX-006 | PASS | All 4 test cases covered: sigv4 emits true, off emits false, FLOCI_SERVICES_IAM_ENABLED=true (updated per SPEC-SW-004), backward compat (§6.11 lines 810-813) |
| SPEC-TX-007 | PASS | All 3 test cases covered: sigv4 ON message, off UNAUTHENTICATED warning, bootstrap admin note (§6.11 lines 816-818) |
| SPEC-TX-008 | PASS | dev_env sed-replace and credential-rotation tests covered (§6.11 line 828). 5 individual test cases enumerated in A1-TX doc (authoritative source) |
| SPEC-TX-009 | PASS | All 4 test cases covered: DEV_AKID+test default, FLOCI_BOOTSTRAP_AKID override, FLOCI_BOOTSTRAP_SECRET override, pass-through args (§6.11 lines 846-849) |
| SPEC-TX-010 | PASS | Cross-cutting podman exec -e overrides covered (§6.11 lines 842-843). 5 individual test cases enumerated in A1-TX doc (authoritative source) |
| SPEC-TX-011 | PASS | chmod failure detection covered (§6.11 line 829) |
| SPEC-TX-012 | PASS | Replace grep/sed with jq covered (§6.11 line 830). 3 test updates enumerated in A1-TX doc (authoritative source) |
| SPEC-TX-013 | PASS | wait_driver kill-before-wait covered (§6.11 line 852). 2 test cases enumerated in A1-TX doc (authoritative source) |

### 2. Test File Identification

| Test File | Exists? | §6.11 Status | Correct? |
|-----------|---------|-------------|----------|
| `tests/phase5.bats` | Yes (366 lines) | Existing, 5 new tests | ✓ |
| `tests/phase6_7.bats` | Yes (251 lines) | Existing, 3 new tests | ✓ |
| `tests/preflight.bats` | No | Marked NEW | ✓ |
| `mock-server/tests/dev_twin.bats` | Yes (510 lines) | Existing, 12 new tests | ✓ |
| `mock-server/tests/orchestrator_args.bats` | Yes (77 lines) | Existing, 5 new tests | ✓ |
| `mock-server/tests/run_in_vm.bats` | No | Marked NEW | ✓ |
| `mock-server/tests/completion_protocol.bats` | Yes (231 lines) | Existing, 1 new + 1 modified | ✓ |

All 7 test files are correctly identified. The 2 NEW files (`tests/preflight.bats`, `mock-server/tests/run_in_vm.bats`) do not yet exist, which is correct — they are to be created during Phase B implementation.

### 3. Test Case Detail Sufficiency

The §6.11 "Key test patterns" section (lines 806-852) provides a structured summary organized by test file, with each test case mapped to its SPEC-TX identifier. The section explicitly references the A1-TX doc as the authoritative source for full specifications (line 778):

> The full test specifications are in `docs/project-management/logs/tickets/psc-0002/A1-TX-test-engineer.md`.

This is appropriate for a design document — the summary provides enough detail to understand the test structure and coverage, while the A1-TX doc contains the precise assertions, preconditions, stub patterns, and assertion logic needed for implementation.

### 4. Implementation Order

§6.11 lines 794-804 specify a clear 7-step implementation order:

1. Phase 5 tests (SPEC-TX-005, SPEC-TX-006) — foundation
2. Phase 6/7 tests (SPEC-TX-007) — depends on config block
3. Preflight tests (SPEC-TX-009)
4. Dev-twin rotation tests (SPEC-TX-001, 002, 003, 008, 011, 012)
5. Orchestrator args tests (SPEC-TX-004:1-5)
6. Run-in-vm tests (SPEC-TX-004:6-9, SPEC-TX-010)
7. Completion protocol fix (SPEC-TX-013)

This order correctly follows dependency chains (config block → summary output) and groups related tests together. ✓

### 5. Stub Requirements

§6.11 lines 854-863 document the new stubs needed:

| Stub | Location | Purpose | Documented? |
|------|----------|---------|-------------|
| `jq` | `mock-server/tests/stubs/bin/` | SPEC-TX-012 JSON parsing tests; supports `STUB_OUT_JQ` | ✓ |
| `kill` | `mock-server/tests/stubs/bin/` | SPEC-TX-013 transport kill tests; supports `STUB_RC_KILL` | ✓ |
| `jq` | `tests/stubs/bin/` | Conditional (if preflight tests need it) | ✓ |

All stub requirements are documented with their purpose and required environment variable support. ✓

## Findings

### Finding 1: Test count discrepancy in dev_twin.bats row (Confidence: 60 — Low)

| ID | Confidence | Severity | Location | Description |
|----|-----------|----------|----------|-------------|
| F1 | 60 | Low | §6.11 line 788 | Table says 12 new tests for `mock-server/tests/dev_twin.bats` covering SPEC-TX-001, 002, 003, 008, 011. Summing the A1-TX test counts: 5+1+1+5+1 = 13. Additionally, SPEC-TX-012 (2 new tests) is not listed in the dev_twin.bats row but is included in the implementation order (line 800). The total (39 new + 1 modified = 40) is correct. |

**Suggested fix:** Either correct the dev_twin.bats count to 13 (or 15 if SPEC-TX-012 is included) and add SPEC-TX-012 to the SPEC column, or add a footnote explaining the counting methodology. This is a documentation polish issue — the A1-TX doc is the authoritative source for exact counts.

### Finding 2: SPEC-TX-006 test case 3 reversal not reflected in A1-TX doc (Confidence: 75 — Moderate)

| ID | Confidence | Severity | Location | Description |
|----|-----------|----------|----------|-------------|
| F2 | 75 | Moderate | Cross-document | §6.2 (line 339-342) and §6.11 (line 812) correctly state that SPEC-TX-006 test case 3 must be reversed: `FLOCI_SERVICES_IAM_ENABLED=true` IS present in sigv4 mode (per SPEC-SW-004). However, the A1-TX doc (line 175-177) still asserts the old behavior: "does NOT emit FLOCI_SERVICES_IAM_ENABLED". The §6.11 summary is correct; the A1-TX doc is stale. |

**Suggested fix:** Update A1-TX-test-engineer.md SPEC-TX-006 test case 3 to match the reversed assertion documented in §6.2 and §6.11. This is a cross-document consistency issue — the A1-TX doc is the implementation specification and should reflect the current requirements.

### Finding 3: SPEC-TX-008 and SPEC-TX-010 individual test cases not enumerated in §6.11 (Confidence: 40 — Low)

| ID | Confidence | Severity | Location | Description |
|----|-----------|----------|----------|-------------|
| F3 | 40 | Low | §6.11 lines 828, 842-843 | SPEC-TX-008 (5 test cases) and SPEC-TX-010 (5 test cases) are summarized as single lines in §6.11, while other SPEC items (TX-001, TX-004, TX-006, TX-007, TX-009) have their individual test cases enumerated. The A1-TX doc is referenced as the authoritative source, so this is not a gap — just an inconsistency in summary detail level. |

**Suggested fix:** Optionally expand the SPEC-TX-008 and SPEC-TX-010 summaries to list individual test cases, matching the detail level of other SPEC items. Not required — the A1-TX doc reference is sufficient.

## Verdict

**VERDICT: CONDITIONAL PASS**

**Rationale:** All 13 SPEC-TX items are covered in §6.11. Test files are correctly identified, implementation order is specified, and stub requirements are documented. The three findings are documentation polish issues (F1: minor count discrepancy, F3: summary detail inconsistency) and a cross-document staleness issue (F2: A1-TX doc not updated for SPEC-SW-004 reversal). None of these block Phase C completion — the §6.11 section correctly captures the current requirements and references the A1-TX doc as the authoritative source for implementation details.

**COVERAGE: 13/13 acceptance criteria have test evidence**

**GAPS:**
- F1: Minor test count discrepancy in dev_twin.bats table row (documentation polish)
- F2: A1-TX doc SPEC-TX-006 test case 3 is stale — should be updated to match §6.2/§6.11 reversal
- F3: SPEC-TX-008 and SPEC-TX-010 individual test cases not enumerated in §6.11 (non-blocking; A1-TX doc is authoritative)

**ROUTING:** Output to supreme-leader. If CONDITIONAL PASS is accepted, proceed to Phase CR. If findings must be addressed, route F2 to docs-writer (update A1-TX doc), F1 and F3 to code-architect (minor table corrections in §6.11).
