# Learning Journal

Append-only. One entry per accepted round, newest at the bottom.

<!-- Entry format:
## YYYY-MM-DD — <topic>
**Learned:** <the one-paragraph insight>
**Decided:** <ADR NNNN, if any>
**Floci gap:** <Finding NNNN, if any>
-->

## 2026-07-28 — Centralized-EKS landing zone on Floci (app = IAM role, env = account)
**Learned:** On an emulator that doesn't enforce VPC networking, the *enforced* boundary must be
identity. Modeling a real hub-and-spoke landing zone (VPC, NAT, Transit Gateway, EKS placement) is
still worth authoring for the learning and real-AWS parity, but you must be explicit about which
controls are enforced (IAM, k8s NetworkPolicy pod-to-pod) versus modeled (VPC/SG/TGW). Two Sonnet
challengers both returned approve-with-changes and surfaced the biggest risk: several lessons become
*false demos* unless verified at runtime (signature authorization ON, RDS IAM auth actually rejecting
a fake token, DynamoDB conditional-write locking) — hence a pre-flight gate script before any apply.
**Decided:** ADR 0001 (app = IAM role), 0002 (hub-spoke as intent; enforce via IAM + NetworkPolicy),
0003 (centralized EKS), 0004 (env = account + layered stacks), 0005 (spoke-to-spoke IAM-gated).
**Floci gap:** Findings 0001 (VPC metadata-only), 0002 (no OIDC/IRSA), 0003 (NodePort/LB unverified),
0004 (Organizations/SCPs absent), 0005 (NetworkPolicy pod-to-pod only), 0006 (no TGW/VPC peering),
0007 (IRSA-via-Secret anti-pattern).
