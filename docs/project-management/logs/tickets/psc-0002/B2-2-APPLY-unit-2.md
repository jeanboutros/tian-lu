# B2-2: APPLY Unit 2 — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T15:05:00Z |
| Step | B2-2 |
| Unit | 2 — §4.2 case statement restructuring |
| Build result | PASS — bash -n on extracted case statement block |

## Changes

### §4.2 `FLOCI_AUTH_MODE` case statement (SPEC-SW-003, SPEC-SW-004)

Replaced the `readonly`-inside-`case` pattern with non-readonly `_auth_*` locals computed inside the `case`, then `readonly` declarations with `${VAR:-default}` at the top level after the `case` block.

**Before:** `readonly` declarations inside `case` branches — breaks test-injection convention.

**After:**
1. Four `_auth_*` locals declared before the `case` (non-readonly, `_` prefix convention)
2. `case` branches assign to the locals (not `readonly`)
3. After `esac`, four `readonly` declarations with `${VAR:-default}` form
4. Added `_auth_iam_enabled` / `FLOCI_SERVICES_IAM_ENABLED` to both branches (SPEC-SW-004)
5. Added explanatory comment about test-injection convention

**Test-injection semantics:**
- A test that sets `FLOCI_AUTH_MODE=off` before sourcing gets `_auth_validate_signatures="false"` from the case, then `readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-false}"` picks up the case-computed value.
- A test that sets `FLOCI_AUTH_VALIDATE_SIGNATURES=true` before sourcing (regardless of `FLOCI_AUTH_MODE`) gets the env var value, bypassing the case-computed default.

## Acceptance criteria

- [x] No `readonly` declarations inside `case` branches
- [x] All four auth vars (`FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`, `FLOCI_SERVICES_IAM_ENABLED`) declared `readonly` with `${VAR:-default}` at top level
- [x] `off` branch sets all four to `false`
- [x] `sigv4` branch sets all four to `true`
- [x] Comment explains the `${VAR:-default}` test-injection convention
- [x] `_` prefix on internal locals (convention: not part of public API)
