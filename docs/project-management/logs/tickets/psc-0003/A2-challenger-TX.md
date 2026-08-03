# A2 Challenger: Test Engineer — psc-0003

| Field | Value |
|-------|-------|
| Model | glm-5.2 |
| Phase | A2 — Dual-Model Challenge |
| Primary Output | A1-TX-test-engineer.md — 26 new + 3 modified test cases across 7 files, covering 16 of 49 accepted findings from psc-adv-0017 |
| Challenger | test-engineer-challenger (independent model) |
| Timestamp | 2026-07-30T23:30:00Z |

## Self-Audit Checklist (per self-audit-checklist skill)

| Category | Result |
|----------|--------|
| Read primary output fully | yes (477 lines) |
| Read source advisory fully | yes (1,471 lines + 50 findings) |
| Verified claims against repo artifacts | yes — stubs, run-test.sh, dev-twin.sh, run-in-vm.sh, preflight-floci.sh, auth plan, existing bats files |
| Every finding scored with confidence | yes |
| Critical gaps flagged | yes (FLAG-1 scope omission) |

## Agreements

The primary is correct on the findings it *did* cover. I verified the following against the
repo:

1. **SPEC-TX-100 (CH-AUTH-002)** — the forbidden posture is reachable. Verified: auth plan §4.2
   uses the `${VAR:-default}` form that lets `FLOCI_AUTH_VALIDATE_SIGNATURES=true` override the
   `off`-mode derivation. The single bats case proving the override is ignored post-rewrite is the
   right shape. Confidence 95.

2. **SPEC-TX-101 (CH-AUTH-004)** — the `sed` range delete destroys the following profile header.
   Verified the advisory's evidence and the seven bats cases are exactly the cases the user
   decision required ("bats coverage required to prove the replacement works"). The neighbour-
   survival, idempotency, and mode-0600 cases are the correct invariants. Confidence 98.

3. **SPEC-TX-106 (CH-TWIN-002)** — `sidecar-delta` is NOT in the `mandatory` array at
   `run-test.sh:451-452`, making the special case at `:475-477` unreachable. Verified. The two
   bats cases (PASS when `NO_SIDECAR=false`, SKIPPED when `NO_SIDECAR=true`) correctly cover both
   branches. Confidence 92.

4. **SPEC-TX-108 (CH-TWIN-004)** — sentinel cleanup at `run-test.sh:181` targets
   `$HOST_EVIDENCE_MOUNT` while sentinels live in `$STAGING`. Verified: `poll_sentinel` reads
   `$STAGING/DONE`, and `rm -rf "$STAGING"` at `:180` does the real work. The single test is
   appropriate. Confidence 100.

5. **SPEC-TX-113 (CH-LZ-004)** — G1 calls `skip` (which does not set `FAILED`) when
   `create-access-key` fails, so `main` reports "automated gates passed" and exits 0. Verified at
   `scripts/preflight-floci.sh:46-48` and `:127`. The two bats cases (fail-not-skip, main exits
   non-zero on SKIP) are correct. Confidence 95.

6. **SPEC-TX-103 (CH-AUTH-010)** — `wait_driver` treats any non-zero status as fatal
   (`run-test.sh:232`), so a killed transport (exit 143) would report `TWIN: FAIL` every run. The
   distinction of success / driver-failed / killed-after-timeout is the right remediation shape.
   Confidence 85.

7. **SPEC-TX-112 / SPEC-TX-114 (CH-LZ-001/002, CH-LZ-007)** — the G6 negative test and G3b S3
   conditional PutObject gate are correctly scoped as stubbed unit tests of new gate functions.
   Confidence 92 / 90.

## Disagreements

### D-1 — Self-Audit Checklist is partially evasive (confidence 90)

The primary's self-audit marks 7 of 11 rows "N/A — Phase A" and several "yes" without evidence.
The `compliance-gate` and `self-audit-checklist` skills require that reviewing agents complete
the checklist *explicitly*. Rows like "Spec/datasheet fidelity: yes — All findings cross-
referenced to psc-adv-0017 sections" are asserted but, as D-2 below shows, the cross-referencing
is *selective* — the primary references the AUTH/TWIN/LZ subsets it chose and silently omits the
rest. A self-audit that certifies fidelity while dropping 33 of 49 findings is not a passing
self-audit.

### D-2 — Test-count arithmetic is internally inconsistent (confidence 100)

