



data "aws_iam_policy_document" "platform_admin" {
  statement {
    sid = "MintPrincipalsOnlyWithBoundary"

    actions = [
      "iam:CreateUser",
      "iam:CreateRole",
      "iam:CreateGroup",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:PutUserPermissionsBoundary",
      "iam:PutGroupPermissionsBoundary",
      "iam:PutRolePermissionsBoundary",
    ]

    resources = [
      "*",
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values = [
        aws_iam_policy.general_app_boundary.arn,
      ]
    }
  }


  statement {
    sid = "AllowAllOtherNonMutatingActions"
    actions = [
      "iam:Get*",
      "iam:List*",
      "iam:PassRole",
      "iam:Tag*",
      "iam:Attach*",
      "iam:Detach*",
    ]
    resources = [
      "*",
    ]
  }

  # G6 (permissions-boundary evaluation gate): must be added to
  # scripts/preflight-floci.sh to verify Floci actually evaluates boundaries.
  # Implementation deferred to Unit 12.

  # Boundary-attachment ceiling. iam:PermissionsBoundary IS present in the request context
  # for these actions, so StringNotEquals is meaningful: platform-admin may mint principals
  # only when the designated boundary is attached.
  statement {
    sid    = "DenyPrincipalCreationWithoutBoundary"
    effect = "Deny"
    actions = [
      "iam:CreateRole", "iam:CreateUser",
      "iam:PutRolePermissionsBoundary", "iam:PutUserPermissionsBoundary",
    ]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.general_app_boundary.arn]
    }
  }

  # Boundary-removal ceiling. iam:PermissionsBoundary is NOT in the request context for
  # these actions — an inverted operator matches the null value and would deny them
  # unconditionally. Scope by resource, with no condition.
  statement {
    sid    = "DenyBoundaryPolicyMutation"
    effect = "Deny"
    actions = ["iam:DeletePolicy", "iam:DeletePolicyVersion",
    "iam:CreatePolicyVersion", "iam:SetDefaultPolicyVersion"]
    resources = [aws_iam_policy.general_app_boundary.arn]
  }

  statement {
    sid       = "DenyBoundaryDetach"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary", "iam:DeleteUserPermissionsBoundary"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "general_app_boundary" {
  statement {
    sid = "1"

    actions = [
      "rds-db:connect",
      "s3:*",
      "dynamodb:*",
      "glue:*",
      "logs:*",
      "sts:AssumeRole",
    ]

    # An identity policy statement MUST carry a Resource; without it the rendered JSON
    # has no "Resource" key and IAM rejects the document as MalformedPolicyDocument.
    # "*" is correct here: this is a permissions BOUNDARY (a ceiling on what a minted
    # principal may ever do), not a grant — statement "2" below is what narrows it.
    resources = [
      "*",
    ]
  }
  statement {
    sid    = "2"
    effect = "Deny"
    actions = [
      "iam:*",
      "organizations:*",
    ]

    resources = [
      "*",
    ]
  }
}

# The boundary must exist as a real managed policy, not just a rendered document:
# platform_admin's statements above reference its ARN, and a permissions boundary is
# attached to a principal BY ARN. Without this resource the three
# `aws_iam_policy.general_app_boundary.arn` references are undeclared and Terraform
# fails at validate/plan/apply time.
resource "aws_iam_policy" "general_app_boundary" {
  name   = "general_app_boundary"
  path   = "/"
  policy = data.aws_iam_policy_document.general_app_boundary.json
}

resource "aws_iam_policy" "platform_admin" {
  name   = "platform_admin_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.platform_admin.json
}
