# ADR 0003: Centralized EKS — one shared cluster in its own spoke; apps are namespaces

**Date:** 2026-07-28
**Status:** Accepted
**Context source:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md
**Related finding:** ../findings/0002-no-oidc-irsa-is-mocked.md

## Context
"Should EKS be its own spoke?" AWS guidance says the **network account**, the **cluster account**,
and the **workload accounts** are distinct — EKS never lives in the network hub
([EKS multi-account best practices](https://docs.aws.amazon.com/eks/latest/best-practices/multi-account-strategy.html);
Well-Architected [SEC01](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/aws-account-management-and-separation.html):
"accounts are a hard boundary"). Two blessed patterns exist: **centralized** (one shared cluster,
apps as namespaces) vs **de-centralized** (a cluster per workload). The learner chose **centralized**.

## Decision
Run **one shared EKS (real k3s) cluster in its own "cluster" spoke** VPC. Each application:
- is a **namespace** in that cluster (soft multi-tenancy), isolated with RBAC, ResourceQuota, and a
  default-deny [NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/);
- also owns a **workload spoke** (its VPC + RDS + IAM role).

Grounded in [EKS tenant isolation](https://docs.aws.amazon.com/eks/latest/best-practices/tenant-isolation.html):
"the cluster is the only construct that provides a strong security boundary" — namespaces are *soft*
multi-tenancy, so we layer RBAC + quotas + NetworkPolicy on top, and use
[Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/).

## Floci-specific adjustments
- Floci EKS = **one k3s container** per cluster; centralized keeps that to a single container.
- **No OIDC** in Floci EKS → real [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
  is unavailable; app identity uses a same-account **IRSA stand-in** (Finding 0002, and the
  anti-pattern warning in Finding 0007).
- On the `terraform-aws-modules/eks` module, disable sub-resources Floci cannot create:
  `enable_irsa=false`, `create_cloudwatch_log_group=false`, `cluster_enabled_log_types=[]`,
  `create_kms_key=false` + empty `cluster_encryption_config`, and **no managed/self node groups**
  (k3s is the node). Prefer the
  [EKS Access Entries API](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html) over
  the deprecated `aws-auth` ConfigMap where the module allows.

## Consequences
- **Shared blast radius** (one cluster) — acceptable for a learning lab; contrasted with the
  de-centralized alternative in the session doc.
- Because AKID = environment (ADR 0004), cluster + workloads share the dev account, so workload
  isolation rests on VPC + IAM + namespace + tags (weaker than an account boundary — stated plainly).

## Alternatives considered
- **De-centralized** (one EKS per workload spoke) — stronger isolation, one k3s container per app;
  documented as the alternative and reachable by flipping the module's `enable_eks` intent.