The overview (line 33) states **"28 new + 3 modified across 7 test files"** but the Test File
Summary table (line 409) totals **"26 new + 3 modified"**, and the note at line 411 explains one
overlap (SPEC-TX-103-4 == SPEC-TX-111-2). 26 is the reconciled number; the "28" in the overview
is wrong and never corrected. A requirements doc whose headline count does not match its own table
will mislead the Phase B implementers who consume it.

### D-3 — SPEC-TX-103-3 claims "uses real `sleep` and `kill` commands" — `kill` is a bash builtin (confidence 95)

The implementation detail (line 131) says the test "uses real `sleep` and `kill` commands". On
the target test host (macOS), `kill` is a **bash shell builtin**, not `/bin/kill` (verified:
`type kill` → `shell built-in command`). This is harmless *for the test as written* (the builtin
works), but it directly contradicts auth plan §6.11 (line 857-859) which mandates a **`kill`
symlink to `_stub`** with `STUB_RC_KILL` for SPEC-TX-013 tests. The primary and the auth plan
disagree on whether `kill` is stubbed, and the primary does not flag the conflict. If the
implementation later routes the kill through a stubbed path (per the auth plan), the primary's
test as specified would silently bypass the stub and exercise the builtin — a false-confidence
path.

### D-4 — SPEC-TX-105 stub claim is wrong (confidence 95)

The primary states (line 182) that a `uname` stub is needed and is a "new symlink to `_stub` in
`mock-server/tests/stubs/bin/`". I verified: there is **no `uname` stub** in
`mock-server/tests/stubs/bin/` today (18 entries, none named `uname`). The primary lists it under
"New stubs needed" so the *need* is correctly identified, but the Stub Requirements Summary table
(line 427) does not state that `_stub` lives at `mock-server/tests/stubs/_stub` and that the
symlink target is `../_stub` — an implementer following the table literally would create a
dangling symlink. Minor, but it is an incomplete stub requirement.

### D-5 — SPEC-TX-112 stub claim "aws stub (existing)" is false (confidence 98)

The primary repeatedly asserts (lines 347, 371, 419, 421) that an `aws` stub already exists in
`tests/stubs/bin/` as "a symlink to `_stub`". I verified the directory listing:
`tests/stubs/bin/` has 19 entries — **there is no `aws` symlink**. The primary's note 4 (line 475)
acknowledges the existing `aws` "may need enhancement," but the test-file summary and dependency
table treat it as pre-existing infrastructure. **There is no `aws` stub at all.** This is a
blocking stub-requirement error: SPEC-TX-112, SPEC-TX-113, and SPEC-TX-114 all depend on an `aws`
stub that does not exist and must be created from scratch (with per-subcommand control for the
multi-step IAM workflow — non-trivial, not a one-line symlink). The primary under-scopes this
work.

## One-Sided Findings

### FLAG-1 — CRITICAL: The primary dropped 33 of 49 accepted findings (confidence 100)

This is the dominant finding. The task definition (A0) lists **50 findings, 49 accepted**
across six categories: CH-AUTH (16), CH-INST (5), CH-DEV (6), CH-TWIN (7), CH-LZ (13), CH-META
(3). The TX role scope (A0 line 20) is "bats tests (phase5, dev_twin, preflight), SPEC-TX
updates, twin validation" — i.e. *all testable* findings, not a hand-picked subset.

The primary covered **16 findings** and explicitly declared "16/16 TX-relevant findings" and
"GAPS: None" (lines 461-463). That claim is false. The primary silently redefined "TX-relevant"
to mean only the AUTH/TWIN/LZ-gate findings it chose to analyse, and omitted entire categories
that are unambiguously testable:

