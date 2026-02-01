# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-${var.env}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-cluster"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.prefix}-${var.env}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.prefix}-${var.env}-ecs-logs"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Log Group for ElastiCache
resource "aws_cloudwatch_log_group" "elasticache" {
  name              = "/elasticache/${var.prefix}-${var.env}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.prefix}-${var.env}-elasticache-logs"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}
