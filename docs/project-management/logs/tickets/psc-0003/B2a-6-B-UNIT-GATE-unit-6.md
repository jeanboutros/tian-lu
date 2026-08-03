# B2a-6: B-UNIT-GATE — psc-0003 Unit 6

## T1: Mechanical
| # | Check | Result |
|---|-------|--------|
| 1 | make lint passes (zero warnings) | PASS |
| 2 | bash -n passes on setup-floci.sh | PASS |
| 3 | bash -n passes on run-in-vm.sh | PASS |
| 4 | All 5 acceptance criteria met | PASS |

## T-ARCH: Architecture + Principles
| # | Check | Result |
|---|-------|--------|
| 1 | verify_health retries on 000 and 5xx; fails fast on 4xx; timeout message includes last code | PASS |
| 2 | Per-binary AppArmor sentinel checks each binary independently (podman-userns, podman-userns-crun, podman-userns-pasta, newuidmap-userns, newgidmap-userns) | PASS |
| 3 | Firewall ranges documented with rationale (confirmed vs INFERRED) | PASS |
| 4 | curl and openssl asserted in Phase 1 + installed in Phase 3 | PASS |
| 5 | AGENTS.md lines 60 and 67 updated (enable-linger prescription, TLS override line reference) | PASS |
| 6 | Pre-existing shellcheck suppressions added for SC2034/SC2145 (wired in follow-up units) | PASS |
| 7 | No regression in existing installer functions | PASS |

## Verdict
PASS
