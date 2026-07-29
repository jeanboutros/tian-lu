# Finding 0002: No OIDC provider in Floci EKS — IRSA is mocked

**Date:** 2026-07-28
**Related ADR:** ../decisions/0003-centralized-eks-placement.md
**Related session:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md

## AWS expectation
[IAM Roles for Service Accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
federates a pod's projected ServiceAccount token to STS via an **OIDC provider**, delivering
short-lived credentials — pods never hold long-lived keys.

## Floci reality
Floci's EKS exposes a real k3s API but there is **no OIDC provider service** (the IAM surface does not
include `CreateOpenIDConnectProvider`); see the [service matrix](https://floci.io/floci/services/) and
[EKS service page](https://floci.io/floci/services/eks/). Therefore `aws_iam_openid_connect_provider`
and real IRSA cannot be created, and `terraform-aws-modules/eks` must set `enable_irsa=false`.

## Impact on the platform
- App identity uses a **same-account IRSA stand-in**: the app's ServiceAccount is annotated with the
  role ARN and credentials are obtained via `sts:AssumeRole` and injected as a Kubernetes Secret.
- This teaches STS AssumeRole mechanics (which transfer to real IRSA) but is a **production
  anti-pattern** — tracked separately in Finding 0007 with an explicit warning and a side-by-side
  comparison to the real OIDC flow.
