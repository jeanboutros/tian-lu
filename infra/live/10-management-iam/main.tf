



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

  statement {
    sid    = "DenyAllExceptBoundary"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteUserPermissionsBoundary",
      "iam:DeleteGroupPermissionsBoundary",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
    ]
    resources = [
      aws_iam_policy.general_app_boundary.arn,
    ]

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

resource "aws_iam_policy" "platform_admin" {
  name   = "platform_admin_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.platform_admin.json
}
