# ===========================================================================
# IAM: Lambda execution role (vulnerable version)
#
# Intentionally overprivileged for demonstration purposes:
# dynamodb:* on the Tasks table instead of the five actions actually needed.
# No permission boundary, no resource level restriction beyond the table.
#
# This role is created directly in this personal AWS account. The hardened
# version documents and implements the least privilege equivalent with only
# PutItem, GetItem, UpdateItem, DeleteItem and Query.
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

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${local.name_prefix}-lambda-role"
  }
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid    = "DynamoDBFullAccessOnTasksTable"
    effect = "Allow"

    actions = [
      "dynamodb:*"
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
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "${local.name_prefix}-lambda-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}
