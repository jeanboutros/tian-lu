# Finding 0006: Floci EC2 implements neither Transit Gateway nor VPC Peering

**Date:** 2026-07-28
**Related ADR:** ../decisions/0002-hub-and-spoke-intent-enforce-iam-netpol.md
**Related session:** ../sessions/2026-07-28-centralized-eks-landing-zone-on-floci.md

## AWS expectation
Hub-and-spoke connectivity uses a
[Transit Gateway](https://docs.aws.amazon.com/vpc/latest/tgw/how-transit-gateways-work.html)
(or, for simple pairs, VPC peering) with route-table associations controlling which spokes reach which.

## Floci reality
Floci's EC2 exposes **78 actions** covering `Vpc`, `Subnet`, `RouteTable`/`CreateRoute`,
`InternetGateway`, `NatGateway`, `SecurityGroup`, `NetworkAcl`, `ElasticIp`, `VpcEndpoint`,
`Instances`, `KeyPairs`, `Tags`, `LaunchTemplates`, `Volumes` — but the **Transit Gateway** and
**VPC Peering** action families are **not** in the list (verified on the
[EC2 service page](https://floci.io/floci/services/ec2/)). So `aws_ec2_transit_gateway*` and
`aws_vpc_peering_connection` **fail at `terraform apply`**.

## Impact on the platform
- The hub's TGW, its attachments, and its route tables are modeled as declarative Terraform
  **`locals`** (routing *intent*) with comments showing the real-AWS resources to swap in (ADR 0002).
- The supported VPC primitives (VPC/subnet/route-table/IGW/NAT/SG/NACL/EIP) are still created as
  records, so the `terraform-aws-modules/vpc` module applies and the topology is authored faithfully.
- Enforcement of the *intent* (who may reach whom) is done where Floci can: **IAM** + **NetworkPolicy**.
