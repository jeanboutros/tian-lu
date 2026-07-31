# infra/ — Educational Terraform AWS landing zone on Floci

## OVERVIEW
Secondary project: a heavily-commented Terraform estate (hub-and-spoke, IAM delegation, centralized EKS/k3s, RDS, environment=account) that runs **on Floci** for learning AWS + IaC-at-scale + landing zones. The boundary we rely on is **IAM** (enforced iff Floci signature validation is ON) and **Kubernetes NetworkPolicy** for pod-to-pod; VPC/subnet/SG/NAT/TGW are **modeled**, not enforced.

## STRUCTURE
- `infra/Makefile` — **the entry point.** Convenience targets over `stage.sh` (`make init/plan/apply/destroy`, `plan-all`, `lint-infra`, `verify-backend`). `make help` documents all of them.
- `infra/stage.sh` — drives one stage for one environment (`init|plan|apply|destroy|fmt|validate`). The **only** place terraform is invoked; covered by `../tests/stage_wrapper.bats`.
- `infra/scripts/help.sh` — the `make help` text (same pattern as the repo-root `scripts/help.sh`).
- `infra/.gitignore` — ignores the **generated** `live/*/providers.tf`, `live/*/versions.tf` and `live/*/.terraform-validate/`.
- `infra/_common/` — **templates copied into each stage** (NOT Terraform modules; root modules require their own `terraform { required_providers }` block). Files: `backend-<env>.hcl` (per-env S3 backend), `providers.tf` (single-endpoint pattern + skip_* flags + default_tags), `versions.tf` (provider pins — canonical: `aws >= 6.56.0`, plus kubernetes/helm/random/null).
- `infra/environments/` — `<env>.tfvars` files, one per environment (`dev`, `test`, `uat`, `prod`). The 12-digit AKID is the env. `dev.tfvars` = `111111111111`.
- `infra/live/NN-name/` — **staged roots**, apply in topological order. Gaps of 10 allow inserting stages. Current: `00-backend-bootstrap/`, `10-management-iam/`. Planned: `20-network-hub`, `30-platform-eks`, `40-app-alpha`, `50-app-beta`, `60-spoke-to-spoke`.
- `infra/eks/` — **0-byte stub** (`main.tf` empty). Reserved for the shared k3s cluster; do not put root modules here.

## WHERE TO LOOK
| Topic | Path |
|---|---|
| How to run anything (targets, flags, env vars) | `make help` → `infra/scripts/help.sh` |
| Terraform invocation, backend/var-file wiring | `infra/stage.sh` |
| Tests for that wiring | `../tests/stage_wrapper.bats` |
| Estate architecture, learning primers, refs | `infra/README.md` |
| Design rationale (ADRs, findings, journal) | `../docs/learning/` |
| Solution picture (Mermaid) | `../docs/learning/diagrams/solution.mmd` |
| Preflight gates (G1/G2/G3 must pass before `apply`) | `../scripts/preflight-floci.sh` |
| Provider/endpoint/tags template | `infra/_common/providers.tf` |
| Provider version pins (canonical) | `infra/_common/versions.tf` |
| S3 backend config (per env; override `key` per stage) | `infra/_common/backend-<env>.hcl` |
| Dev env vars (AKID, CIDRs) | `infra/environments/dev.tfvars` |
| Open gaps requiring runtime test | `../docs/design/gaps-register.md` |

