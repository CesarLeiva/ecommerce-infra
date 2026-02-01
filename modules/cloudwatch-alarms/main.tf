# ===================================
# SNS Topic for Alarms
# ===================================
resource "aws_sns_topic" "alarms" {
  name              = "${var.prefix}-${var.env}-alarms"
  display_name      = "CloudWatch Alarms for ${var.prefix}-${var.env}"
  kms_master_key_id = var.kms_key_id

  tags = {
    Name        = "${var.prefix}-${var.env}-alarms"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count     = length(var.alarm_emails) > 0 ? length(var.alarm_emails) : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_emails[count.index]
}

# ===================================
# ECS Service Alarms
# ===================================
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = var.ecs_services

  alarm_name          = "${var.prefix}-${var.env}-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.ecs_cpu_threshold
  alarm_description   = "ECS service ${each.key} CPU utilization is above ${var.ecs_cpu_threshold}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = each.value.service_name
    ClusterName = var.cluster_name
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-${each.key}-cpu-high"
    Environment = var.env
    Service     = each.key
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  for_each = var.ecs_services

  alarm_name          = "${var.prefix}-${var.env}-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.ecs_memory_threshold
  alarm_description   = "ECS service ${each.key} memory utilization is above ${var.ecs_memory_threshold}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ServiceName = each.value.service_name
    ClusterName = var.cluster_name
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-${each.key}-memory-high"
    Environment = var.env
    Service     = each.key
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks_low" {
  for_each = var.ecs_services

  alarm_name          = "${var.prefix}-${var.env}-${each.key}-running-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.min_running_tasks
  alarm_description   = "ECS service ${each.key} has less than ${var.min_running_tasks} running tasks"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = each.value.service_name
    ClusterName = var.cluster_name
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-${each.key}-running-tasks-low"
    Environment = var.env
    Service     = each.key
    ManagedBy   = "Terraform"
  }
}

# ===================================
# ALB Target Health Alarms
# ===================================
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  for_each = var.target_groups

  alarm_name          = "${var.prefix}-${var.env}-${each.key}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "ALB target group ${each.key} has unhealthy targets"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = each.value.arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-${each.key}-unhealthy-targets"
    Environment = var.env
    Service     = each.key
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  for_each = var.target_groups

  alarm_name          = "${var.prefix}-${var.env}-${each.key}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.target_response_time_threshold
  alarm_description   = "ALB target group ${each.key} response time is above ${var.target_response_time_threshold} seconds"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = each.value.arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-${each.key}-high-response-time"
    Environment = var.env
    Service     = each.key
    ManagedBy   = "Terraform"
  }
}

# ===================================
# RDS Alarms
# ===================================
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.prefix}-${var.env}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold
  alarm_description   = "RDS instance CPU utilization is above ${var.rds_cpu_threshold}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_cluster_id
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-rds-cpu-high"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  count = var.enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.prefix}-${var.env}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_connections_threshold
  alarm_description   = "RDS instance has more than ${var.rds_connections_threshold} database connections"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_cluster_id
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-rds-connections-high"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory_low" {
  count = var.enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.prefix}-${var.env}-rds-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_freeable_memory_threshold
  alarm_description   = "RDS instance freeable memory is below ${var.rds_freeable_memory_threshold / 1024 / 1024 / 1024} GB"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_cluster_id
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-rds-memory-low"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_replica_lag" {
  count = var.enable_rds_alarms && var.has_rds_reader ? 1 : 0

  alarm_name          = "${var.prefix}-${var.env}-rds-replica-lag-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReplicaLag"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_replica_lag_threshold
  alarm_description   = "RDS replica lag is above ${var.rds_replica_lag_threshold} seconds"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_cluster_id
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-rds-replica-lag-high"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# WAF Alarms (Attack Detection)
# ===================================
resource "aws_cloudwatch_metric_alarm" "waf_cloudfront_blocked_requests" {
  count = var.enable_waf_cloudfront_alarms ? 1 : 0

  alarm_name          = "${var.prefix}-${var.env}-waf-cloudfront-blocked-requests-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = var.waf_blocked_requests_threshold
  alarm_description   = "CloudFront WAF is blocking more than ${var.waf_blocked_requests_threshold} requests (possible attack)"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = var.waf_cloudfront_web_acl_name
    Region = "us-east-1"
    Rule   = "ALL"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-waf-cloudfront-blocked-requests-high"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "waf_alb_blocked_requests" {
  count = var.enable_waf_alb_alarms ? 1 : 0

  alarm_name          = "${var.prefix}-${var.env}-waf-alb-blocked-requests-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = var.waf_blocked_requests_threshold
  alarm_description   = "ALB WAF is blocking more than ${var.waf_blocked_requests_threshold} requests (possible attack)"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = var.waf_alb_web_acl_name
    Region = var.aws_region
    Rule   = "ALL"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-waf-alb-blocked-requests-high"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "waf_cloudfront_block_rate" {
  count = var.enable_waf_cloudfront_alarms ? 1 : 0

  alarm_name          = "${var.prefix}-${var.env}-waf-cloudfront-block-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.waf_block_rate_threshold
  alarm_description   = "CloudFront WAF block rate is above ${var.waf_block_rate_threshold}% (possible attack)"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "block_rate"
    expression  = "(blocked / allowed) * 100"
    label       = "Block Rate Percentage"
    return_data = true
  }

  metric_query {
    id = "blocked"
    metric {
      metric_name = "BlockedRequests"
      namespace   = "AWS/WAFV2"
      period      = 300
      stat        = "Sum"
      dimensions = {
        WebACL = var.waf_cloudfront_web_acl_name
        Region = "us-east-1"
        Rule   = "ALL"
      }
    }
  }

  metric_query {
    id = "allowed"
    metric {
      metric_name = "AllowedRequests"
      namespace   = "AWS/WAFV2"
      period      = 300
      stat        = "Sum"
      dimensions = {
        WebACL = var.waf_cloudfront_web_acl_name
        Region = "us-east-1"
        Rule   = "ALL"
      }
    }
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-waf-cloudfront-block-rate-high"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}
