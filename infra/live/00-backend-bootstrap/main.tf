# 00-backend-bootstrap — creates the S3 bucket + DynamoDB lock table that EVERY other stage
# uses as its remote backend. This stage necessarily uses LOCAL state (chicken/egg): it must
# create the backend before any stage can store state in it.
#
# Refs:
#   S3 backend + locking — https://developer.hashicorp.com/terraform/language/settings/backends/s3
#   Floci S3/DynamoDB     — https://floci.io/floci/services/  (both emulated)
#
# Apply:
#   terraform init      # local state, no backend
#   terraform apply -var-file=../../environments/dev.tfvars

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.56.0"
    }
  }
  # NOTE: intentionally LOCAL state. Keep terraform.tfstate out of git (see .gitignore);
  # re-running apply against Floci is cheap and idempotent.
}

variable "environment" {
  type = string
}

variable "account_id" {
  type = string # 12-digit AKID => Floci account
}

variable "secret_key" {
  type      = string
  sensitive = true
}

variable "region" {
  type = string
}

variable "floci_endpoint" {
  type = string
}

# Unused here but present so the shared dev.tfvars (which sets CIDRs/tags) applies cleanly.
variable "default_tags" {
  type    = map(string)
  default = {}
}
variable "hub_vpc_cidr" {
  type    = string
  default = null
}
variable "cluster_vpc_cidr" {
  type    = string
  default = null
}
variable "alpha_vpc_cidr" {
  type    = string
  default = null
}
variable "beta_vpc_cidr" {
  type    = string
  default = null
}

provider "aws" {
  region = var.region
  # A 12-digit AKID selects the Floci account and authenticates as its root principal
  # (accepted; see docs/design/authentication-plan.md). Floci 1.5.33-compat does not verify
  # the secret (docs/issues/floci-signature-validation-ignored.md).
  access_key = var.account_id
  secret_key = var.secret_key

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  default_tags {
    tags = merge({
      Project     = "tianlu"
      Environment = var.environment
      ManagedBy   = "terraform"
      Stage       = "00-backend-bootstrap"
    }, var.default_tags)
  }

  endpoints {
    s3       = var.floci_endpoint
    dynamodb = var.floci_endpoint
  }
}

# Remote state bucket (one per environment).
resource "aws_s3_bucket" "tf_state" {
  bucket = "tf-state-${var.environment}"
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# State lock table. Terraform locking relies on conditional writes — verify with
# scripts/preflight-floci.sh gate G3 before trusting it for concurrent use.
resource "aws_dynamodb_table" "tf_locks" {
  name         = "tf-locks-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  description = "S3 bucket for remote state; set as `bucket` in every other stage's backend."
  value       = aws_s3_bucket.tf_state.id
}

output "lock_table" {
  description = "DynamoDB table for state locking; set as `dynamodb_table` in each backend."
  value       = aws_dynamodb_table.tf_locks.name
}
