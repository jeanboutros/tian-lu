# Finding 0001: VPC / subnet / security-group networking is metadata-only in Floci

**Date:** 2026-07-28
**Related ADR:** ../decisions/0002-hub-and-spoke-intent-enforce-iam-netpol.md
**Related session:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md

## AWS expectation
In real AWS, VPCs, subnets, route tables, and **security groups** enforce packet-level isolation —
a wrong SG rule *blocks traffic*. See the
[VPC + NAT scenario](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html).

## Floci reality
Floci's EC2 **creates these as records** (VPC, Subnet, RouteTable, IGW, NatGateway, SecurityGroup,
NACL, EIP) but does **not** enforce them as a data plane — see the
[EC2 service page](https://floci.io/floci/services/ec2/): *"Security group rules are not enforced as a
firewall (Docker bridge networking handles routing)."* All container-backed services share one bridged
network `floci-net`, so a pod can reach any sidecar regardless of VPC/SG — internal `GAP-013b` in
[docs/design/gaps-register.md](../../design/gaps-register.md).

## Impact on the platform
- The `terraform-aws-modules/vpc` module **applies cleanly** (records are accepted), so the topology
  is authored exactly as in real AWS — good for learning.
- But network isolation is **not** provided by VPC/SG here. The enforced boundaries are **IAM**
  (API auth) and **Kubernetes NetworkPolicy** (pod-to-pod, Finding 0005). Lessons and diagrams mark
  VPC/SG/TGW as *metadata* (grey/dashed) vs *real* (green).
