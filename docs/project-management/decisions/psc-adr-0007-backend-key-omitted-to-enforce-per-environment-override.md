# ADR psc-adr-0007: Backend key omitted to enforce per-environment override

## Status
Accepted

## Context

CH-LZ-010 identified that `infra/live/10-management-iam/providers.tf:14` has a hardcoded backend key:
```hcl
backend "s3" {
  key = "10-management-iam/terraform.tfstate"
}
```

This violates the landing-zone §9 isolation scheme which requires an `<env>/` prefix (e.g., `dev/10-management-iam/terraform.tfstate`). Without the prefix, promotion to uat/prod collides on the same S3 object — one environment's `terraform apply` reads another's state and operates on the wrong infrastructure.

The cross-environment state collision (CH-LZ-010) has infrastructure-destruction blast radius: `terraform apply` in uat could destroy dev resources because Terraform thinks the resources already exist and plans a no-op, or thinks they don't exist and recreates them.

The user decision (A0:45) and challenger (A-42) both specify: omit the `key` from `providers.tf` backend block entirely, forcing a `-backend-config="key=..."` override at init time. This makes the key mandatory — fail-loud on missing override.

## Decision

1. **Omit `key` from `providers.tf` backend block** in all stage providers:
   ```hcl
   backend "s3" {
     # key is OMITTED — must be provided via -backend-config
     bucket         = "tianlu-terraform-state"
     region         = "eu-west-1"
     dynamodb_table = "tianlu-terraform-locks"
     encrypt        = true
   }
   ```

2. **Require `-backend-config="key=<env>/<stage>/terraform.tfstate"` on every `terraform init`** — enforced by Terraform (fails if key not provided)

3. **Backend key pattern standardized**: `<env>/<stage>/terraform.tfstate` (e.g., `dev/10-management-iam/terraform.tfstate`)

4. **Backend config file pattern**: Each environment has a `backend.hcl` (e.g., `infra/environments/dev/backend.hcl`) that provides the key. `_common/backend.hcl` provides shared config (bucket, region, table).

5. **Documentation updated**: Landing-zone §9 and authentication-plan §6.10b corrected to show `-backend-config=../../_common/backend.hcl` + per-stage `key=` override only; deprecated `force_path_style`/`endpoint` args removed (CH-LZ-006, A-38).

## Consequences

**Enables:**
- Fail-loud: `terraform init` fails immediately if key not provided via `-backend-config`
- Cross-environment state collision impossible — each environment's state is isolated by prefix
- Explicit environment selection at init time (no implicit defaults)
- Consistent with landing-zone §9 isolation scheme

**Trade-offs:**
- Every `terraform init` must include `-backend-config` — adds verbosity
- CI/CD pipelines must pass the correct key for each environment
- Developers must know the key pattern (`<env>/<stage>/terraform.tfstate`)
- Migration required for existing state — existing state at `10-management-iam/terraform.tfstate` must be moved to `dev/10-management-iam/terraform.tfstate` before this takes effect

**Mitigations:**
- Wrapper scripts or Makefile targets encapsulate the `-backend-config` arguments
- `dev.tfvars` and environment documentation show the exact init command
- State migration is a one-time operation documented in runbooks

## References

- **Challenge finding**: CH-LZ-010 (A2-challenger-SX, A2-challenger-DO)
- **Advisory**: M-17 (SX missed CH-LZ-009 + CH-LZ-010), M-32 (SX missed CH-INST-004)
- **Recommendation**: R-37 (include CH-LZ-005/008/009/010 in SX findings)
- **A2 synthesis**: A2-dual-model-challenge.md §4 Agreements A-42, §6.2 M-17
- **A2c decision register**: A2c-decision-register.md §4 Implementation Impact (A-42)
- **User decision**: 2026-07-30, Supreme Leader ruling — "Accepted" for A-42; A0:45 "Omit key from providers.tf"