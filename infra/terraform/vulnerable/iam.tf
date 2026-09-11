# ===========================================================================
# IAM — Lambda execution role (vulnerable version)
#
# Intentionally overpermissioned for demonstration purposes:
# - single shared role for the Lambda function
# - dynamodb:* grants full access to the Tasks table
#   which includes Scan, DeleteTable, ExportTableToS3, and more
#
# In the hardened version, the role is restricted to only the five
# DynamoDB actions the application actually needs:
# PutItem, GetItem, UpdateItem, DeleteItem, Query
# ===========================================================================

# Trust policy — allows Lambda service to assume this role
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# IAM Role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = {
    Name = "${local.name_prefix}-lambda-role"
  }
}

# Attach basic Lambda execution policy (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Overpermissive DynamoDB policy — dynamodb:* on the Tasks table
# An attacker who compromises this Lambda can:
# - Scan the entire table (enumerate all users data)
# - DeleteTable (destroy the entire database)
# - ExportTableToS3 (exfiltrate all data to an external bucket)
# - CreateBackup (exfiltrate via backup)
data "aws_iam_policy_document" "dynamodb_policy" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:*"
    ]

    resources = [
      aws_dynamodb_table.tasks.arn
    ]
  }
}

resource "aws_iam_role_policy" "dynamodb_policy" {
  name   = "${local.name_prefix}-dynamodb-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.dynamodb_policy.json
}
