# B2-10: APPLY Unit 10 — Terraform Coherence

| Field | Value |
|-------|-------|
| Agent | code-architect |
| Timestamp | 2026-07-30T00:00:00Z |
| Step | B2-10 |
| Ticket | psc-0003 |
| Unit | 10 — Terraform Coherence |

## Files changed

| File | Lines changed | Description |
|------|--------------|-------------|
| `infra/_common/providers.tf` | +7 | CH-LZ-008 + CH-LZ-011: reversed merge order, added environment validation |
| `infra/live/10-management-iam/providers.tf` | +7 | CH-LZ-008 + CH-LZ-011: same changes propagated to stage copy |
| `infra/_common/versions.tf` | 1 | CH-LZ-009: `>= 5.56.0` → `>= 6.56.0` |
| `infra/live/10-management-iam/versions.tf` | 1 | CH-LZ-009: `>= 5.56.0` → `>= 6.56.0` |
| `infra/live/00-backend-bootstrap/main.tf` | 1 | CH-LZ-009: `>= 5.95.0, < 7.0.0` → `>= 6.56.0` |
| `infra/_common/backend.hcl copy.example` | 1 | CH-LZ-005: `us-east-1` → `eu-west-2` |
| `infra/environments/dev.tfvars` | 3 | CH-LZ-012: corrected comment mechanism |

## CH-LZ-008: Restore governance tags in _common/providers.tf

**Status:** DONE (via CH-LZ-011 merge reversal)

The governance trio (Project/Environment/ManagedBy) was already present in `_common/providers.tf`. The merge order was reversed per CH-LZ-011, which also satisfies CH-LZ-008's intent of having governance tags in the template.

## CH-LZ-011: Reverse default_tags merge order + add environment validation

**Status:** DONE

Two changes applied to both `_common/providers.tf` and `infra/live/10-management-iam/providers.tf`:

1. **Merge order reversed:** `merge(var.default_tags, {governance})` — governance keys now take precedence over tfvars. A tfvars entry like `Environment = "wrong"` is silently overridden by the providers.tf value from `var.environment`.

2. **Environment validation added:**
```hcl
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of dev, uat, prod (see landing-zone-design.md §4.1)."
  }
}
```

## CH-LZ-009: Unify provider constraints to >= 6.56.0 with NO upper bound

**Status:** DONE

Three files updated:
- `infra/_common/versions.tf`: `>= 5.56.0` → `>= 6.56.0`
- `infra/live/10-management-iam/versions.tf`: `>= 5.56.0` → `>= 6.56.0`
- `infra/live/00-backend-bootstrap/main.tf`: `>= 5.95.0, < 7.0.0` → `>= 6.56.0` (upper bound removed)

All three now use the same constraint: `>= 6.56.0` with no upper bound.

## CH-LZ-010: Omit key from providers.tf

**Status:** NO-OP (already satisfied)

`infra/live/10-management-iam/providers.tf` has no `key` field. The backend is declared in `backend.tf` as `terraform { backend "s3" {} }` — an empty partial configuration that requires `-backend-config="key=…"` at init time. A missing required value fails loudly; a wrong default fails silently.

## CH-LZ-005: Align backend region with tfvars region

**Status:** DONE

`infra/_common/backend.hcl copy.example` line 18: `region = "us-east-1"` → `region = "eu-west-2"` to match `dev.tfvars`.

## CH-LZ-006: Reduce §6.10b to modern backend config

**Status:** NO-OP (already satisfied)

`infra/_common/backend.hcl copy.example` already uses the modern form:
- `use_path_style = true` (not deprecated `force_path_style`)
- `endpoints = { s3 = …, dynamodb = … }` (not deprecated `endpoint`)

## CH-LZ-012: Correct mechanism in dev.tfvars comment

**Status:** DONE

`infra/environments/dev.tfvars` lines 26-29: replaced the incorrect "causes terraform plan warnings (duplicate key) and breaks ABAC tag-match queries" with the correct mechanism: "merge precedence means the providers.tf values silently override any duplicate keys in this map, with no diagnostic."

## Build verification

| Check | Result |
|-------|--------|
| `terraform -chdir=infra/live/10-management-iam fmt -check` | PASS (exit 0, no output) |
| `terraform -chdir=infra/live/00-backend-bootstrap fmt -check` | PASS (exit 0, no output) |

## Acceptance criteria coverage

| AC | Description | Status |
|----|-------------|--------|
| CH-LZ-008 | Governance tags in _common/providers.tf | PASS |
| CH-LZ-011 | Reverse merge order + env validation | PASS |
| CH-LZ-009 | Provider >= 6.56.0, no upper bound | PASS |
| CH-LZ-010 | Omit key from 10-management-iam/providers.tf | PASS (already satisfied) |
| CH-LZ-005 | Backend region = eu-west-2 | PASS |
| CH-LZ-006 | Modern backend config (use_path_style + endpoints) | PASS (already satisfied) |
| CH-LZ-012 | Correct mechanism in dev.tfvars comment | PASS |
| Build | terraform fmt -check | PASS |
