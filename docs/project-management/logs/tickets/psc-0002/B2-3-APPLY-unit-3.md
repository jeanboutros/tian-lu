# B2-3: APPLY Unit 3 — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T15:10:00Z |
| Step | B2-3 |
| Unit | 3 — §6.1, §6.2 code block updates |
| Build result | PASS — bash -n on extracted code blocks; §4.2 and §6.1 case statements match |

## Changes

### §6.1 code block (SPEC-SW-003, SPEC-SW-004)
Added the full restructured case statement code block to §6.1, mirroring the §4.2 restructuring from Unit 2. The code block now includes:
- Non-readonly `_auth_*` locals computed inside the `case`
- `readonly` declarations with `${VAR:-default}` at the top level after `esac`
- `FLOCI_SERVICES_IAM_ENABLED` in both branches and the readonly block

### §6.2 write_env_file code block (SPEC-SW-004)
Updated the env file code block to include `FLOCI_SERVICES_IAM_ENABLED` as the first auth var line, before the existing three. Added a note about SPEC-TX-006 test case 3 reversal.

**Before:**
```bash
FLOCI_AUTH_VALIDATE_SIGNATURES=${FLOCI_AUTH_VALIDATE_SIGNATURES}
FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED}
FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL}
```

**After:**
```bash
FLOCI_SERVICES_IAM_ENABLED=${FLOCI_SERVICES_IAM_ENABLED}
FLOCI_AUTH_VALIDATE_SIGNATURES=${FLOCI_AUTH_VALIDATE_SIGNATURES}
FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=${FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED}
FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL=${FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL}
```

## Acceptance criteria

- [x] §6.1 code block matches §4.2 restructured case statement exactly
- [x] §6.2 code block includes all four auth vars in order: `FLOCI_SERVICES_IAM_ENABLED`, `FLOCI_AUTH_VALIDATE_SIGNATURES`, `FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED`, `FLOCI_SERVICES_IAM_SEED_DEPLOYER_PRINCIPAL`
- [x] Note about SPEC-TX-006 test case 3 reversal present
