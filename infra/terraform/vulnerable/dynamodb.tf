# ===========================================================================
# DynamoDB — Tasks table (vulnerable version)
#
# Intentionally insecure for demonstration purposes:
# - no encryption at rest
# - no PITR
# - no TTL
# ===========================================================================

resource "aws_dynamodb_table" "tasks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "taskId"

  attribute {
    name = "taskId"
    type = "S"
  }

  tags = {
    Name = "${local.name_prefix}-tasks-table"
  }
}
