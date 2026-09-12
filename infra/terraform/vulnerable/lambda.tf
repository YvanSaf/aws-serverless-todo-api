# ===========================================================================
# Lambda: todo-api monolithic function (vulnerable version)
#
# Intentionally insecure for demonstration purposes:
# - no X-Ray tracing
# - no reserved concurrency
# - table name exposed in environment variables
# - execution role with dynamodb:* (see iam.tf)
# ===========================================================================

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../../src/vulnerable/handler.py"
  output_path = "${path.module}/lambda_vulnerable.zip"
}

resource "aws_lambda_function" "todo_api" {
  function_name = "${local.name_prefix}-handler"
  description   = "Vulnerable Todo API, for security demonstration only"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.lambda_runtime
  handler       = "handler.lambda_handler"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
    }
  }

  tags = {
    Name = "${local.name_prefix}-handler"
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.todo_api.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-lambda-logs"
  }
}
