# ADR 0002: Model hub-and-spoke (incl. Transit Gateway) as declarative intent; enforce via IAM + NetworkPolicy

**Date:** 2026-07-28
**Status:** Accepted
**Context source:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md
**Related finding:** ../findings/0006-no-transit-gateway-or-vpc-peering.md

## Context
Hub-and-spoke networking centralizes connectivity through a hub — normally an AWS
[Transit Gateway](https://docs.aws.amazon.com/vpc/latest/tgw/how-transit-gateways-work.html) — per the
[Building a Scalable and Secure Multi-VPC Network Infrastructure](https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/welcome.html)
whitepaper. But Floci's EC2 implements neither **Transit Gateway** nor **VPC peering** actions
(Finding 0006), and VPC/subnet/SG are metadata only (Finding 0001).

## Decision
Author the hub-and-spoke topology — VPCs, subnets, NAT egress, and the **TGW attachments + route
tables** — but model the TGW itself as **declarative Terraform `locals`** (a "routing intent" data
structure) rather than `aws_ec2_transit_gateway*` resources, with comments showing the exact
real-AWS resources to swap in. Enforce only what Floci actually honors:
- **IAM** for API-level access (who may call RDS/EKS/Glue) — enforced.
- **Kubernetes [NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)**
  for pod-to-pod traffic in the shared k3s cluster — enforced (Finding 0005).

## Floci-specific adjustments
- `aws_ec2_transit_gateway*` and `aws_vpc_peering_connection` would **fail at apply** (Finding 0006);
  the `transit` locals avoid that while preserving the learning artifact and real-AWS parity.

## Consequences
- **Layering must be taught explicitly:** TGW route tables are **L3 packet routing**; IAM is
  **API-call authorization**; NetworkPolicy is **L4 pod traffic**. They operate at *different layers*.
  A learner must not conclude that IAM controls packet forwarding.
- Promoting to real AWS = replace the `transit` locals with `aws_ec2_transit_gateway`,
  `_vpc_attachment`, and `_route_table` resources; the spoke VPCs and app code are unchanged.

## Alternatives considered
- **Create real `aws_ec2_transit_gateway`** — fails apply on Floci (unimplemented action).
- **VPC peering** as a fallback — also unimplemented in Floci (Finding 0006).
