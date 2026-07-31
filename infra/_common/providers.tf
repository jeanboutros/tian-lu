# _common/providers.tf — TEMPLATE. Copy into each infra/live/<stage>/ root.
# Points every AWS SDK/Terraform call at Floci (a local AWS emulator on port 4566).
# This is the LocalStack-style "single endpoint" pattern.
#
# Refs:
#   Floci common setup / AWS_ENDPOINT_URL — https://floci.io/floci/services/#common-setup
#   provider default_tags                 — https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags
#   multi-account (12-digit AKID = account) — https://floci.io/floci/configuration/multi-account/

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "test", "uat", "prod"], var.environment)
    error_message = "environment must be one of dev, test, uat, prod (see landing-zone-design.md §4.1)."
  }
}
variable "account_id" { type = string } # 12-digit AKID; becomes the Floci account id
variable "secret_key" {
  type      = string
  sensitive = true
}
variable "region" {
  type    = string
  default = "eu-west-2"
}
variable "floci_endpoint" {
  type    = string
  default = "http://localhost:4566"
}
variable "default_tags" {
  type    = map(string)
  default = {}
}

provider "aws" {
  region = var.region

  # A 12-digit Access Key ID selects the Floci account AND authenticates as that account's
  # root principal (accepted limitation — see docs/design/authentication-plan.md).
  # Floci 1.5.33-compat does not verify the secret (docs/issues/floci-signature-validation-ignored.md);
  # secret_key is future-facing, not yet an enforced boundary.
  access_key = var.account_id
  secret_key = var.secret_key

  # Emulator conveniences — skip real-AWS-only preflight calls.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # Mandatory governance tags on every taggable resource.
  # var.default_tags is merged FIRST so governance keys CANNOT be overridden by tfvars.
  default_tags {
    tags = merge(var.default_tags, {
      Project     = "tianlu"
      Environment = var.environment
      ManagedBy   = "terraform"
    })
  }

  # Point each service used by this estate at Floci's single port.
  endpoints {
    iam            = var.floci_endpoint
    sts            = var.floci_endpoint
    ec2            = var.floci_endpoint
    eks            = var.floci_endpoint
    rds            = var.floci_endpoint
    s3             = var.floci_endpoint
    dynamodb       = var.floci_endpoint
    glue           = var.floci_endpoint
    ecr            = var.floci_endpoint
    secretsmanager = var.floci_endpoint
    kms            = var.floci_endpoint
    logs           = var.floci_endpoint
    sns            = var.floci_endpoint
    sqs            = var.floci_endpoint
  }
}

# The 12-digit AKID must resolve to the expected account. Fails the plan if it does not
# (e.g. a non-12-digit key silently fell back to FLOCI_DEFAULT_ACCOUNT_ID).
data "aws_caller_identity" "current" {
  lifecycle {
    postcondition {
      condition     = self.account_id == var.account_id
      error_message = "Resolved account ${self.account_id} does not match var.account_id ${var.account_id}: the AKID did not select the expected account."
    }
  }
}
