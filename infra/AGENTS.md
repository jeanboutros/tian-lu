# infra/ — Educational Terraform AWS landing zone on Floci

## OVERVIEW
Secondary project: a heavily-commented Terraform estate (hub-and-spoke, IAM delegation, centralized EKS/k3s, RDS, environment=account) that runs **on Floci** for learning AWS + IaC-at-scale + landing zones. The boundary we rely on is **IAM** (enforced iff Floci signature validation is ON) and **Kubernetes NetworkPolicy** for pod-to-pod; VPC/subnet/SG/NAT/TGW are **modeled**, not enforced.

## STRUCTURE
- `infra/_common/` — **copy-paste templates** (NOT Terraform modules; root modules require their own `terraform { required_providers }` block). Files: `backend.hcl.example` (S3 backend), `providers.tf` (single-endpoint pattern + skip_* flags + default_tags), `versions.tf` (provider pins `aws >= 5.95.0, < 7.0.0`).
- `infra/environments/` — `<env>.tfvars` files. The 12-digit AKID is the env. `dev.tfvars` = `111111111111`.
- `infra/live/NN-name/` — **staged roots**, apply in topological order. Gaps of 10 allow inserting stages. Current: `00-backend-bootstrap/`, `10-management-iam/`. Planned: `20-network-hub`, `30-platform-eks`, `40-app-alpha`, `50-app-beta`, `60-spoke-to-spoke`.
- `infra/eks/` — **0-byte stub** (`main.tf` empty). Reserved for the shared k3s cluster; do not put root modules here.

## WHERE TO LOOK
| Topic | Path |
|---|---|
| Estate architecture, learning primers, refs | `infra/README.md` |
| Design rationale (ADRs, findings, journal) | `../docs/learning/` |
| Solution picture (Mermaid) | `../docs/learning/diagrams/solution.mmd` |
| Preflight gates (G1/G2/G3 must pass before `apply`) | `../scripts/preflight-floci.sh` |
| Provider/endpoint/tags template | `infra/_common/providers.tf` |
| Provider version pins (canonical) | `infra/_common/versions.tf` |
| S3 backend config (override `key` per stage) | `infra/_common/backend.hcl.example` |
| Dev env vars (AKID, CIDRs) | `infra/environments/dev.tfvars` |
| Open gaps requiring runtime test | `../docs/design/gaps-register.md` |

## CONVENTIONS (infra-specific)
- **Stage naming**: `NN-name` with gaps of 10. Apply **top-to-bottom**; downstream stages `data.terraform_remote_state` upstream outputs.
- **Backend wiring**: `00-backend-bootstrap` uses **local state** (chicken/egg, creates the `tf-state-<env>` bucket + `tf-locks-<env>` DynamoDB table). Every other stage: `terraform init -backend-config=../../_common/backend.hcl -backend-config="key=dev/<NN-stage>/terraform.tfstate"`.
- **Env promotion**: copy `dev.tfvars` → `<env>.tfvars`, change `account_id` (new AKID) + backend `key` prefix. Stage code unchanged. Account ID always via `data.aws_caller_identity`, never hardcoded.
- **Provider copy**: every `live/<stage>/` root gets its own `providers.tf` + `versions.tf` copied from `_common/`. Edit the copy, never the template.
- **Provider endpoint pattern**: every service in `endpoints {}` → `var.floci_endpoint` (`http://localhost:4566`). All five `skip_*` flags mandatory. `default_tags { tags = merge({Project="tianlu", Environment=var.environment, ManagedBy="terraform"}, var.default_tags) }`.
- **IAM delegation**: `platform-admin` policy allows `iam:CreateRole` **only** when a `PermissionsBoundary` condition matches. `general_app_boundary` is the ceiling: allows `rds-db:connect`, S3, DynamoDB, Glue, logs, `sts:AssumeRole`; **denies `iam:*` and `organizations:*`**.
- **IRSA stand-in**: assume-role + inject creds into a Secret. Production anti-pattern (Finding 0007); acknowledged.
- **TGW**: modeled in `locals` (Floci has no TGW, Finding 0006).

## ANTI-PATTERNS (infra-specific)
- **Do NOT reference `var.*` inside `.tfvars` files.** `var.environment` is not a thing in tfvars — values are literal. The Project/Environment/ManagedBy merge happens in `providers.tf` from `var.environment` passed via `-var-file`.
- **Do NOT add a `modules/workload-spoke/` or `apps/<service>/` yet.** Phase 0 only; creating empty dirs pollutes the tree.
- **Do NOT change the AWS provider pin in `_common/versions.tf` without updating every stage.** `10-management-iam/providers.tf` currently hardcodes `aws >= 6.56.0` (inline backend, no `versions.tf`) while `_common` ships `>= 5.95.0, < 7.0.0` — **reconcile before adding downstream stages**, or `terraform init` will fail with a constraint conflict in the first stage that copies both files.
- **Do NOT promote from `00-backend-bootstrap` until `terraform apply` shows the S3 bucket + DynamoDB table**. Local state is the only place that records them initially.
- **Do NOT set `Environment = "dev"` directly in `default_tags` for the spoke stages.** The map-merge in `providers.tf` already injects it from `var.environment`; double-tagging breaks `terraform plan` (duplicate key warnings) and ABAC tag-match queries.
- **Do NOT run `terraform apply` without `./scripts/preflight-floci.sh` passing G1/G2/G3.** G1 (signature authorization ON) is a hard stop — without it, the IAM lessons are false demos.

## BUILD STATUS
- [x] Phase 0: `_common/`, `environments/dev.tfvars`, learning docs, preflight gates.
- [ ] Phase 1 (20–40): network-hub, platform-eks, workload-spoke module, app-alpha + FastAPI.
- [ ] Phase 2 (50–60): app-beta (WAL), spoke-to-spoke.
- 10-management-iam: **policy documents authored**; `aws_iam_policy.platform_admin` created, but **no users/roles/groups** and `general_app_boundary` is `data`-only (no `aws_iam_policy` resource). Stub until Phase 1.
- **KNOWN BUG**: `infra/environments/dev.tfvars` `default_tags` map contains `Environment = var.environment` (invalid in tfvars), and also duplicates `Project`/`ManagedBy` already set by the `providers.tf` merge. Fix: remove `Environment`, `Project`, `ManagedBy` from the tfvars `default_tags` map (keep only extras like `Owner`); the `providers.tf` merge injects the canonical trio from `var.environment`.
