# ===========================================================================
# Lambda — todo-api monolithic function (vulnerable version)
#
# Intentionally insecure for demonstration purposes:
# - no IMDSv2 enforcement
# - no X-Ray tracing
# - table name passed as environment variable (visible in Lambda config)
# - no reserved concurrency (susceptible to cost abuse)
# ===========================================================================

# Package the Python source code into a ZIP file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../../src/vulnerable/handler.py"
  output_path = "${path.module}/lambda_vulnerable.zip"
}

resource "aws_lambda_function" "todo_api" {
  function_name = "${local.name_prefix}-handler"
  description   = "Vulnerable Todo API — for security demonstration only"
  role          = aws_iam_role.lambda_role.arn
  runtime       = var.lambda_runtime
  handler       = "handler.lambda_handler"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
      # No secrets or credentials here — but the table name is exposed
      # which helps an attacker understand the data model
    }
  }

  # No X-Ray tracing — attacker actions leave minimal traces
  # In the hardened version: tracing_config mode = "Active"

  # No reserved concurrency — 5000 concurrent requests can be triggered
  # leading to unexpected AWS costs
  # In the hardened version: reserved_concurrent_executions = 10

  tags = {
    Name = "${local.name_prefix}-handler"
  }
}

# CloudWatch Log Group for Lambda logs
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.todo_api.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-lambda-logs"
  }
}