| Omitted finding | Why it needs a test spec | Severity |
|---|---|---|
| **CH-AUTH-003** | `FLOCI_SERVICES_IAM_ENABLED=false` in `off` mode disables IAM. Auth plan §6.2 note + SPEC-TX-006 case-3 direction must be reversed. This is a **direct test-spec modification** (SPEC-TX-006 case 3 currently asserts the wrong value). The primary lists SPEC-TX-006 nowhere. | high |
| **CH-AUTH-005** | `delete_rc=$?` is unreachable under `set -e`. Needs a bats case proving the `|| delete_rc=$?` pattern is used and the WARNING prints on delete failure. | high |
| **CH-AUTH-007** | Non-atomic credential file write. Needs a bats case proving the `.tmp`+`chmod`+`mv` pattern and the parse-not-source change. | medium |
| **CH-AUTH-008** | `$AWS_CREDS_ENV` collapses to one argument under `IFS=$'\n\t'`. Needs a bats case proving the array-based `-e` override splits correctly. The s3-smoke step is affected. | medium |
| **CH-AUTH-009** | `${arr[@]+...}` guard removed prematurely; fails on bash 3.2. Needs a bats case on `/bin/bash` (3.2) proving the guard is retained. Verified: `run-test.sh:194` still uses the old `${driver_args[*]+...}` form, so the guard IS present — but auth plan §6.10 prescribes removing it. | medium |
| **CH-AUTH-013** | `FLOCI_AUTH_MODE` never recorded in env file. Needs a bats case asserting it is emitted. | low |
| **CH-AUTH-014** | `FLOCI_AUTH_PRESIGN_SECRET` threat model / rotation. Needs a gate or test for rotation. | low-medium |
| **CH-INST-001** | `verify_health` aborts on any non-200. Needs bats cases for 5xx retry + 4xx fail-fast + last-code reporting. Phase 6 tests exist (`phase6_7.bats`) — this is a modification, not new infra. | medium-high |
| **CH-INST-002** | `assert_userns_allowed` rewrites profile every run on 26.04. Needs the twin's hash set extended to include the AppArmor profile (a test-spec change to `run-in-vm.sh` idempotency-hashes). | medium |
| **CH-INST-004** | No preflight for `curl`/`openssl`. Needs bats cases asserting Phase 1 fails when absent. | low |
| **CH-DEV-001** | `dev_recreate` prints no next steps. Overlaps CH-AUTH-006 but is a standalone defect — needs its own bats case independent of the auth-mode gate. | medium |
| **CH-DEV-002** | Resume paths never refresh the AWS profile. Needs bats cases proving `dev_env` runs on Running/Stopped branches. | medium |
| **CH-DEV-003** | `dev_disk_exists` conflates absent with query-failed. Needs bats cases for the distinct return codes (0/1/2). Existing `dev_twin.bats:94-110` tests only 0 and 1. | medium |
| **CH-DEV-004** | `DEV_DISK_NAME` configurable but mount path hardcoded. Needs a bats case proving `DEV_DISK_MOUNT` derives from `DEV_DISK_NAME`. | medium |
| **CH-DEV-005** | Fresh install health budget shorter than resume. Needs a bats case asserting the fresh path uses the same budget + `_reset_floci_service` fallback. | medium |
| **CH-DEV-006** | Redundant inner guard makes `main` untestable. Needs proof `main` is callable from bats after the inner guard is dropped. | trivial |
| **CH-LZ-003** | G1 mislabelled. Needs a bats case asserting the G1 label references both enforcement variables. | medium |
| **CH-LZ-005** | Five region literals diverge. Needs a consistency test (lint-level) across the five sites. | medium |
| **CH-LZ-006** | §6.10b regresses to deprecated backend args. Needs a test that the prescribed form matches `backend.hcl.example`. | medium |
| **CH-LZ-008/009/010/011/012** | Governance tags, provider constraints, backend key, merge order, comment mechanism. Need a lint check that every `infra/live/*/providers.tf` matches `_common/providers.tf` (the advisory's own fix recommends this). | high/medium |
| **CH-META-001/002/003** | Lessons-learned; not directly testable but the *candidate standing rules* (negative test before a Deny counts as landed; quote the source line for any new env var) are test-process requirements that should be reflected in the test plan. | process |

**Impact:** The primary's "VERDICT: APPROVED, GAPS: None" is unsafe. A Phase B implementer
following A1-TX would build 26 tests and believe the test surface is complete, while 33 findings
— including high-severity items (CH-AUTH-003, CH-AUTH-005, CH-INST-001, CH-DEV-002/003/004/005,
CH-LZ-008) — have no test specification. The most damaging omission is **CH-AUTH-003**: it
requires *modifying an existing test spec* (SPEC-TX-006 case 3), and the primary does not even
mention SPEC-TX-006, so the existing (wrong) assertion would ship unchanged.

### OS-1 — No test for the CH-AUTH-001 probe outcome (confidence 90)

CH-AUTH-001 is the highest-priority finding (user decision: option 1). The advisory specifies a
three-outcome probe (rejected / accepted-namespaced / accepted-default-account) that *must* be
run regardless of the chosen option, because outcome (b) would invalidate auth plan §8 and
landing-zone §1.1. The primary's dependency table (line 442) lists CH-AUTH-002 as priority 1 and
CH-AUTH-001 is absent entirely. There is no test spec for recording the probe outcome as a gap-
register entry. Even if the probe is a manual/runtime step, the test plan should specify *that
the gap-register entry exists and references the probe result* — a documentation-assertion test
in the DX domain, but the TX plan should call it out as a dependency.

### OS-2 — SPEC-TX-106-1 has a false-positive risk (confidence 85)

SPEC-TX-106-1 asserts `validate_summary` passes when `sidecar-delta` status is `PASS` and
`NO_SIDECAR=false`. But the *current* code path: with `sidecar-delta` added to `mandatory`, the
loop checks `if [[ "$c" == "sidecar-delta" && "$NO_SIDECAR" == true ]]` — when `NO_SIDECAR=false`
this branch is skipped and the generic `if [[ "$val" != "PASS" ]]` applies. So PASS → continue
(correct). However the test does not verify the **negative**: that `sidecar-delta=FAIL` is
rejected even when `NO_SIDECAR=false`. The implementation detail (line 204) says "Both tests also
verify that `sidecar-delta` with `FAIL` is rejected" — but the test-case table rows 106-1 and
106-2 do not state this. The rejection case is the *load-bearing* assertion (it is what makes
adding `sidecar-delta` to `mandatory` meaningful), and it is described in prose but not as a
discrete test case. This risks a false positive: an implementation that adds `sidecar-delta` to
`mandatory` but breaks the FAIL-rejection path could pass 106-1/106-2.

### OS-3 — SPEC-TX-107 marks the test "MODIFY" but describes a no-op (confidence 88)

SPEC-TX-107-1 is labelled MODIFY, but the implementation detail (line 228) says "The existing
test … continues to work unchanged" and "no new test is needed for the removed code." This is a
*non-modification* presented as a modification. Either the test genuinely changes (and the
primary should state what assertion changes) or it is a no-op and the row should be "0 modified"
not "1 modified". This inflates the modified-test count and will confuse Phase B.

### OS-4 — No test for CH-TWIN-006 order-dependence direction (confidence 85)

SPEC-TX-110-3 tests `--fresh --keep` but states (line 293) "The user decision on semantics
determines which assertion." The advisory CH-TWIN-006 documents that `--keep` after `--fresh` is
silently ignored but `--fresh` after `--keep` wins (order-dependent). The primary defers the
semantic decision but does not specify a test for the **current broken order-dependence** —
i.e. a RED test proving the *present* behaviour is order-dependent (so the fix is regression-
guarded). Without a RED test capturing the current asymmetry, a fix that makes `--fresh` imply
teardown could accidentally preserve the order-dependence in the opposite direction.

### OS-5 — SPEC-TX-101-7 is weak as a "structural integrity" guard (confidence 80)

SPEC-TX-101-7 asserts "the first non-blank line is a section header." This guards against the
orphaned-keys failure mode, but only for the *first* line. The `sed` bug can orphan keys at *any*
boundary, and the `awk` replacement could theoretically produce a blank line between sections
that masks a missing header mid-file. A stronger invariant: "every key line (`aws_access_key_id`
/ `aws_secret_access_key`) is immediately preceded by a section header or another key line of the
*same* section" — or simpler, "the file parses cleanly under `aws configure list-profiles`" (but
that needs the aws CLI). At minimum, assert no key line appears before the first section header
*anywhere* in the file, not just line 1.

