# ADR 0001: Application = one IAM role (the enforced boundary)

**Date:** 2026-07-28
**Status:** Accepted
**Context source:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md
**Related finding:** ../findings/0001-vpc-networking-is-metadata-only.md

## Context
The learner's philosophy is: *"an application is a set of resources — RDS, Glue, Kubernetes — that
all have access to each other."* We need one clear isolation boundary per application. On Floci,
VPC/subnet/security-group networking is **not enforced** (Finding 0001), but **IAM and STS are**
(provided signature authorization is on — see Finding 0004 / pre-flight G1). "Good" here means the
boundary we teach also happens to be the boundary AWS recommends: identity.

## Decision
Each application gets **exactly one IAM role** that is its identity and its blast-radius boundary.
- Least-privilege policy scoped to *that app's* resources (its RDS, its Glue DB), following
  [IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) and
  Well-Architected [SEC03 (permissions management)](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/sec-03.html).
- Access scales with **ABAC**: resources are tagged `App=<name>` and policies match on the tag, so
  adding resources needs no policy edits — see
  [ABAC](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction_attribute-based-access-control.html).
- Every app role is minted **with a permissions boundary** so a delegated admin cannot escalate —
  see [permissions boundaries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html).
- Database access is expressed as an IAM permission (`rds-db:connect`) via
  [RDS IAM database authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html).

## Floci-specific adjustments
- IAM/STS are enforced **only if** `FLOCI_AUTH_VALIDATE_SIGNATURES=true`
  ([env vars](https://floci.io/floci/configuration/environment-variables/)); the pre-flight G1 gate
  asserts this, otherwise the whole lesson is client-side theater.
- ABAC session tags (`kubernetes-namespace`, `service-account`) are **deployer-assigned** here, not
  cryptographically bound by an OIDC JWT (Floci has no OIDC — Finding 0002), so ABAC is *illustrative*.

## Consequences
- Vend-an-app = instantiate the `workload-spoke` module (role + boundary + tagged resources).
- The network boundary is a *separate* concern (k8s NetworkPolicy pod-to-pod + host UFW), not IAM —
  see ADR 0002 and Finding 0005; do not conflate them.

## Alternatives considered
- **One shared role for all apps** — rejected: violates least privilege, no blast-radius containment.
- **Network-only isolation (SG/NACL)** — not enforced in Floci (Finding 0001), and identity-first is
  the AWS-recommended primary boundary anyway.
