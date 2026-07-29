# ADR 0004: Environment = account (AKID); layered stacks with a reusable workload-spoke module

**Date:** 2026-07-28
**Status:** Accepted
**Context source:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md
**Related finding:** ../findings/0004-organizations-and-scps-absent.md

## Context
The learner wants to learn IaC "at scale" and landing zones. AWS separates workloads into accounts
grouped by function into OUs ([Organizing Your AWS Environment](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html);
[WAF SEC01](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/aws-account-management-and-separation.html)).
Floci isolates resources by **12-digit Access Key ID = account**
([multi-account](https://floci.io/floci/configuration/multi-account/)). The learner chose to use the
AKID axis for **environments** (dev/uat/prod), building **dev** now.

## Decision
- **Environment = account = one AKID.** Build `dev` (`111111111111`); uat/prod are future AKIDs.
- Landing-zone **functions** (management, network, cluster, workloads) are **layered Terraform
  stacks** with **isolated remote state per (env, stage)** on Floci's S3 + DynamoDB
  ([S3 backend + locking](https://developer.hashicorp.com/terraform/language/settings/backends/s3)),
  wired via [`terraform_remote_state`](https://developer.hashicorp.com/terraform/language/state/remote-state-data).
- A reusable **`workload-spoke`** module vends an app (VPC + RDS + IAM role + optional namespace).
- **Promotion** dev→uat→prod = same code, new AKID + backend prefix + `environments/<env>.tfvars`.
- Modules are **pinned** ([version constraints](https://developer.hashicorp.com/terraform/language/modules/syntax#version));
  account IDs come from `data.aws_caller_identity.current.account_id`, never hardcoded, so promotion
  needs no ARN edits.

## Floci-specific adjustments
- **AWS Organizations / SCPs are not emulated** (Finding 0004), so cross-account *guardrails* are
  documented, not enforced. Within one env the cluster + workloads share an account (see ADR 0003).

## Consequences
- Clean promotion story and small blast radius per stage; the DAG (`00 → {10,20,30} → {40,50} → 60`)
  must be applied in order (documented in `infra/README.md`).
- Real AWS at scale would use a **function × environment** account grid; the stacks are parameterized
  so each stage could later target a different account by swapping the provider AKID.

## Alternatives considered
- **AKID = function** (network/cluster/workload accounts) — conflicts with using AKID for envs; would
  multiply accounts. **Single root module** — no layering/blast-radius lesson. **Terragrunt** — the
  real DRY-at-scale answer; kept pure-Terraform for now to avoid extra tooling (revisit later).
