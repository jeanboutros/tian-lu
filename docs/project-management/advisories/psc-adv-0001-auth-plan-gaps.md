# Advisory: Auth Plan Design Defects

| Field | Value |
|-------|-------|
| ID | psc-adv-0001-auth-plan-gaps |
| Type | advisory |
| Status | awaiting user decision |
| Confidence | 90 |
| Priority | critical |
| Source ticket | psc-adv-0001 |
| Source agent | SW, SX, DX |
| Source file | [A2-dual-model-challenge.md](docs/project-management/logs/tickets/psc-adv-0001/A2-dual-model-challenge.md) |
| Created | 2026-07-30 |

## Description
The authentication plan (`authentication-plan.md`) contains multiple design defects that would break the rotation flow and IAM guardrails if implemented as written. These are design-time findings that must be resolved before Phase B implementation.

**Consolidated findings:**

1. **M-SW-001 (conf 90) — Region mismatch breaks SigV4 rotation**: Auth plan hardcodes `eu-west-1` but Terraform/dev.tfvars uses `eu-west-2`. AWS SigV4 signs the region into the signature — this mismatch breaks the entire rotation flow in sigv4 mode. **Runtime-correctness blocker for the auth plan's central feature.**

2. **M-SW-002 (conf 82) — Deny statement is a no-op**: `platform_admin` Deny statement (`main.tf:49-63`) scopes `resources` to only the boundary policy ARN, but the denied actions (`DeleteRolePermissionsBoundary`, `DeleteUserPermissionsBoundary`, `DeletePolicy`) act on role/user/policy ARNs — the Deny never matches. The delegated-administration guardrail is **non-functional**.

3. **D-SW-001 (conf 88) — `readonly` inside `case` breaks test injection**: The auth plan §4.2 code block declares `readonly` vars inside `case` branches. This breaks the project's `${VAR:-default}` bats-injection convention because `readonly` is hit on the first `source`. The auth plan's own §6.11 test requirements (two modes in one bats file) cannot both run under the proposed pattern. **Severity raised to HIGH.**

4. **M-SX-003 (conf 72) — Rotation non-atomic write**: Auth plan rotation writes credentials with `printf >` (non-atomic). A crash mid-write leaves a truncated/empty credentials file, and the next `dev_env` silently falls back to `test/test` — defeating the rotation. The installer's own `write_env_file` uses atomic `.tmp` + `mv`, but the rotation design does not.

5. **M-SW-005 (conf 72) — Missing verification step in rotation**: Auth plan §6.5 rotation deletes the old key with **zero verification** that the new key works. If `create-access-key` returns a malformed response, the script deletes the only working credential and persists a broken one — total lockout.

6. **F-SW-001 (conf 85) — `FLOCI_SERVICES_IAM_ENABLED` missing from sigv4 branch**: The auth plan's `FLOCI_AUTH_MODE` case statement for `sigv4` mode does not set `FLOCI_SERVICES_IAM_ENABLED=true`, which is required for Floci to enforce IAM signatures.

7. **M-SX-006 (conf 70) — Presign secret scope gap**: `FLOCI_AUTH_PRESIGN_SECRET` has no documented threat model and no rotation path. It is an independent authentication secret that bypasses the IAM layer the entire auth plan is about. The auth plan covers `floci-deployer` rotation extensively but never mentions this secret.

8. **M-DX-003 (conf 75) — Secret in stdout**: Auth plan §6.3 proposed `print_summary` echoes `secret=floci` to stdout. Echoing a live secret to stdout (captured in logs, terminal scrollback, CI output) is a credential-exposure vector the auth plan neither acknowledges in §2.2 nor mitigates.

9. **M-DX-004 (conf 70) — Resume-path gap**: Auth plan §4.3 states dev twin default is `sigv4`, but `make dev-up` on an existing VM does NOT re-invoke the installer (per AGENTS.md gotcha). The resume path (`_resume_health_check`) is not addressed — `FLOCI_AUTH_MODE` cannot be changed without `dev-recreate`.

## Recommended Action
1. Fix region inconsistency: replace all `eu-west-1` literals in auth plan with `DEV_REGION` constant (default `eu-west-2`).
2. Rewrite `DenyAllExceptBoundary` statement resources to `["*"]` or use `StringNotEquals` condition on `iam:PermissionsBoundary`.
3. Rewrite auth plan §4.2 code block: move `readonly` out of `case` to preserve `${VAR:-default}` test-injection convention.
4. Make credential-file write atomic in rotation: write to `.tmp`, `chmod 0600`, `mv -f` — mirroring `write_env_file` pattern.
5. Add verification step (`sts get-caller-identity`) between create and delete in rotation flow.
6. Add `FLOCI_SERVICES_IAM_ENABLED=true` to `sigv4` branch of `FLOCI_AUTH_MODE` case statement.
7. Add `FLOCI_AUTH_PRESIGN_SECRET` section to auth plan: threat model, rotation procedure, cross-link from F-SX-001.
8. Remove `secret=floci` from `print_summary` stdout output; use masked display or omit entirely.
9. Document auth plan resume-path behavior: `make dev-up` on existing VM does not re-invoke installer; `FLOCI_AUTH_MODE` changes require `dev-recreate`.

## User Decision
1. corre t region is eu-west-2 others should be fixed
2. fix it
3. fix it
4. fix it
5. fix it
6. fix it
7. fix it
8. fix it. use masked output and show the file where it is stored
9. document it as expected behavior

## Decision Rationale

## Implementation Ticket