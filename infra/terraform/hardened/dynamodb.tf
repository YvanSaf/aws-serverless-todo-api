# ===========================================================================
# DynamoDB: Tasks table (hardened version)
#
# Fixes applied relative to infra/terraform/vulnerable/dynamodb.tf:
# - encryption at rest with the AWS managed key (aws/dynamodb)
# - point-in-time recovery enabled (35 day rolling window)
# - a userId GSI so the API can Query instead of Scan
# ===========================================================================

resource "aws_dynamodb_table" "tasks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "taskId"

  attribute {
    name = "taskId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  global_secondary_index {
    name            = "userId-index"
    hash_key        = "userId"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = "alias/aws/dynamodb"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${local.name_prefix}-tasks-table"
  }
}
