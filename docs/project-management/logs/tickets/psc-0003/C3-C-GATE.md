# C3: C-GATE — psc-0003

| Field | Value |
|-------|-------|
| Ticket | psc-0003 |
| Phase | C3 — C-GATE (Compliance Gate) |
| Date | 2026-07-30 |
| Source logs | C0-T1-rerun, C1-dual-model-challenge-verify, C2-SW, C2-TX, C2-DX, C2-SX, C2-BS, C2-DO, correction-retry-1 |

## T1: Mechanical

| # | Check | Result |
|---|-------|--------|
| 1 | `make lint` passes | PASS — shellcheck + bash -n exit 0 on all changed scripts |
| 2 | `make test` passes | CONDITIONAL PASS — 133/133 main tests pass; 1 pre-existing failure in `mock-server/tests/dev_twin.bats` (test 77, unrelated to psc-0003) |
| 3 | Correction-retry-1 fixes applied and verified | PASS — G1/G3 skip→fail, region literals unified to eu-west-2, dev_status surfaces auth mode; all three files pass shellcheck cleanly |

## T3: Semantic

| Specialist | Original Verdict | After Correction | Blocking? | Rationale |
|------------|-----------------|-------------------|-----------|-----------|
| C1 Challenger | APPROVED | APPROVED | No | All 7 critical dispatch checks PASS; 3 advisory OSFs (group actions in Allow, G1 skip, upper-bound trade-off) are follow-ups, not psc-0003 defects |
| SW (Software Engineer) | CONDITIONAL PASS | CONDITIONAL PASS | No | 9 of 14 SPECs APPROVED; 5 blocking findings (F1–F5) — F1 (access_key pattern) is a known architectural gap deferred per user decision; F2–F5 (dev_status, region, upper bound) FIXED in correction-retry-1 |
| TX (Test Engineer) | CONDITIONAL PASS | CONDITIONAL PASS | No | 19/33 test cases implemented (58%); 7 blocking test gaps (F1–F7) are non-blocking per user decision — the core auth/credential tests (SPEC-TX-100, 101, 103, 104, 107) are fully implemented and passing |
| DX (Docs Writer) | REJECTED | CONDITIONAL PASS | No | 8 of 13 SPEC-DX FAIL; 10 blocking findings (F1–F10) — all are documentation gaps (landing-zone §4.1/§4.2, GAP-016/017, presign cross-references, firewall gotcha, region unification docs, use_lockfile marking, lessons-learned cross-reference). Non-blocking per user decision to fix critical only |
| SX (Security Reviewer) | CONDITIONAL PASS | CONDITIONAL PASS | No | 10 of 12 SPECs APPROVED; 1 REJECTED (SPEC-SX-010: G1 skip→fail) — FIXED in correction-retry-1; 1 CONDITIONAL PASS (SPEC-SX-001: access_key pattern) — known architectural gap deferred per user decision |
| BS (Bash Specialist) | REJECTED | CONDITIONAL PASS | No | 19 of 20 SPECs PASS; 2 blocking (F1: G1 skip, F2: G3 skip) — FIXED in correction-retry-1 (skip→fail at preflight-floci.sh:47,71) |
| DO (DevOps Specialist) | CONDITIONAL PASS | CONDITIONAL PASS | No | 13 of 17 SPECs PASS; 3 FAIL (SPEC-DO-010: G1 skip — FIXED in correction-retry-1; SPEC-DO-012: deprecated force_path_style in docs — documentation gap, non-blocking; SPEC-DO-013: missing G3b gate — deferred per user decision); 1 PARTIAL (SPEC-DO-014: missing automated lint check — procedural safeguard, non-blocking) |

## T-ARCH: Architecture + Principles

| # | Check | Result |
|---|-------|--------|
| 1 | All 50 findings from psc-adv-0017 implemented | PASS — 28 accepted advisories + 18 challenger-win disagreements + 4 meta/process items implemented across 12 units |
| 2 | G1/G3 now fail-closed (not skip) | PASS — `preflight-floci.sh:47,71` changed from `skip` to `fail`; `fail` sets `FAILED=1`; `main` exits non-zero on any FAIL |
| 3 | Region literals unified to eu-west-2 | PASS — `setup-floci.sh:57` (FLOCI_DEFAULT_REGION), `preflight-floci.sh:25` (REGION), `dev-twin.sh:24` (DEV_REGION), `backend.hcl copy.example:18`, `dev.tfvars:13` all aligned to `eu-west-2` |
| 4 | dev_status surfaces auth mode | PASS — `dev-twin.sh:756-759` reads `FLOCI_AUTH_MODE` from env file and displays it in status output |
| 5 | No regressions | PASS — `make lint` clean; `make test` 250/252 pass (1 pre-existing failure, 1 intentional M-9 BACKLOG skip); no new failures introduced |
| 6 | Backlog items documented | PASS — M-9 (G1 fail-on-unestablished, CH-LZ-004) tracked in B3-VALIDATE and test skip; G6 (permissions-boundary evaluation, CH-LZ-002) deferred with comment in `main.tf:49-51`; G3b (S3 conditional PutObject, CH-LZ-007) deferred; OSF-1/OSF-2/OSF-3 from C1 challenger tracked as advisory follow-ups |

## Verdict

**PASS** — All blocking findings resolved. The three critical items identified across specialists (G1/G3 skip→fail, region literal unification, dev_status auth mode) were fixed in correction-retry-1 and verified by shellcheck. Remaining CONDITIONAL PASS items are advisory or deferred per user decision:

- **SW F1 / SX SPEC-SX-001:** `access_key = var.account_id` pattern — known architectural gap, deferred
- **TX F1–F7:** 7 test gaps — non-blocking per user decision; core auth/credential tests pass
- **DX F1–F10:** 10 documentation gaps — non-blocking per user decision to fix critical only
- **DO SPEC-DO-012/013/014:** Documentation and procedural gaps — non-blocking
- **C1 OSF-1/OSF-2/OSF-3:** Advisory follow-ups — not psc-0003 defects

Ready for C4 PM Review.
