# ADR psc-adr-0008: Governance tag merge order with environment validation

## Status
Accepted

## Context

CH-LZ-011 identified that `_common/providers.tf:46-50` has a `default_tags` merge order that allows `var.default_tags` (from `dev.tfvars` / environment tfvars) to silently override the governance tags (`Project`, `Environment`, `ManagedBy`):

```hcl
default_tags = {
  tags = merge(
    {
      Project     = "tianlu"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.default_tags  # GOVERNANCE TAGS OVERWRITTEN HERE
  )
}
```

Since `merge(map1, map2)` lets `map2` keys override `map1`, any `dev.tfvars` setting `default_tags = { Environment = "prod" }` would silently change the environment tag — a silent ABAC bypass (OWASP A01:2021 + A05:2021). The comment above the block says "Mandatory governance tags on every taggable resource" but the code does the opposite.

Additionally, there was no validation on `var.environment` — it could be set to any string, breaking the `dev`/`uat`/`prod` isolation model.

The challenger (SX, DO) and user decision (A-43) specify:
1. Reverse merge order so governance tags win
2. Add `environment` validation restricting to `dev`/`uat`/`prod`
3. Add lint check that every `infra/live/*/providers.tf` matches `_common/providers.tf` (CH-LZ-008, A-40)

## Decision

1. **Reverse `merge` order in `_common/providers.tf`** — governance tags applied last, so they win:
   ```hcl
   default_tags = {
     tags = merge(
       var.default_tags,  # general tags (Owner, CostCenter, etc.)
       {
         Project     = "tianlu"
         Environment = var.environment
         ManagedBy   = "terraform"
       }  # GOVERNANCE TAGS APPLIED LAST — WIN
     )
   }
   ```

2. **Add `environment` validation** in `_common/variables.tf`:
   ```hcl
   variable "environment" {
     type        = string
     description = "Deployment environment — must be dev, uat, or prod"
     validation {
       condition     = contains(["dev", "uat", "prod"], var.environment)
       error_message = "environment must be one of: dev, uat, prod."
     }
   }
   ```

3. **`dev.tfvars` carries only `Owner`** (general tag) — governance tags come from the template:
   ```hcl
   default_tags = {
     Owner = "platform-team"
   }
   environment = "dev"
   ```

4. **Lint check (SPEC-DO-014, CH-LZ-008)**: Every `infra/live/*/providers.tf` must match `_common/providers.tf` in:
   - `default_tags` block structure (merge order, governance tag keys)
   - `environment` variable validation
   - No stage-specific divergence without explicit ADR
   - Implemented as `terraform fmt -check` + `terraform validate` + custom check in CI (M-23, M-7)

5. **Documentation**: Landing-zone §5.3 ABAC model updated to reference the enforced governance tags; authentication-plan §12 cross-linked.

## Consequences

**Enables:**
- Governance tags (`Project`, `Environment`, `ManagedBy`) are immutable — cannot be overridden by tfvars
- `Environment` tag is validated to only `dev`/`uat`/`prod` — prevents typos and injection
- `Owner` (and other general tags) still configurable per environment via `default_tags`
- Lint check prevents silent divergence of stage providers from template
- ABAC policies in landing-zone §5.3 can reliably match on `Environment` tag

**Trade-offs:**
- Stage providers cannot customize governance tags (intentional — they are governance)
- `environment` variable validation adds a hard constraint — invalid values fail at plan time
- Lint check requires CI capability for Terraform (M-23, M-7 — addressed in SPEC-DO-017)
- Existing stage providers (10-management-iam) must be updated to match template

**Migration:**
- `infra/live/10-management-iam/providers.tf` updated to match `_common/providers.tf` structure
- Any existing `dev.tfvars` with `Environment` or `Project` in `default_tags` — those values are now ignored (governance wins)
- State is unaffected (tags are metadata, not resource identity)

## References

- **Challenge finding**: CH-LZ-011 (A2-challenger-SX, A2-challenger-DO), CH-LZ-008 (stage 10 governance tags deleted)
- **Advisory**: M-4 (SX missed CH-LZ-008), M-17 (SX missed CH-LZ-009/010), M-32 (SX missed CH-INST-004)
- **Recommendation**: R-37 (include CH-LZ-005/008/009/010 in SX), R-15 (lint check for providers.tf match)
- **A2 synthesis**: A2-dual-model-challenge.md §4 Agreements A-40, A-43, §6.2 M-4, M-17
- **A2c decision register**: A2c-decision-register.md §4 Implementation Impact (A-40, A-43)
- **User decision**: 2026-07-30, Supreme Leader ruling — "Accepted" for A-40, A-43