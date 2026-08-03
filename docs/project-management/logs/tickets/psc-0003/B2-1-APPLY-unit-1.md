# B2-1: APPLY Unit 1 — Auth Config Block

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T23:45:00Z |
| Step | B2-1 |
| Unit | 1 — Auth Configuration Surface |
| Ticket | psc-0003 |
| Source findings | CH-AUTH-002, CH-AUTH-003, CH-AUTH-013 |

## Files Changed

| File | Lines added | Lines removed | Net |
|------|-------------|---------------|-----|
| `setup-floci.sh` | +35 | 0 | +35 |

## Changes

### 1. Auth config block (inserted after line 73, before ports section)

**Before:** No auth config block existed. The script had no `FLOCI_AUTH_MODE`, no derived auth variables, and `print_summary` hardcoded `FLOCI_AUTH_VALIDATE_SIGNATURES=false` in its risk message.

**After:** Added a 30-line auth config block implementing the challenger's design from CH-AUTH-002:

```bash
# --- Auth posture ---
readonly FLOCI_AUTH_MODE="${FLOCI_AUTH_MODE:-sigv4}"
case "$FLOCI_AUTH_MODE" in
  off)   _auth_on="false" ;;
  sigv4) _auth_on="true"  ;;
  *) printf 'ERROR: FLOCI_AUTH_MODE must be "off" or "sigv4" (got: %s)\n' "$FLOCI_AUTH_MODE" >&2
     exit 1 ;;
esac
if [[ "${FLOCI_AUTH_UNSAFE_OVERRIDE:-0}" == "1" ]]; then
  readonly FLOCI_AUTH_VALIDATE_SIGNATURES="${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_auth_on}"
  readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED:-$_auth_on}"
else
  readonly FLOCI_AUTH_VALIDATE_SIGNATURES="$_auth_on"
  readonly FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED="$_auth_on"
fi
readonly FLOCI_SERVICES_IAM_ENABLED="${FLOCI_SERVICES_IAM_ENABLED:-true}"
if [[ "$FLOCI_AUTH_MODE" == "sigv4" ]]; then
  readonly FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL="${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL:-true}"
else
  readonly FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL="false"
fi
unset _auth_on
```

Key properties:
- Posture is derived **unconditionally** from `FLOCI_AUTH_MODE` — no individual override without the escape hatch
- `FLOCI_AUTH_UNSAFE_OVERRIDE=1` is the single named escape hatch for tests
- `_auth_on` is `unset` after use (was left set in the challenger's original design)
- `FLOCI_SERVICES_IAM_ENABLED=true` in both branches (CH-AUTH-003)
- `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=true` in sigv4, `false` in off
- Invalid `FLOCI_AUTH_MODE` exits 1 with error message

### 2. write_env_file heredoc (after line 866)

**Before:** Only `FLOCI_AUTH_PRESIGN_SECRET` was emitted.

**After:** Added 5 auth variables:

```
FLOCI_AUTH_MODE=${FLOCI_AUTH_MODE}
FLOCI_AUTH_VALIDATE_SIGNATURES=${FLOCI_AUTH_VALIDATE_SIGNATURES}
FLOCI_SERVICES_IAM_ENABLED=${FLOCI_SERVICES_IAM_ENABLED}
FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED}
FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL}
```

This satisfies CH-AUTH-013: `FLOCI_AUTH_MODE` is recorded on the host so `dev_status` and `preflight-floci.sh` can detect the current posture.

## Acceptance Criteria Coverage

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | `FLOCI_AUTH_MODE=off FLOCI_AUTH_VALIDATE_SIGNATURES=true` → `FLOCI_AUTH_VALIDATE_SIGNATURES=false` in env file | PASS | In the non-UNSAFE_OVERRIDE path, `FLOCI_AUTH_VALIDATE_SIGNATURES` is set unconditionally to `$_auth_on` (which is `"false"` for `off` mode). The env var override is ignored. |
| 2 | `FLOCI_AUTH_MODE=sigv4` → all auth vars `true` | PASS | `_auth_on="true"` → `FLOCI_AUTH_VALIDATE_SIGNATURES=true`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true`, `FLOCI_SERVICES_IAM_ENABLED=true`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=true` |
| 3 | `FLOCI_AUTH_MODE=off` → `FLOCI_SERVICES_IAM_ENABLED=true`, enforcement `false` | PASS | `FLOCI_SERVICES_IAM_ENABLED` is set to `true` unconditionally (with `${VAR:-true}` default). Enforcement is `false` via `_auth_on`. |
| 4 | `FLOCI_AUTH_MODE=invalid` → exits 1 with error message | PASS | `case` fallthrough `*)` prints error to stderr and `exit 1` |
| 5 | `FLOCI_AUTH_UNSAFE_OVERRIDE=1 FLOCI_AUTH_MODE=off FLOCI_AUTH_VALIDATE_SIGNATURES=true` → `FLOCI_AUTH_VALIDATE_SIGNATURES=true` | PASS | UNSAFE_OVERRIDE path uses `${FLOCI_AUTH_VALIDATE_SIGNATURES:-$_auth_on}` — the env var override wins |
| 6 | `FLOCI_AUTH_MODE` emitted to env file | PASS | Added to `write_env_file` heredoc |
| 7 | `make lint` passes | PASS | shellcheck + bash -n: exit 0, zero warnings |
| 8 | `make test` passes | PASS | 221/221 tests pass (116 unit + 105 mock-server) |

## Build Verification

```sh
$ make lint
shellcheck setup-floci.sh tests/stubs/_stub mock-server/run-test.sh ...
bash -n setup-floci.sh mock-server/run-test.sh ...
# exit 0, zero warnings

$ make test
bats tests/
1..116
# All 116 tests pass

bats mock-server/tests/
1..105
# All 105 tests pass (4 skipped: validate_summary requires Bash 4+)
```

## Self-Reflection

No bugs encountered during implementation. The changes were straightforward insertions following the challenger's exact design. The existing test suite passed without modification because:
1. The auth config block uses `${VAR:-default}` for all variables, so tests that don't export auth vars get the default `sigv4` posture
2. The `write_env_file` test at phase5.bats:65 (`renders all §12 keys`) uses `grep -q` for specific keys — the new auth lines are present but the test doesn't assert their absence, so it still passes
3. The `print_summary` test at phase6_7.bats:88 still matches `UNAUTHENTICATED` in the output (the risk message is unchanged)
