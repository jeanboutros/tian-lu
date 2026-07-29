terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.56.0"
    }

  }
  backend "s3" {
    bucket = "tf-state-dev"
    key    = "10-management-iam/terraform.tfstate"
  }
}

provider "aws" {
  region = var.region


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
  }
}
