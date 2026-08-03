# Advisory: Auth Plan Implementation Gaps (Code Not Implemented)

| Field | Value |
|-------|-------|
| ID | psc-adv-0003-auth-implementation-gaps |
| Type | advisory |
| Status | awaiting user decision |
| Confidence | 85 |
| Priority | critical |
| Source ticket | psc-adv-0001 |
| Source agent | SX, DX |
| Source file | [A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-adv-0001/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |

## Description
The authentication plan proposes several implementation changes that have **not been implemented in code**. The auth plan reads as if implemented, but the actual codebase has not been updated.

**Consolidated findings:**

1. **F-SX-003 (conf 85) — `FLOCI_AUTH_MODE` missing from env file**: Auth plan introduces `FLOCI_AUTH_MODE` (off/sigv4) but `write_env_file` does not emit it. The installer never sets it, so Floci always runs with the default (off mode).

2. **F-SX-001 (conf 90) — `dev_env` hardcoded `test/test`**: `dev_env` function still uses hardcoded `DEV_AKID=test DEV_SECRET=test` instead of reading from `DEV_CREDENTIALS_FILE` as the auth plan specifies. This bypasses the entire rotation flow.

3. **F-SX-002 (conf 88) — `preflight-floci.sh` hardcoded secret**: `preflight-floci.sh` uses hardcoded secret `floci` instead of reading from `DEV_CREDENTIALS_FILE`. The G1 gate (IAM signature validation) cannot run in sigv4 mode with the current code.

4. **F-SX-008 (conf 80) — `print_summary` unconditional**: Auth plan §6.3 proposes `print_summary` to echo mode-specific messages, but current `print_summary` is unconditional and does not branch on auth mode.

5. **F-DX-007 (conf 85) — `write_env_file` missing auth vars**: `write_env_file` does not emit `FLOCI_AUTH_MODE`, `FLOCI_SERVICES_IAM_ENABLED`, `FLOCI_AUTH_PRESIGN_SECRET`, or rotation metadata.

6. **F-DX-008 (conf 80) — `run-test.sh` missing `--auth-mode`**: Test twin driver does not accept `--auth-mode` flag; the test harness cannot exercise sigv4 mode.

7. **F-SX-004 (conf 85→78) — `chmod 0600` missing on credentials file**: After rotation writes new credentials, the file permissions are not hardened to 0600. (Challenger retiered to LOW-MODERATE but fix still needed.)

## Recommended Action
1. Implement `FLOCI_AUTH_MODE` in `write_env_file` with `off`/`sigv4` validation.
2. Rewrite `dev_env` to source `DEV_CREDENTIALS_FILE` instead of hardcoded values.
3. Update `preflight-floci.sh` to read credentials from `DEV_CREDENTIALS_FILE`.
4. Implement `print_summary` auth-mode branching per auth plan §6.3 (but WITHOUT echoing secret to stdout — see M-DX-003).
5. Extend `write_env_file` to emit all auth-plan env vars.
6. Add `--auth-mode` flag to `run-test.sh` driver and pass through to `in-vm` driver.
7. Add `chmod 0600` after atomic write in rotation function.

## User Decision
the plan is a plan to be implemented, but the code is not yet implemented.
only resurface gaps that affect the implementation of the plan and not gaps that are proposed by the plan and not yet implemented in code.

## Decision Rationale

## Implementation Ticket