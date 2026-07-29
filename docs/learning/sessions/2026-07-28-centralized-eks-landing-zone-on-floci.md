# Session: Centralized-EKS landing zone on Floci (app = IAM role, env = account)

**Date:** 2026-07-28
**Question:** How do we build, for learning, an admin that manages IAM, an EKS-in-a-VPC, and an app
with its own IAM policy to reach an RDS in the same VPC — hub-and-spoke, "one IAM role per
application", plus a spoke-to-spoke connection to another app that is just an RDS Postgres with WAL —
all on Floci?
**Outcome:** accepted → implementation started
**Decision records:** ../decisions/0001..0005
**Related findings:** ../findings/0001..0007

## Challenge
Sharpened problem: teach AWS + networking + IaC-at-scale + landing zones on Floci, where the honest
constraint is that **VPC networking is not enforced** — so the *enforced* boundary must be **IAM**
(and k8s NetworkPolicy for pod-to-pod). Clarifying decisions taken with the learner:
- Terraform layout → **numbered, layered stages** with isolated remote state (learn IaC at scale).
- In-cluster app → **custom FastAPI**, built and pushed to Floci ECR, run in k3s.
- EKS placement → **centralized** (shared cluster in its own spoke; apps = namespaces).
- Account axis → **AKID = environment** (dev/uat/prod); build **dev**; functions = layers within dev.
- Docs → **full learn.md deliverables** + commented Terraform + README + diagram.

## Research briefs
### Lens 1 — AWS Well-Architected
Accounts are a hard boundary; separate workloads by function into OUs; least privilege; permissions
boundaries for delegation; ABAC to scale access. Sources: WAF
[SEC01](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/aws-account-management-and-separation.html),
[SEC03](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec-03.html),
[permissions boundaries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html),
[ABAC](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction_attribute-based-access-control.html).
### Lens 2 — Real-world / community (EKS)
Network account ≠ cluster account ≠ workload accounts; centralized (shared cluster, namespaces) vs
de-centralized (cluster per workload); "the cluster is the only strong security boundary". Sources:
[EKS multi-account](https://docs.aws.amazon.com/eks/latest/best-practices/multi-account-strategy.html),
[EKS tenant isolation](https://docs.aws.amazon.com/eks/latest/best-practices/tenant-isolation.html).
### Lens 3 — Floci reconciliation
EKS = real k3s, RDS = real Postgres (WAL native); VPC/SG metadata-only; **no Transit Gateway / VPC
peering**; no OIDC; Organizations/SCPs absent; 12-digit AKID = account; S3+DynamoDB usable as TF
backend. Sources: [services](https://floci.io/floci/services/),
[ec2](https://floci.io/floci/services/ec2/), [multi-account](https://floci.io/floci/configuration/multi-account/),
internal GAP-013b in [gaps-register](../../design/gaps-register.md).

## Debate
- **EKS in the hub?** No — the hub is network-only; EKS belongs in a spoke (cluster spoke, centralized).
- **Model TGW or drop it?** Floci can't create it; model as declarative `locals` and enforce intent
  via IAM + NetworkPolicy (do not conflate L3 routing with API auth or L4 pod policy).
- **Is the network the boundary?** Not in Floci — IAM + NetworkPolicy are; VPC/SG are learning-shaped
  metadata.

## Synthesis
Centralized EKS in its own spoke; one workload spoke per app; one IAM role per app (ABAC + permissions
boundary); env = account (dev); layered stacks with remote state on Floci S3/DynamoDB; reusable
`workload-spoke` module; IAM DB auth as the app→RDS control; spoke-to-spoke gated by IAM + NetworkPolicy.

## Adversarial review (2 challengers, Claude Sonnet, 2026-07-28)
Both returned **approve-with-changes**. Incorporated:
- **Pre-flight gates** before any apply (`scripts/preflight-floci.sh`): G1 signature authorization ON;
  G2 RDS IAM auth really enforced (fake-token rejected); G3 DynamoDB conditional-write locking; G4
  NetworkPolicy scope is pod-to-pod only; G5 k3s admin-token check.
- **EKS module** must disable OIDC/node-groups/KMS/CloudWatch sub-resources.
- **Finding 0007** added (IRSA-via-Secret anti-pattern); **Finding 0005** corrected (pod-to-pod only).
- **References** attached to every decision (see each ADR + `infra/README.md`).

## Your decision
**Accept** and begin implementation (Phase 0 foundations first, then Phase 1).
