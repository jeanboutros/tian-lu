# B2-6: APPLY Unit 6 — psc-0002

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T15:25:00Z |
| Step | B2-6 |
| Unit | 6 — Cross-reference additions |
| Build result | PASS — markdown link check; all referenced file paths resolve |

## Changes

### §6.10a — IAM permissions boundary enforcement (SPEC-SW-002)
Added new subsection cross-referencing `infra/live/10-management-iam/main.tf` `DenyAllExceptBoundary` statement. Includes:
- Explanation of the `StringNotEquals` on `iam:PermissionsBoundary` condition
- The corrected HCL code block with `resources = ["*"]` and condition block
- Rationale: the original scoped `resources` to the boundary policy ARN, but denied actions act on IAM principal ARNs
- Link to `landing-zone-design.md` §5.1

### §6.10b — Terraform backend configuration (SPEC-SW-006)
Added new subsection with:
- Full `terraform init -backend-config` command for stage `10-management-iam` (11 flags)
- Pre-rotation and post-rotation variants
- Note that `bucket` is NOT hardcoded in `providers.tf`
- Cross-reference to §5.2 for rotation flow

### §6.10c — Environment tag consistency (SPEC-SW-007)
Added new subsection with:
- Cross-reference to `infra/environments/dev.tfvars`
- Explanation that `Project`, `Environment`, `ManagedBy` are injected by `providers.tf` merge
- `Environment` tag value is `"dev"` (from `var.environment`), not `"development"`
- The `providers.tf` `default_tags` merge code block

### §6.10d — IRSA stand-in session duration (SPEC-SW-008)
Added new subsection with:
- Cross-reference to `landing-zone-design.md` §5.4
- `DurationSeconds` bound of 3600s, re-assumption cadence of 30 minutes
- Table with parameter, value, and rationale
- Expiry behavior: pod restarts if credentials expire
- Note that this is a Floci accommodation (real EKS uses IRSA/EKS Pod Identity)

## Acceptance criteria

- [x] Four new subsections present with correct cross-references
- [x] All referenced file paths resolve to existing files
- [x] Backend config subsection includes full `terraform init` command with all 11 `-backend-config` flags
- [x] Each subsection has a clear rationale explaining why the cross-reference exists