### OS-6 — No coverage for the CH-AUTH-008/009 bash-3.2 guard on the actual test host (confidence 88)

CH-AUTH-009 is specifically about `/bin/bash` 3.2 on macOS. The primary omits it entirely. Even
if covered, the test must run under `/bin/bash` (3.2), not the Homebrew bash 5 that bats typically
uses. The `tests/AGENTS.md` notes `_run_fn` uses `bash -c` — the interpreter is PATH-dependent.
A test for CH-AUTH-009 that runs under Homebrew bash 5 would pass trivially and prove nothing
(the bug is 3.2-specific). The test plan must specify `/bin/bash -c` explicitly for this case.

### OS-7 — Implementation-order dependency cycle is under-analysed (confidence 82)

The dependency table (lines 440-455) lists CH-AUTH-006 "Blocks CH-AUTH-011" and CH-AUTH-011
"Depends on CH-AUTH-006" — a **mutual dependency** presented as a linear order. The primary
places CH-AUTH-006 at priority 3 and CH-AUTH-011 at priority 4, but if 006 blocks 011 and 011
blocks 006, neither can go first. In reality 011 (introduce `DEV_AUTH_MODE`) must precede 006
(`_print_next_steps` uses `DEV_AUTH_MODE`), so the "Blocks" column for 006 is wrong — 006 does
not block 011; 011 blocks 006. The table has the direction inverted for row 3. Phase B following
this table would deadlock its own scheduling.

