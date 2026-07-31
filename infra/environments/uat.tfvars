# environments/uat.tfvars — the UAT environment (= one Floci account = one 12-digit AKID).
# Promotion pattern: same stage code as dev; only environment + account_id (+ backend key) change.
# See environments/dev.tfvars for the annotated reference.

environment = "uat"
account_id  = "333333333333" # uat AKID (dev=111111111111, test=222222222222, prod=444444444444)

region         = "eu-west-2"
floci_endpoint = "http://localhost:4566"

# Accounts are isolated by AKID, so the CIDR layout can be identical across environments.
hub_vpc_cidr     = "10.0.0.0/16"
cluster_vpc_cidr = "10.10.0.0/16"
alpha_vpc_cidr   = "10.20.0.0/16"
beta_vpc_cidr    = "10.30.0.0/16"

default_tags = {
  Owner = "Jean Boutros"
}
