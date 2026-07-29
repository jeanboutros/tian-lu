# Finding 0007: IRSA-via-Secret is a Floci stand-in and a production anti-pattern

**Date:** 2026-07-28
**Related ADR:** ../decisions/0003-centralized-eks-placement.md
**Related session:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md

## AWS expectation
Real [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
(and EKS Pod Identity) deliver **short-lived** credentials to a pod via a **projected ServiceAccount
token** exchanged at STS through an OIDC provider. Pods never hold long-lived keys; the namespace and
service-account identity are cryptographically bound in the token's claims.

## Floci reality
With no OIDC (Finding 0002), we approximate identity by calling `sts:AssumeRole` at deploy time and
injecting the resulting credentials into a **Kubernetes Secret** mounted by the pod.

| Aspect | Real IRSA | Floci stand-in |
|---|---|---|
| Credential lifetime | short-lived, auto-rotated | assumed creds in a Secret (longer-lived) |
| Identity binding | OIDC JWT claims (unforgeable) | deployer-assigned tags (not bound) |
| Pod sees keys? | no (token exchange) | yes (Secret) |

## Impact on the platform
- **Teaching value:** demonstrates `sts:AssumeRole` and the *shape* of per-pod identity, which
  transfers to real IRSA.
- **Warning (must be surfaced in the module README):** this pattern is **not production-safe** —
  it is credential sprawl. In real EKS, use IRSA or EKS Pod Identity; never bake assumed credentials
  into Secrets. ABAC session tags here are **illustrative**, not cryptographically enforced.
- If Floci later adds OIDC, migrate the `workload-spoke` module to real IRSA.
