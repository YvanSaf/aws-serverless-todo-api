# ===========================================================================
# Outputs — useful information after terraform apply
# ===========================================================================

output "api_endpoint" {
  description = "API Gateway endpoint URL — use this to run attack simulations"
  value       = aws_apigatewayv2_api.todo_api.api_endpoint
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.todo_api.function_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.tasks.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.tasks.arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

# Useful commands printed after terraform apply
output "test_create_task" {
  description = "Command to create a task (no auth required — vulnerability demo)"
  value       = "curl -X POST ${aws_apigatewayv2_api.todo_api.api_endpoint}/tasks -H 'Content-Type: application/json' -d '{\"title\":\"My task\",\"userId\":\"user-123\"}'"
}

output "test_list_all_tasks" {
  description = "Command to list ALL tasks from ALL users (no auth — vulnerability demo)"
  value       = "curl ${aws_apigatewayv2_api.todo_api.api_endpoint}/tasks"
}

output "cloudwatch_logs_url" {
  description = "CloudWatch log group for this Lambda"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.lambda_logs.name, "/", "$252F")}"
}
