
###############################################################################
# IAM NAMING CONVENTION  (authored here for now; move to docs/ later)
#
# Two namespaces live in this file -- keep them distinct:
#   * Terraform identifiers -- the 2nd label, e.g. "platform_admin_boundary":
#     snake_case. Local to Terraform state; AWS never sees them.
#   * AWS entity names -- the `name` on aws_iam_role / aws_iam_policy: the
#     convention below. Account-global, embedded in every ARN, and matched by
#     the scoping wildcards in the policies further down.
#
# Rule: lowercase kebab-case, prefix `tianlu-`, a single `-` between tokens.
# ARN wildcard matching is CASE- and DELIMITER-sensitive, so a name that drifts
# from this shape silently falls outside a scoping wildcard and its guardrail
# stops applying -- with no error.
#
#   roles      tianlu-platform-admin            delegated IAM admin   (singleton)
#              tianlu-infra-deployer            Crossplane identity   (singleton)
#              tianlu-app-<app>                 app execution role    (per app)
#              tianlu-app-<app>-support         human support role    (per app)
#   policies   tianlu-<role>-policy             identity policy for <role>
#              tianlu-app-baseline-policy       shared by every app role
#   boundaries tianlu-app-boundary              ceiling for app roles
#              tianlu-support-boundary          ceiling for support roles
#              tianlu-platform-admin-boundary   ceiling for platform-admin
#              tianlu-infra-deployer-boundary   ceiling for infra-deployer
#
#   <app> is the lowercase app token: alfa, beta. A role's identity policy is
#   "<role-name>-policy", e.g. tianlu-app-alfa-support-policy.
#
# Scoping wildcards these names make reliable:
#   role/tianlu-app-*           every app role (execution AND support)
#   role/tianlu-app-*-support   support roles only
#   policy/tianlu-app-*         per-app + baseline policies. NOTE: also matches
#                               tianlu-app-boundary, so a boundary is protected
#                               only by the explicit policy/*-boundary deny.
#   policy/*-boundary           every boundary policy
#
# A boundary is an ordinary managed policy attached in the boundary slot, not a
# distinct type. Length ceilings: role name <= 64, policy name <= 128.
#
# sids: PascalCase, state intent + effect, unique within one document, and take
# no tianlu- prefix (a sid is document-scoped, not an account-global name).
###############################################################################

# This data source retrieves information about the current AWS account and user. It is 
# used to get the account ID and other details that may be needed for resource creation or
# policy definitions. It can be used as ${data.aws_caller_identity.current.account_id} to
# reference the account ID in other parts of the Terraform configuration.
# There is no to redefine this data source in the current configuration, as it already exists
# in the provider.tf so adding it here for reference.
# 
# data "aws_caller_identity" "current" {}


# First we define the App Permissions Boundary Policy
# This policy is a top-level security policy. It applies to all application roles. 
# It allows standard application actions (S3, RDS, CloudWatch) while strictly banning 
# high-risk operations (like modifying IAM or deleting logs).
data "aws_iam_policy_document" "app_permission_boundary" {

  # Define the generic permissions that are allowed for a standard application.
  statement {
    sid = "TianLuAppPermissionBoundaryAllows"

    actions = [
      "s3:*",
      "rds:*",
      "rds-db:connect",
      "dynamodb:*",
      "glue:*",
      "logs:*",
      "sts:AssumeRole",
    ]

    effect = "Allow"

    resources = [
      "*",
    ]
  }

  # Define the high-risk permissions that are denied for all application roles.
  # Explicit are better than implicit, so we explicitly deny these actions to ensure that application roles cannot perform them.
  statement {
    sid = "TianLuAppPermissionBoundaryDenies"

    actions = [
      "iam:*",
      "organizations:*",
      "account:*",
      "aws-portal:*",
      "kms:ScheduleKeyDeletion",
    ]

    effect = "Deny"

    resources = [
      "*",
    ]
  }
}

# Define the Platform-Admin boundary
# The platform admin can mint iam roles for applications, but cannot delete keys or
# perform other high-risk operations. They also cannot rewrite the ceiling, or mint an
# admin role for itself.
data "aws_iam_policy_document" "platform_admin_boundary" {
  
  # Allow the platform admin to perform all IAM actions on application roles and policies.
  statement {
    sid = "TianLuPlatformAdminBoundaryAllows"

    actions = [
      "iam:*",
    ]

    effect = "Allow"

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/tianlu-app-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/tianlu-app-*",
    ]
  }

  # Allow the platform admin to introspect any IAM resources.
  statement {
    sid = "TianLuPlatformAdminBoundaryAllowsForItself"

    actions = [
      "iam:Get*",
      "iam:List*",
    ]

    effect = "Allow"

    resources = [
      "*",
    ]
  }

  # Deny the modification of itself
  statement {
    sid = "TianLuPlatformAdminBoundaryDenies"

    actions = [
      "*"
    ]

    effect = "Deny"

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/tianlu-platform-admin",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/tianlu-*-boundary",
    ]
  }

  # Deny IAM writes outside the role/tianlu-app-* and policy/tianlu-app-* namespace. This prevents the platform admin from creating or modifying IAM roles and policies that are not part of the application namespace.
  statement {
    sid = "TianLuPlatformAdminBoundaryDeniesIAMWritesOutsideAppNamespace"

    actions = [
      "iam:Create*",
      "iam:Put*",
      "iam:Update*",
      "iam:Delete*",
      "iam:Attach*",
      "iam:Detach*",
      "iam:Tag*",
      "iam:Untag*",
      "iam:PassRole",
    ]

    effect = "Deny"

    not_resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/tianlu-app-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/tianlu-app-*",
    ]
  }

  statement {
    sid = "TianLuPlatformAdminBoundaryDeniesHighRiskActions"

    actions = [
      "iam:DeleteRolePermissionsBoundary",
      "iam:PutRolePermissionsBoundary",
    ]

    effect = "Deny"

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/tianlu-app-*",
    ]
  }
}

