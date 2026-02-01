# ===================================
# SNS Topic for Budget Alerts
# ===================================
resource "aws_sns_topic" "budget_alerts" {
  name              = "${var.prefix}-${var.env}-budget-alerts"
  display_name      = "AWS Budget Alerts for ${var.prefix}-${var.env}"
  kms_master_key_id = var.kms_key_id

  tags = {
    Name        = "${var.prefix}-${var.env}-budget-alerts"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "budget_alerts_email" {
  count     = length(var.alert_emails) > 0 ? length(var.alert_emails) : 0
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

# ===================================
# Overall Budget (All Services)
# ===================================
resource "aws_budgets_budget" "overall" {
  name              = "${var.prefix}-${var.env}-overall-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.overall_monthly_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-02-01_00:00"

  dynamic "notification" {
    for_each = var.alert_thresholds
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.alert_emails
      subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts.arn]
    }
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-overall-budget"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# Database Budget (RDS + ElastiCache)
# ===================================
resource "aws_budgets_budget" "database" {
  name              = "${var.prefix}-${var.env}-database-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.database_monthly_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-02-01_00:00"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Relational Database Service",
      "Amazon ElastiCache"
    ]
  }

  dynamic "notification" {
    for_each = var.alert_thresholds
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.alert_emails
      subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts.arn]
    }
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-database-budget"
    Environment = var.env
    Category    = "Database"
    ManagedBy   = "Terraform"
  }
}

# ===================================
# Compute Budget (ECS + ECR + EC2)
# ===================================
resource "aws_budgets_budget" "compute" {
  name              = "${var.prefix}-${var.env}-compute-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.compute_monthly_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-02-01_00:00"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Elastic Container Service",
      "Amazon EC2 Container Registry (ECR)",
      "Amazon Elastic Compute Cloud - Compute"
    ]
  }

  dynamic "notification" {
    for_each = var.alert_thresholds
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = var.alert_emails
      subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts.arn]
    }
  }
}