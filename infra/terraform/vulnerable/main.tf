terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local backend — state stays on the machine running Terraform.
  # On a full-permission AWS account, replace this with an S3 backend
  # and a DynamoDB table for state locking.
  backend "local" {}
}

provider "aws" {
  region = var.aws_region

  # Pass credentials through environment variables only — never hardcode them:
  # export AWS_ACCESS_KEY_ID="..."
  # export AWS_SECRET_ACCESS_KEY="..."
  # export AWS_SESSION_TOKEN="..."

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Version     = "vulnerable"
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }

  name_prefix = "${var.project_name}-${var.environment}-vuln"
}
