# B2-4: APPLY Unit 4 — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T15:15:00Z |
| Step | B2-4 |
| Unit | 4 — §5.2, §6.1a, §6.5 rotation updates |
| Build result | PASS — bash -n on extracted _rotate_bootstrap_credentials function |

## Changes

### §6.1a — DEV_REGION constant (SPEC-SW-001)
Added `DEV_REGION` constant after `DEV_CREDENTIALS_FILE`:
```bash
readonly DEV_REGION="${DEV_REGION:-eu-west-2}"
```

### §5.2 — Rotation flow diagram (SPEC-SW-005)
Updated the rotation flow to include the `sts get-caller-identity` verification step:
- Added step 4c: VERIFY with `sts get-caller-identity` using new credentials
- Renumbered old 4c→4d (delete), 4d→4e (persist)
- Added `--region "$DEV_REGION"` to create-access-key and verification calls

### §6.5 — _rotate_bootstrap_credentials code block (SPEC-SW-001, SPEC-SW-005)
1. Replaced all `eu-west-1` literals with `$DEV_REGION` (3 occurrences: create-access-key, verification, delete-access-key)
2. Inserted `sts get-caller-identity` verification step between create and delete:
   - Probes with new credentials before deleting old key
   - On failure: emits WARNING, preserves old key, aborts rotation (return 0 with fallback)
   - On success: proceeds to delete old key
3. Updated partial-failure handling documentation to include verification-failure scenario

## Acceptance criteria

- [x] `DEV_REGION` constant declared in §6.1a with `${DEV_REGION:-eu-west-2}` default
- [x] No `eu-west-1` literals remain in §6.5
- [x] Verification step uses `sts get-caller-identity` with new credentials
- [x] Verification failure preserves old key and emits WARNING (does not delete)
- [x] Verification success proceeds to delete old key
- [x] §5.2 flow diagram shows verification step (4c)
- [x] Partial-failure handling note updated to include verification-failure scenario
