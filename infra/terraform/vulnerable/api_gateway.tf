# ===========================================================================
# API Gateway — HTTP API (vulnerable version)
#
# Intentionally insecure for demonstration purposes:
# - no authentication on any route
# - no throttling (unlimited requests per second)
# - no request validation
# - CORS wide open (all origins allowed)
#
# This means anyone on the internet can call any endpoint
# without identifying themselves, at any volume, with any payload.
# ===========================================================================

resource "aws_apigatewayv2_api" "todo_api" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"
  description   = "Vulnerable Todo API — for security demonstration only"

  # CORS wide open — any origin can call this API
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Name = "${local.name_prefix}-api"
  }
}

# Default stage with auto-deploy
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.todo_api.id
  name        = "$default"
  auto_deploy = true

  # No throttling configured — unlimited requests allowed
  # In the hardened version: default_route_settings with throttling

  # Access logs disabled — no record of who calls the API
  # In the hardened version: access_log_settings enabled

  tags = {
    Name = "${local.name_prefix}-stage"
  }
}

# Lambda integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.todo_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.todo_api.invoke_arn
  payload_format_version = "2.0"
}

# Routes — no authorizer attached to any route
resource "aws_apigatewayv2_route" "create_task" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "POST /tasks"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  # No authorization_type — anyone can create tasks as anyone
}

resource "aws_apigatewayv2_route" "list_tasks" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "GET /tasks"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  # No authorization_type — anyone can list ALL tasks from ALL users
}

resource "aws_apigatewayv2_route" "get_task" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "GET /tasks/{taskId}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  # No authorization_type — anyone can read any task by guessing its ID
}

resource "aws_apigatewayv2_route" "update_task" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "PUT /tasks/{taskId}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  # No authorization_type — anyone can modify any task
}

resource "aws_apigatewayv2_route" "delete_task" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "DELETE /tasks/{taskId}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  # No authorization_type — anyone can delete any task
}

# Permission for API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.todo_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.todo_api.execution_arn}/*/*"
}
