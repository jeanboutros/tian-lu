# Finding 0004: AWS Organizations / SCPs are absent — AKID models environments, guardrails not enforced

**Date:** 2026-07-28
**Related ADR:** ../decisions/0004-environment-as-account-layered-stacks.md
**Related session:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md

## AWS expectation
A landing zone uses **AWS Organizations** with
[Service Control Policies (SCPs)](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
as org/OU/account-wide guardrails, on top of per-account IAM
([WAF SEC01](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/aws-account-management-and-separation.html)).

## Floci reality
AWS Organizations is **not** among Floci's emulated services (not in the
[service matrix](https://floci.io/floci/services/)). Floci *does* isolate resources per
**12-digit Access Key ID = account** ([multi-account](https://floci.io/floci/configuration/multi-account/)),
and STS AssumeRole routes temporary credentials — but there is no SCP enforcement layer.

## Impact on the platform
- We use the AKID/account axis for **environments** (dev/uat/prod); `dev` = `111111111111`.
- Org-wide **guardrails (SCPs)** are documented in comments as the real second layer of defense but
  are **not enforceable** here; IAM + permissions boundaries are the enforced controls.
- Signature authorization must be ON for even IAM to be enforced — pre-flight gate **G1**
  (`FLOCI_AUTH_VALIDATE_SIGNATURES=true`).
