# ADR psc-adr-0003: IAM service always enabled regardless of auth mode

## Status
Accepted

## Context

CH-AUTH-003 identified a critical defect: in `FLOCI_AUTH_MODE=off`, the authentication plan set `FLOCI_SERVICES_IAM_ENABLED=false`, which disables the IAM API surface entirely. This is a security misconfiguration (OWASP A05:2021) because:

1. The IAM service surface and IAM enforcement are two independent dimensions. Disabling the service surface removes the ability to create/manage IAM resources, which breaks functionality that should be available even in `off` mode (e.g., role assumption, policy evaluation for testing).

2. Combined with CH-AUTH-001 (the three-outcome probe), this creates a false-negative security gate: under `sigv4` with default credentials (`$DEV_AKID` + `test`), the `create-access-key` call always fails, so the gate the design calls a "hard stop" reports success on precisely the configuration it exists to police. With `IAM_ENABLED=false` in `off` mode, it also always skips.

The challenge advisory (A2-challenger-SX, A2-challenger-SW) identified this as a distinct finding requiring `FLOCI_SERVICES_IAM_ENABLED=true` in both branches (or omitted, defaulting to `true`). Only `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` should track the mode.

The user ruled (A2c, A-3) to accept the challenger position.

## Decision

1. **`FLOCI_SERVICES_IAM_ENABLED=true` in both branches** (or omit entirely, relying on Floci default of `true`): The IAM service surface is always available regardless of `FLOCI_AUTH_MODE`.

2. **Only `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED` tracks the mode**:
   - `sigv4` → `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`
   - `off` → `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=false`

3. **Documentation corrections**:
   - `authentication-plan.md` §6.2 note corrected to reflect IAM service always enabled
   - SPEC-TX-006 case-3 updated to test enforcement toggle, not service availability
   - Landing-zone §1.1 "Enforced" rows updated to reference enforcement variable, not service variable

4. **Test specification**: SPEC-TX-006 case-3 modified to verify that IAM API calls succeed in both modes, but enforcement behavior differs (allowed vs denied based on signatures).

## Consequences

**Enables:**
- IAM service surface always available for testing, development, and operational tasks
- Enforcement is the only toggle controlled by `FLOCI_AUTH_MODE`
- The three-outcome probe (CH-AUTH-001) can meaningfully test enforcement in `sigv4` mode because the service is available
- Security posture is clearer: mode controls enforcement, not service availability

**Trade-offs:**
- `off` mode now exposes IAM API surface (but without enforcement, which is the intended semantics)
- Documentation and test specs must be updated to reflect the corrected model
- Any existing tests or scripts assuming IAM service is unavailable in `off` mode must be updated

## References

- **Challenge finding**: CH-AUTH-003 (A2-challenger-SX, A2-challenger-SW)
- **Advisory**: M-1 (TX dropped 33 of 49 findings — includes CH-AUTH-003), M-19 (SX missed CH-AUTH-006 + CH-AUTH-013 security-gate variables never assigned)
- **A2 synthesis**: A2-dual-model-challenge.md §4 Agreements A-3, §6.2 M-1/M-19
- **A2c decision register**: A2c-decision-register.md §4 Implementation Impact
- **User decision**: 2026-07-30, Supreme Leader ruling — "Accepted" for A-3