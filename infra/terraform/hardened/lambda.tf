# ===========================================================================
# Lambda: todo-api and authorizer functions (hardened version)
#
# Fixes applied relative to infra/terraform/vulnerable/lambda.tf:
# - X-Ray active tracing enabled on both functions
# - execution roles scoped to least privilege (see iam.tf)
# - a Lambda Authorizer validates every request before it reaches todo_api
#
# Reserved concurrency was intentionally left out: it requires knowing
# how much unreserved concurrency the AWS account has available, which
# varies per account and is often very low on new personal accounts.
# The API Gateway throttle (see api_gateway.tf) is the actual rate
# limiting control for this project.
#
# Only authorizer.py needs PyJWT, and handler.py needs aws-xray-sdk to
# trace the DynamoDB calls it makes. Both functions are packaged from
# the same build directory for simplicity, so the null_resource below
# installs dependencies once and both aws_lambda_function resources
# reuse the resulting zip.
# ===========================================================================

resource "null_resource" "install_dependencies" {
  triggers = {
    requirements = filemd5("${path.module}/../../../src/hardened/requirements.txt")
    handler      = filemd5("${path.module}/../../../src/hardened/handler.py")
    authorizer   = filemd5("${path.module}/../../../src/hardened/authorizer.py")
    validator    = filemd5("${path.module}/../../../src/hardened/validator.py")
  }

  provisioner "local-exec" {
    command = <<-EOT
      rm -rf ${path.module}/build
      mkdir -p ${path.module}/build
      cp ${path.module}/../../../src/hardened/handler.py ${path.module}/build/
      cp ${path.module}/../../../src/hardened/authorizer.py ${path.module}/build/
      cp ${path.module}/../../../src/hardened/validator.py ${path.module}/build/
      pip install -r ${path.module}/../../../src/hardened/requirements.txt -t ${path.module}/build --upgrade --break-system-packages
    EOT
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/build"
  output_path = "${path.module}/lambda_hardened.zip"

  depends_on = [null_resource.install_dependencies]
}

resource "aws_lambda_function" "todo_api" {
  function_name = "${local.name_prefix}-handler"
  description   = "Hardened Todo API, ownership and validation enforced"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.lambda_runtime
  handler       = "handler.lambda_handler"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
    }
  }

  tags = {
    Name = "${local.name_prefix}-handler"
  }
}

resource "aws_lambda_function" "authorizer" {
  function_name = "${local.name_prefix}-authorizer"
  description   = "JWT Lambda Authorizer for the hardened Todo API"
  role          = aws_iam_role.authorizer_exec.arn
  runtime       = var.lambda_runtime
  handler       = "authorizer.lambda_handler"
  timeout       = var.authorizer_timeout
  memory_size   = var.lambda_memory

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      JWT_SECRET = var.jwt_secret
    }
  }

  tags = {
    Name = "${local.name_prefix}-authorizer"
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.todo_api.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-lambda-logs"
  }
}

resource "aws_cloudwatch_log_group" "authorizer_logs" {
  name              = "/aws/lambda/${aws_lambda_function.authorizer.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-authorizer-logs"
  }
}
