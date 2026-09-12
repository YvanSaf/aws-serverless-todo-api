# ===========================================================================
# IAM: Lambda execution roles (hardened version)
#
# Two separate roles, each scoped to only what its function needs:
# - lambda_exec (todo_api): PutItem, GetItem, UpdateItem, DeleteItem and
#   Query only, restricted to this table and its GSI. No dynamodb:*,
#   no Scan, unlike infra/terraform/vulnerable/iam.tf.
# - authorizer_exec: no DynamoDB access at all, it only validates a JWT.
# ===========================================================================

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- todo_api role ---------------------------------------------------------

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${local.name_prefix}-lambda-role"
  }
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid    = "DynamoDBLeastPrivilege"
    effect = "Allow"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]

    resources = [
      aws_dynamodb_table.tasks.arn,
      "${aws_dynamodb_table.tasks.arn}/index/*"
    ]
  }

  statement {
    sid    = "LambdaLogging"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:${var.aws_region}:*:*"]
  }

  statement {
    sid    = "XRayTracing"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${local.name_prefix}-lambda-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# --- authorizer role ---------------------------------------------------------

resource "aws_iam_role" "authorizer_exec" {
  name               = "${local.name_prefix}-authorizer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${local.name_prefix}-authorizer-role"
  }
}

data "aws_iam_policy_document" "authorizer_permissions" {
  statement {
    sid    = "LambdaLogging"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:${var.aws_region}:*:*"]
  }

  statement {
    sid    = "XRayTracing"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "authorizer_permissions" {
  name   = "${local.name_prefix}-authorizer-policy"
  role   = aws_iam_role.authorizer_exec.id
  policy = data.aws_iam_policy_document.authorizer_permissions.json
}
