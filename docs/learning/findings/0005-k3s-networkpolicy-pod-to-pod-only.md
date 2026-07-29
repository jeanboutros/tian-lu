# Finding 0005: k3s NetworkPolicy enforces pod-to-pod only — not pod-to-RDS

**Date:** 2026-07-28
**Related ADR:** ../decisions/0002-hub-and-spoke-intent-enforce-iam-netpol.md
**Related session:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md

## AWS expectation
On real EKS, [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
(via the VPC CNI or Calico/Cilium) plus **security groups for pods** give network-layer isolation for
both pod-to-pod and pod-to-database traffic.

## Floci reality
k3s ships a NetworkPolicy controller ([k3s networking](https://docs.k3s.io/networking/basic-network-options)),
so **pod-to-pod** policies are expected to enforce **inside** the cluster. But RDS and ECR run as
**separate sidecar containers on the same bridged `floci-net`** (internal `GAP-013b`,
[docs/design/gaps-register.md](../../design/gaps-register.md)) — a Kubernetes NetworkPolicy governs
traffic within the k3s CNI, **not** a pod reaching an external container's IP. So a pod can still
route to the Postgres container directly.

> Verify on the Lima dev-twin: apply a default-deny policy, confirm cross-namespace pod→service is
> blocked (expected PASS) and note that pod→RDS-container-IP is **not** blocked (expected).

## Impact on the platform
- NetworkPolicy is taught as **pod-to-pod** isolation (a real, enforced control) — verification step
  is scoped accordingly.
- The **database-access** boundary is **IAM DB auth** (pre-flight G2) plus **host UFW**, *not*
  NetworkPolicy. Diagrams and ADR 0002 state the layering explicitly.
