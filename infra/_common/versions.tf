# _common/versions.tf — TEMPLATE. Copy (or symlink) into each infra/live/<stage>/ root.
# Terraform requires provider/version blocks in every root module, so this cannot be a
# shared module; it is a canonical copy to keep pins identical across stages.
#
# Refs:
#   required_version / provider constraints — https://developer.hashicorp.com/terraform/language/modules/syntax#version
#   terraform-aws-modules/eks 21.24.0        — https://github.com/terraform-aws-modules/terraform-aws-eks/releases/tag/v21.24.0

terraform {
  required_version = ">= 1.15.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.57.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.15.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}
