# B2-8: APPLY Unit 8 — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T15:35:00Z |
| Step | B2-8 |
| Unit | 8 — infra/ code changes |
| Build result | PASS — terraform fmt -check passes on all three files |

## Changes

### 1. `infra/live/10-management-iam/main.tf` — DenyAllExceptBoundary (SPEC-SW-002)
- Changed `resources = [aws_iam_policy.general_app_boundary.arn]` to `resources = ["*"]`
- Added `condition` block with `StringNotEquals` on `iam:PermissionsBoundary` matching `general_app_boundary.arn`
- Removed trailing blank line inside the statement block

### 2. `infra/live/10-management-iam/providers.tf` — backend config (SPEC-SW-006)
- Removed hardcoded `bucket = "tf-state-dev"` from the `backend "s3"` block
- Added comment: `# bucket and region are passed via -backend-config at init time.`
- Added cross-reference: `# See docs/design/authentication-plan.md §6.10b for the full init command.`

### 3. `infra/environments/dev.tfvars` — default_tags (SPEC-SW-007)
- Removed `Project`, `Environment`, `ManagedBy` from the `default_tags` map (kept only `Owner`)
- Added comment explaining these are injected by `providers.tf`'s `default_tags` merge from `var.environment`
- Applied `terraform fmt` to all three files

## Acceptance criteria

- [x] `main.tf` `DenyAllExceptBoundary` uses `resources = ["*"]` with `StringNotEquals` condition
- [x] `providers.tf` backend block has no hardcoded `bucket` value
- [x] `dev.tfvars` `default_tags` contains only `Owner` (not `Project`, `Environment`, `ManagedBy`)
- [x] `dev.tfvars` has comment explaining the `providers.tf` merge injection
