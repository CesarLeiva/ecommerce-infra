output "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "sns_topic_name" {
  description = "SNS topic name"
  value       = aws_sns_topic.alarms.name
}

output "ecs_cpu_alarm_names" {
  description = "ECS CPU high alarm names"
  value       = { for k, v in aws_cloudwatch_metric_alarm.ecs_cpu_high : k => v.alarm_name }
}

output "ecs_memory_alarm_names" {
  description = "ECS memory high alarm names"
  value       = { for k, v in aws_cloudwatch_metric_alarm.ecs_memory_high : k => v.alarm_name }
}

output "rds_alarm_names" {
  description = "RDS alarm names"
  value = {
    cpu_high         = var.enable_rds_alarms ? aws_cloudwatch_metric_alarm.rds_cpu_high[0].alarm_name : null
    connections_high = var.enable_rds_alarms ? aws_cloudwatch_metric_alarm.rds_connections_high[0].alarm_name : null
    memory_low       = var.enable_rds_alarms ? aws_cloudwatch_metric_alarm.rds_freeable_memory_low[0].alarm_name : null
    replica_lag      = var.enable_rds_alarms && var.has_rds_reader ? aws_cloudwatch_metric_alarm.rds_replica_lag[0].alarm_name : null
  }
}

output "waf_alarm_names" {
  description = "WAF alarm names"
  value = {
    cloudfront_blocked_requests = var.enable_waf_cloudfront_alarms ? aws_cloudwatch_metric_alarm.waf_cloudfront_blocked_requests[0].alarm_name : null
    alb_blocked_requests        = var.enable_waf_alb_alarms ? aws_cloudwatch_metric_alarm.waf_alb_blocked_requests[0].alarm_name : null
    cloudfront_block_rate       = var.enable_waf_cloudfront_alarms ? aws_cloudwatch_metric_alarm.waf_cloudfront_block_rate[0].alarm_name : null
  }
}