## CONVENTIONS (infra-specific)
- **Stage naming**: `NN-name` with gaps of 10. Apply **top-to-bottom**; downstream stages `data.terraform_remote_state` upstream outputs.
- **Backend wiring**: `00-backend-bootstrap` uses **local state** (chicken/egg, creates the `tf-state-<env>` bucket + `tf-locks-<env>` DynamoDB table). Every other stage uses the per-env S3 backend, which `infra/stage.sh` derives: `./infra/stage.sh init <env> <NN-stage>` (or `terraform init -backend-config=../../_common/backend-<env>.hcl -backend-config="key=<env>/<NN-stage>/terraform.tfstate"`).
- **Env promotion**: copy `dev.tfvars` → `<env>.tfvars`, change `account_id` (new AKID). Stage code unchanged. `account_id` is supplied via `var.account_id`; a `data.aws_caller_identity` postcondition verifies the AKID resolved to that account.
- **Provider copy is GENERATED**: every `live/<stage>/` root gets its own `providers.tf` + `versions.tf`, copied from `_common/` by `stage.sh` on `make init`. Those copies are **git-ignored build output** — `_common/` is the single source of truth. **Edit the template, never the copy**: run `make init STAGE=<stage>` to regenerate, or `make init STAGE=<stage> FLAGS=--force` to overwrite a copy that has drifted (without `--force` a drifted copy is left alone with a warning). `00-backend-bootstrap` is exempt — it declares its provider and `required_providers` inline in `main.tf`, because it creates the backend the other stages use.
- **Provider endpoint pattern**: every service in `endpoints {}` → `var.floci_endpoint` (`http://localhost:4566`). All five `skip_*` flags mandatory. `default_tags { tags = merge({Project="tianlu", Environment=var.environment, ManagedBy="terraform"}, var.default_tags) }`.
- **IAM delegation**: `platform-admin` policy allows `iam:CreateRole` **only** when a `PermissionsBoundary` condition matches. `general_app_boundary` is the ceiling: allows `rds-db:connect`, S3, DynamoDB, Glue, logs, `sts:AssumeRole`; **denies `iam:*` and `organizations:*`**.
- **IRSA stand-in**: assume-role + inject creds into a Secret. Production anti-pattern (Finding 0007); acknowledged.
- **TGW**: modeled in `locals` (Floci has no TGW, Finding 0006).

## ANTI-PATTERNS (infra-specific)
- **Do NOT reference `var.*` inside `.tfvars` files.** `var.environment` is not a thing in tfvars — values are literal. The Project/Environment/ManagedBy merge happens in `providers.tf` from `var.environment` passed via `-var-file`.
- **Do NOT add a `modules/workload-spoke/` or `apps/<service>/` yet.** Phase 0 only; creating empty dirs pollutes the tree.
- **Do NOT change the AWS provider pin in `_common/versions.tf` without re-running `make init` on every stage.** The pin lives in exactly two places: `_common/versions.tf` (copied into each stage) and `00-backend-bootstrap/main.tf` (inline, because that stage is never synced). Change one without the other and `terraform init` fails with a constraint conflict. After any pin change: `make init-all`, then `make lint-infra`.
- **Do NOT hand-edit `live/<stage>/providers.tf` or `versions.tf`.** They are git-ignored generated copies; the next `make init FLAGS=--force` discards the edit and git cannot recover it. Edit `_common/` instead.
- **Do NOT promote from `00-backend-bootstrap` until `terraform apply` shows the S3 bucket + DynamoDB table**. Local state is the only place that records them initially.
- **Do NOT set `Environment = "dev"` directly in `default_tags` for the spoke stages.** The map-merge in `providers.tf` already injects it from `var.environment`; double-tagging breaks `terraform plan` (duplicate key warnings) and ABAC tag-match queries.
- **Do NOT run `terraform apply` without `./scripts/preflight-floci.sh` passing G1/G2/G3.** G1 (signature authorization ON) is a hard stop — without it, the IAM lessons are false demos. `make apply` enforces this automatically; `SKIP_PREFLIGHT=1` bypasses it and should be used only when you have already run the gates in the same session.
- **Do NOT call `terraform` directly in a stage directory.** Use `make` / `stage.sh`: they resolve the per-env backend, the state key `<env>/<stage>/terraform.tfstate`, the var-file, and the bootstrap special-casing. `-backend-config` belongs to `init` only — passing it to `plan`/`apply` is rejected by Terraform.

## BUILD STATUS
- [x] Phase 0: `_common/`, `environments/dev.tfvars`, learning docs, preflight gates.
- [ ] Phase 1 (20–40): network-hub, platform-eks, workload-spoke module, app-alpha + FastAPI.
- [ ] Phase 2 (50–60): app-beta (WAL), spoke-to-spoke.
- 10-management-iam: policy documents authored; `aws_iam_policy.platform_admin` **and** `aws_iam_policy.general_app_boundary` created (the boundary must exist as a real managed policy — a boundary is attached by ARN, and `platform_admin`'s statements reference that ARN). Still **no users/roles/groups** — stub until Phase 1. `terraform validate` passes.
- 10-management-iam declares no CIDR variables (`variables.tf` was removed), so the four `*_vpc_cidr` values in the shared `<env>.tfvars` produce four harmless *undeclared variable* warnings. `00-backend-bootstrap` suppresses the equivalent warnings by declaring them with `default = null`; mirror that if the noise becomes a problem.
