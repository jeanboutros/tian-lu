# environments/dev.tfvars — the DEV environment (= one Floci account = one 12-digit AKID).
#
# Promotion pattern (the IaC-at-scale lesson): to build uat/prod, copy this file, change
# `account_id`, the CIDRs if desired, and the backend key prefix — the *same* stage code
# applies unchanged. See infra/README.md "Environment promotion".
#
# Ref (accounts as the isolation axis): AWS Well-Architected SEC01
#   https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/aws-account-management-and-separation.html

environment = "dev"
account_id  = "111111111111" # dev AKID (test=222222222222, uat=333333333333, prod=444444444444)

region         = "eu-west-2"
floci_endpoint = "http://localhost:4566"

# Non-overlapping CIDRs so the hub-and-spoke topology reads cleanly (metadata in Floci,
# but authored exactly as in real AWS). Floci also seeds a default VPC at 172.31.0.0/16
# which we leave untouched (AWS best practice: do not rely on the default VPC).
hub_vpc_cidr     = "10.0.0.0/16"  # network-only hub (TGW/egress/ingress)
cluster_vpc_cidr = "10.10.0.0/16" # shared EKS (k3s) cluster spoke
alpha_vpc_cidr   = "10.20.0.0/16" # App-Alpha workload spoke
beta_vpc_cidr    = "10.30.0.0/16" # App-Beta workload spoke (Phase 2)

default_tags = {
  Owner = "Jean Boutros"
  # Project, Environment, and ManagedBy are injected by providers.tf's default_tags
  # merge from var.environment. Do NOT duplicate them here — merge precedence means
  # the providers.tf values silently override any duplicate keys in this map, with
  # no diagnostic.
}
