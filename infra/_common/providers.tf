# _common/providers.tf — TEMPLATE. Copy into each infra/live/<stage>/ root.
# Points every AWS SDK/Terraform call at Floci (a local AWS emulator on port 4566).
# This is the LocalStack-style "single endpoint" pattern.
#
# Refs:
#   Floci common setup / AWS_ENDPOINT_URL — https://floci.io/floci/services/#common-setup
#   provider default_tags                 — https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags
#   multi-account (12-digit AKID = account) — https://floci.io/floci/configuration/multi-account/

variable "environment" { type = string } # dev | uat | prod  (AKID axis)
variable "account_id" { type = string }  # 12-digit AKID; becomes the Floci account id
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

  # In Floci, a 12-digit Access Key ID selects the account. The secret is not validated
  # in dev, but signature *authorization* MUST be enabled (see scripts/preflight-floci.sh G1).
  access_key = var.account_id
  secret_key = var.secret_key

  # Emulator conveniences — skip real-AWS-only preflight calls.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # Mandatory governance tags on every taggable resource.
  default_tags {
    tags = merge({
      Project     = "tianlu"
      Environment = var.environment
      ManagedBy   = "terraform"
    }, var.default_tags)
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
