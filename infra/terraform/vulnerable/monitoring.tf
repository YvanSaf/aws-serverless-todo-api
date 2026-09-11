# ===========================================================================
# Monitoring — CloudWatch (vulnerable version)
#
# Minimal monitoring — only basic Lambda error alarms.
# There are no alarms on unusual traffic patterns, no API Gateway
# access logs, and no alerts on suspicious activity.
# An attack can run undetected for a long time.
# ===========================================================================

# SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = {
    Name = "${local.name_prefix}-alerts"
  }
}

# Optional email subscription
resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Basic alarm — Lambda errors only
# No alarm on invocation count spikes (cost abuse goes undetected)
# No alarm on API Gateway 4xx (IDOR attempts go undetected)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  alarm_description   = "Lambda function errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.todo_api.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${local.name_prefix}-lambda-errors-alarm"
  }
}
