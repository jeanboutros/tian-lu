# ADR psc-adr-0002: Auth posture derivation with single escape hatch

## Status
Accepted

## Context

CH-AUTH-002 identified that the `${VAR:-default}` pattern on individual authentication sub-variables (e.g., `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-true}`) reopens the forbidden `(signatures=on, enforcement=off)` posture. An operator could set `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=false` while `FLOCI_AUTH_MODE=sigv4`, creating the exact security hole the `FLOCI_AUTH_MODE` enum was designed to collapse.

The authentication plan §4.2 design uses a single `FLOCI_AUTH_MODE` enum (`sigv4` | `off`) that collapses the dangerous 2×2 matrix (signatures on/off × enforcement on/off) into two coherent states. The defect is that individual sub-variables still have `${VAR:-default}` defaults, allowing piecemeal override.

The challenge advisory (A2-challenger-BS, A2-challenger-SX, A2-challenger-TX) and BS primary (SPEC-BS-001) identified the fix:
1. Derive posture unconditionally from `FLOCI_AUTH_MODE` — no `${VAR:-default}` on sub-variables
2. Add a single, explicit, named escape hatch: `FLOCI_AUTH_UNSAFE_OVERRIDE=1`
3. `unset _auth_on` after use to prevent leakage
4. Add bats test case proving the forbidden posture is unreachable without the escape hatch

The user ruled (A2c, A-2) to accept this approach.

## Decision

1. **Posture derived unconditionally from `FLOCI_AUTH_MODE`**:
   ```bash
   readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-sigv4}"
   
   if [[ "$FLOCI_AUTH_MODE" == "sigv4" ]]; then
     readonly _auth_on=1
   else
     readonly _auth_on=0
   fi
   
   # No ${VAR:-default} on sub-variables — they are derived, not configured
   readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="$_auth_on"
   readonly FLOCI_SERVICES_IAM_VALIDATE_SIGNATURES="$_auth_on"
   readonly FLOCI_SERVICES_IAM_ENABLED="true"  # always true (see CH-AUTH-003)
   ```

2. **Single escape hatch: `FLOCI_AUTH_UNSAFE_OVERRIDE=1`**:
   ```bash
   if [[ "${FLOCI_AUTH_UNSAFE_OVERRIDE:-0}" == "1" && "$FLOCI_AUTH_MODE" == "sigv4" ]]; then
     # Allow selective override ONLY for testing
     readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-1}"
     readonly FLOCI_SERVICES_IAM_VALIDATE_SIGNATURES="${FLOCI_SERVICES_IAM_VALIDATE_SIGNATURES:-1}"
   fi
   ```
   - Explicit, named, documented
   - Only works when `FLOCI_AUTH_MODE=sigv4` (cannot enable enforcement in `off` mode)
   - Test-gated: bats case proves hole is closed without it

3. **Cleanup**: `unset _auth_on` after derivation to prevent accidental leakage into child processes.

4. **Bats test case**: A discrete test proving that setting `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=false` with `FLOCI_AUTH_MODE=sigv4` does NOT produce the forbidden posture — the derived value remains `true`. Only `FLOCI_AUTH_UNSAFE_OVERRIDE=1` allows the override.

5. **Documentation**: Authentication plan §4.2 rewritten with the new derivation logic. The old `${VAR:-default}` section removed.

## Consequences

**Enables:**
- The forbidden `(signatures=on, enforcement=off)` posture is architecturally impossible without the explicit escape hatch
- Single source of truth: `FLOCI_AUTH_MODE` is the only configuration knob
- Escape hatch is explicit, named, documented, and test-gated
- `FLOCI_AUTH_UNSAFE_OVERRIDE` name signals danger — operators won't set it accidentally
- Bats test proves the hole is closed

**Trade-offs:**
- Testing requires `FLOCI_AUTH_UNSAFE_OVERRIDE=1` — intentional friction
- Sub-variables can no longer be individually configured in `sigv4` mode (intentional — they're derived)
- `off` mode still has no enforcement (by design)
- Existing configurations using sub-variable overrides will break — migration required

## References

- **Challenge finding**: CH-AUTH-002 (A2-challenger-BS, A2-challenger-SX, A2-challenger-TX)
- **Disagreement**: D-17 (BS `printf '%q'` version claim — related but separate)
- **Advisory**: M-19 (SX missed CH-AUTH-006 + CH-AUTH-013), M-11 (SW under-weighted CH-AUTH-014)
- **Recommendation**: R-3 (create SPEC-SW-015 for CH-LZ-002)
- **A2 synthesis**: A2-dual-model-challenge.md §4 Agreements A-2, §6.1 D-2, D-17, D-18, D-19
- **A2c decision register**: A2c-decision-register.md §4 Implementation Impact (D-2, D-17, D-18, D-19)
- **User decision**: 2026-07-30, Supreme Leader ruling — "Resolved: Challenger" for D-2, D-17, D-18, D-19; "Accepted" for A-2