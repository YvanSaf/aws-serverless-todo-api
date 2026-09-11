# ===========================================================================
# DynamoDB — Tasks table (vulnerable version)
#
# Intentionally insecure for demonstration purposes:
# - no encryption at rest
# - no PITR (Point-in-Time Recovery)
# - no TTL configured
# - table structure allows Scan operations (no enforced access pattern)
#
# This version exists to demonstrate what happens when a DynamoDB table
# is deployed without security controls. See the hardened version for
# the corrected implementation.
# ===========================================================================

resource "aws_dynamodb_table" "tasks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "taskId"

  attribute {
    name = "taskId"
    type = "S"
  }

  # No encryption — data stored in plaintext on disk
  # In the hardened version: server_side_encryption enabled with KMS

  # No PITR — no point-in-time recovery
  # In the hardened version: point_in_time_recovery enabled

  # No TTL — items never expire automatically
  # In the hardened version: ttl block enabled on expiresAt attribute

  tags = {
    Name = "${local.name_prefix}-tasks-table"
  }
}
