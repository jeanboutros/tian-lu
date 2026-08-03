# ADR psc-adr-0005: Governance tag template with merge-order protection

## Status
Accepted

## Context

CH-LZ-008 identified that the governance tag trio (`Project`, `Environment`, `ManagedBy`) was deleted from `infra/live/10-management-iam/providers.tf` (the stage provider), not just from `dev.tfvars`. The stage's `default_tags` block reads `merge({}, var.default_tags)` — an empty governance map. The comment above it still says "Mandatory governance tags on every taggable resource."

This creates a **silent broken access control** vulnerability: the landing-zone §5.3 ABAC model uses `Environment` tag matching for cross-account role assumptions and resource policies. With no `Environment` tag present, the ABAC model has nothing to match on, silently breaking all tag-based access controls.

Additionally, CH-LZ-011 identified that the `default_tags` merge order in `_common/providers.tf:46-50` lets `var.default_tags` (from tfvars) override the governance tags — a silent ABAC bypass. The merge order was:
```hcl
default_tags = merge(
  var.default_tags,           # tfvars — can override!
  { Project = "...", Environment = "...", ManagedBy = "..." }  # governance
)
```

The challenge advisory (A2-challenger-SX) and DO primary both identified this. The fix requires:
1. Restore governance tags in stage 10 provider (not just tfvars)
2. Reverse merge order so governance tags win
3. Add `environment` validation restricting to `dev`/`uat`/`prod`
4. Add lint check that every `infra/live/*/providers.tf` matches `_common/providers.tf`

The user ruled (A2c, A-40, A-43) to accept the challenger position on merge order and environment validation.

## Decision

1. **Governance tags restored in `_common/providers.tf` template** (not in stage tfvars):
   - `Project` = project identifier (e.g., `tianlu`)
   - `Environment` = restricted to `dev` | `uat` | `prod` (validated)
   - `ManagedBy` = `terraform`
   - These are mandatory on every taggable resource

2. **Stage tfvars carries only `Owner`** (general tag, not governance):
   - `dev.tfvars` provides `Owner` = team/individual
   - Stage-specific overrides allowed for `Owner` only

3. **Merge order reversed in `_common/providers.tf`** (governance tags win):
   ```hcl
   default_tags = merge(
     { Project = var.project_name, Environment = var.environment, ManagedBy = "terraform" },
     { Owner = var.owner },              # general tag from tfvars
     var.default_tags                    # any additional tags (cannot override governance)
   )
   ```
   This ensures governance tags (`Project`, `Environment`, `ManagedBy`) always win over any tfvars or additional tags.

4. **Environment validation** restricting to `dev`/`uat`/`prod`:
   ```hcl
   variable "environment" {
     type        = string
     validation {
       condition     = contains(["dev", "uat", "prod"], var.environment)
       error_message = "Environment must be one of: dev, uat, prod."
     }
   }
   ```

5. **Lint check (SPEC-DO-014 / CH-LZ-008)**: A CI job that verifies every `infra/live/*/providers.tf` matches the `_common/providers.tf` template in structural elements (governance tag block, merge order, validation). This closes the open/closed principle violation where the template was open for extension but not closed for modification.

## Consequences

**Enables:**
- Governance tags are mandatory and immutable — cannot be overridden by tfvars
- ABAC model in landing-zone §5.3 has reliable `Environment` tag to match on
- Silent ABAC bypass eliminated — tfvars can add tags but not override governance
- Lint check catches template divergence early
- Clear separation: governance (template-enforced) vs. general tags (tfvars-controlled)

**Trade-offs:**
- Stage tfvars lose ability to override governance tags (intentional)
- New stages must follow the template exactly — lint check enforces this
- Environment value is constrained to three values — adding a new environment requires template change
- `Owner` tag is the only stage-specific general tag; other custom tags go through `default_tags` but cannot override governance

## References

- **Challenge finding**: CH-LZ-008 (A2-challenger-SX), CH-LZ-011 (A2-challenger-DX, A2-challenger-DO)
- **Advisory**: M-4 (SX missed CH-LZ-008), M-17 (SX missed CH-LZ-009/010), M-32 (SX missed CH-INST-004)
- **Disagreement**: D-12 (DX presents inferred firewall ranges as fact — related doc correction)
- **A2 synthesis**: A2-dual-model-challenge.md §4 Agreements A-40, A-43, §6.2 M-4, M-17, M-32
- **A2c decision register**: A2c-decision-register.md §4 Implementation Impact (M-4, R-37)
- **User decision**: 2026-07-30, Supreme Leader ruling — "Accepted" for M-4, A-40, A-43