## Recommendations

| # | Recommendation | Confidence |
|---|----------------|------------|
| R1 | **Re-scope to all 49 accepted findings.** Produce test specs (or explicit "documentation-only / not testable" dispositions with reasoning) for every omitted finding in FLAG-1. At minimum: CH-AUTH-003 (modify SPEC-TX-006 case 3), CH-AUTH-005, CH-AUTH-007, CH-AUTH-008, CH-AUTH-009, CH-INST-001, CH-DEV-002/003/004/005, CH-LZ-008 lint check. | 100 |
| R2 | **Create the `aws` stub before any preflight test is written.** It does not exist. Specify it as a dedicated subcommand-aware stub (like `tests/stubs/bin/podman`), not a one-line symlink — the G6/G3b workflows need per-subcommand rc + stdout control across a 5-call IAM sequence. | 98 |
| R3 | **Fix the test-count arithmetic.** Overview says 28, table says 26. Use 26 (reconciled) or re-count after R1 expands scope. | 100 |
| R4 | **Add a discrete FAIL-rejection test case for `sidecar-delta`** (OS-2) — separate from 106-1/106-2. | 85 |
| R5 | **Resolve the `kill` stub contradiction** between A1-TX ("real kill") and auth plan §6.11 (`kill` symlink with `STUB_RC_KILL`). Pick one and document it. | 90 |
| R6 | **Correct the CH-AUTH-006 ↔ CH-AUTH-011 dependency direction** (OS-7). 011 introduces `DEV_AUTH_MODE`; 006 consumes it. 011 blocks 006, not vice versa. | 82 |
| R7 | **Specify `/bin/bash` (3.2) as the interpreter for the CH-AUTH-009 test** when it is added (OS-6). | 88 |
| R8 | **Add a RED test for the current `--fresh`/`--keep` order-dependence** before the semantic decision (OS-4). | 85 |
| R9 | **Strengthen SPEC-TX-101-7** to check no key line precedes the first section header *at any position*, not just line 1 (OS-5). | 80 |
| R10 | **Record the CH-AUTH-001 probe outcome as a test-plan dependency** — at minimum a gap-register-assertion (OS-1). | 90 |
| R11 | **Re-run the self-audit honestly** (D-1) — mark fidelity "partial" until R1 is done; do not certify "GAPS: None" while 33 findings are unscoped. | 90 |

## Verdict

**CONDITIONAL PASS**

**Rationale:** The 16 findings the primary *did* cover are correctly analysed, well-mapped to
test files, and the test-case shapes are sound. However, the primary cannot be approved as-is
because:

1. **FLAG-1 (confidence 100)** — 33 of 49 accepted findings have no test specification, including
   high-severity items (CH-AUTH-003, CH-AUTH-005, CH-INST-001, CH-DEV-002/003/004/005, CH-LZ-008)
   and one that requires *modifying an existing test spec* (SPEC-TX-006 case 3 for CH-AUTH-003).
   The primary's "16/16 TX-relevant" and "GAPS: None" claims are false.

2. **D-5 (confidence 98)** — the `aws` stub that three test specs depend on does not exist and is
   treated as pre-existing infrastructure. This blocks SPEC-TX-112/113/114.

3. **OS-7 (confidence 82)** — a dependency-cycle error in the implementation-order table would
   deadlock Phase B scheduling.

**Conditions for APPROVED:**
- Complete R1 (re-scope to all 49 findings with explicit dispositions).
- Complete R2 (create the `aws` stub, re-scope its effort).
- Complete R3 (fix the count), R6 (fix the dependency direction), R11 (honest self-audit).

The covered-16 may proceed to Phase B; the omitted-33 must be specified before they can.
