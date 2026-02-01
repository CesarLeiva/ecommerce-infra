variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for SNS topic encryption"
  type        = string
}

variable "alarm_emails" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

# ECS Variables
variable "ecs_services" {
  description = "Map of ECS services with their names"
  type = map(object({
    service_name = string
  }))
  default = {}
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = ""
}

variable "ecs_cpu_threshold" {
  description = "CPU utilization threshold for ECS alarms (%)"
  type        = number
  default     = 80
}

variable "ecs_memory_threshold" {
  description = "Memory utilization threshold for ECS alarms (%)"
  type        = number
  default     = 80
}

variable "min_running_tasks" {
  description = "Minimum number of running tasks before triggering alarm"
  type        = number
  default     = 1
}

# ALB Variables
variable "target_groups" {
  description = "Map of target groups with their ARN suffixes"
  type = map(object({
    arn_suffix = string
  }))
  default = {}
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix"
  type        = string
  default     = ""
}

variable "target_response_time_threshold" {
  description = "Target response time threshold in seconds"
  type        = number
  default     = 2
}

# RDS Variables
variable "enable_rds_alarms" {
  description = "Enable RDS CloudWatch alarms"
  type        = bool
  default     = false
}

variable "rds_cluster_id" {
  description = "RDS cluster identifier"
  type        = string
  default     = ""
}

variable "has_rds_reader" {
  description = "Whether RDS has a reader instance"
  type        = bool
  default     = false
}

variable "rds_cpu_threshold" {
  description = "RDS CPU utilization threshold (%)"
  type        = number
  default     = 80
}

variable "rds_connections_threshold" {
  description = "RDS database connections threshold"
  type        = number
  default     = 80
}

variable "rds_freeable_memory_threshold" {
  description = "RDS freeable memory threshold in bytes (default: 1GB)"
  type        = number
  default     = 1073741824
}

variable "rds_replica_lag_threshold" {
  description = "RDS replica lag threshold in milliseconds"
  type        = number
  default     = 1000
}

# WAF Variables
variable "enable_waf_cloudfront_alarms" {
  description = "Enable CloudFront WAF alarms"
  type        = bool
  default     = false
}

variable "enable_waf_alb_alarms" {
  description = "Enable ALB WAF alarms"
  type        = bool
  default     = false
}

variable "waf_cloudfront_web_acl_name" {
  description = "CloudFront WAF Web ACL name"
  type        = string
  default     = ""
}

variable "waf_alb_web_acl_name" {
  description = "ALB WAF Web ACL name"
  type        = string
  default     = ""
}

variable "waf_blocked_requests_threshold" {
  description = "Threshold for blocked requests count to trigger alarm"
  type        = number
  default     = 1000
}

variable "waf_block_rate_threshold" {
  description = "Threshold for block rate percentage to trigger alarm"
  type        = number
  default     = 50
}
