# ---------------------------------------------------------------------------
# Environment values
# This file is listed in .gitignore — do not commit it
# ---------------------------------------------------------------------------

aws_region   = "us-east-1"
project_name = "yvan-todo-api"
environment  = "dev"
owner        = "yvan-saf"

dynamodb_table_name = "Tasks"

lambda_runtime = "python3.12"
lambda_timeout = 30
lambda_memory  = 128

alert_email        = ""
log_retention_days = 7
