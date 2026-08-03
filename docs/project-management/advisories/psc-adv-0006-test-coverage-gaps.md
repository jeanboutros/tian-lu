# Advisory: Test Coverage Gaps

| Field | Value |
|-------|-------|
| ID | psc-adv-0006-test-coverage-gaps |
| Type | advisory |
| Status | awaiting user decision |
| Confidence | 82 |
| Priority | high |
| Source ticket | psc-adv-0001 |
| Source agent | TX |
| Source file | [A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-adv-0001/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |

## Description
Systematic test coverage gaps across auth rotation, auth mode, dev_env, and cross-cutting concerns. Many tests specified in auth plan §6.11 and §7.3 are not implemented.

**Consolidated findings:**

1. **F-TX-001 (conf 90) — Rotation unit tests missing**: Auth plan §6.11 specifies rotation tests; none implemented.

2. **M-TX-001 (conf 82) — No test for rotation gating in `auth_mode=off`**: If `_rotate_bootstrap_credentials` runs unconditionally in off mode, it could delete the working `floci`/`floci` bootstrap. The auth plan §6.5 needs an explicit `DEV_AUTH_MODE` guard.

3. **M-TX-002 (conf 80) — No test that `DEV_CREDENTIALS_FILE` is NOT consumed in `auth_mode=off`**: A stale creds file from a prior sigv4 run would be sourced and used in off mode, where the rotated creds fail auth.

4. **F-TX-002 (conf 90) / M-TX-001/M-TX-002 — Auth-mode tests missing**: No tests for `FLOCI_AUTH_MODE` behavior switching.

5. **F-TX-011, F-TX-012, F-TX-013 (conf 85) — `FLOCI_AUTH_MODE` tests missing**: Three specific test cases for auth mode switching not implemented.

6. **F-TX-014 (conf 80) — `dev_env` tests missing**: No tests for the dev env profile management.

7. **F-TX-015 (conf 75) — `preflight-floci.sh` untested**: The G1/G2/G3 preflight gates have no test coverage.

8. **M-TX-006 (conf 70) — Cross-cutting `podman exec -e` override tests missing**: §7.3 test-matrix cross-cutting concern: `podman exec -e ...` overrides must appear consistently across s3-smoke, Lambda sidecar, and G1 preflight steps. A single test per step misses the cross-step consistency requirement.

9. **M-TX-004 (conf 62) — No test for `chmod 0600` failure on `DEV_CREDENTIALS_FILE`**: Under `set -e`, a `chmod` failure after key rotation (new key created, old key deleted) aborts without persisting — permanent lockout.

10. **F-TX-004 (conf 70) — Rotation JSON parsing fragile**: The rotation code parses AWS CLI JSON output with fragile string manipulation; no tests for malformed responses.

11. **M-TX-003 (conf 72) — `wait_driver` success path un-killed wait defect**: Same un-killed-wait defect as failure path (F-TX-003). If driver hangs after publishing DONE, `wait_driver` blocks indefinitely on success path too.

12. **F-TX-009 (reframed per D-TX-002) — Journal check downgrades systemctl PASS to FAIL when lines unparseable**: The real bug is subtler than "unconditional" — when a journal line is empty (parse failure), the test sets FAIL and discards the systemctl PASS.

## Recommended Action
1. Implement rotation unit tests (5 cases: fresh install, dev-recreate, fallback, partial failure, file permissions) per F-TX-001.
2. Add mode-gating tests: rotation is no-op in `auth_mode=off`; stale `DEV_CREDENTIALS_FILE` is not consumed in off mode.
3. Implement `FLOCI_AUTH_MODE` test matrix (3+ cases).
4. Implement `dev_env` tests.
5. Add `preflight-floci.sh` test coverage for G1/G2/G3 gates.
6. Add cross-cutting test for `podman exec -e` override consistency across s3-smoke, Lambda sidecar, G1 preflight.
7. Add `chmod 0600` failure test for credentials file.
8. Harden rotation JSON parsing with jq and test malformed responses.
9. Fix `wait_driver` success path: add kill-before-wait on both success and failure paths.
10. Fix journal check logic: preserve systemctl-based result when lines missing; only set FAIL when both lines present AND misordered.

## User Decision
all ok

## Decision Rationale

## Implementation Ticket