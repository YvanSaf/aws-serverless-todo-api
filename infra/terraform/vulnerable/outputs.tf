# ===========================================================================
# Outputs
# ===========================================================================

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.todo_api.api_endpoint
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.todo_api.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.tasks.name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "test_create_task" {
  description = "Command to create a task"
  value       = "curl -X POST ${aws_apigatewayv2_api.todo_api.api_endpoint}/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Ma premiere tache\",\"userId\":\"user-123\",\"description\":\"Test\"}'"
}

output "test_list_all_tasks" {
  description = "Command to list ALL tasks from ALL users"
  value       = "curl ${aws_apigatewayv2_api.todo_api.api_endpoint}/tasks"
}
