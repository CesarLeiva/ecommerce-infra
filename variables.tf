variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}
variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}
variable "env" {
  description = "Deployment environment (e.g., dev, qa)"
  type        = string
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}
variable "app_subnet_cidrs" {
  description = "CIDR blocks for application subnets"
  type        = list(string)
}
variable "data_subnet_cidrs" {
  description = "CIDR blocks for data subnets"
  type        = list(string)
}
variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
}
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
}

# ALB Variables
variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
}

variable "enable_https" {
  description = "Enable HTTPS for ALB and create ACM certificate"
  type        = bool
}

variable "alb_ssl_policy" {
  description = "SSL policy for ALB HTTPS listener"
  type        = string
}

# Domain and DNS Variables
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "subject_alternative_names" {
  description = "Subject alternative names for ACM certificate"
  type        = list(string)
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

# ECS Cluster Variables
variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS"
  type        = bool
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
}

# ECS Services Variables
variable "services" {
  description = "Map of services to deploy"
  type = map(object({
    listener_rule_priority = number
    path_pattern           = string
    container_port         = number
    health_check_path      = string
    health_check_matcher   = string
    environment_variables = list(object({
      name  = string
      value = string
    }))
  }))
}

# ECR Variables
variable "image_tag_mutability" {
  description = "Image tag mutability setting for ECR repositories"
  type        = string
}

variable "scan_on_push" {
  description = "Enable image scanning on push for ECR"
  type        = bool
}

variable "max_image_count" {
  description = "Maximum number of images to retain in ECR"
  type        = number
}

# ECS Task Variables
variable "task_cpu" {
  description = "Task CPU units (1024 = 1 vCPU)"
  type        = number
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = number
}

variable "ephemeral_storage_size" {
  description = "Ephemeral storage size in GiB"
  type        = number
}

# Auto Scaling Variables
variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
}

variable "min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
}

variable "memory_target_value" {
  description = "Target memory utilization percentage for auto scaling"
  type        = number
}

variable "cpu_architecture" {
  description = "CPU architecture for ECS tasks (ARM64 or X86_64)"
  type        = string
  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "CPU architecture must be either ARM64 or X86_64."
  }
}

# KMS Variables
variable "kms_deletion_window_in_days" {
  description = "KMS key deletion window in days"
  type        = number
}

# RDS Variables
variable "rds_database_name" {
  description = "Name of the database to create"
  type        = string
}

variable "rds_master_username" {
  description = "Master username for RDS"
  type        = string
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "rds_parameter_group_family" {
  description = "RDS parameter group family"
  type        = string
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
}

variable "rds_storage_type" {
  description = "Storage type (gp2, gp3, io1, io2)"
  type        = string
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
}

variable "rds_db_parameters" {
  description = "RDS DB instance parameters"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string)
  }))
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
}

variable "rds_preferred_backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
}

variable "rds_preferred_maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection for RDS"
  type        = bool
}

variable "rds_enable_reader" {
  description = "Enable reader instance"
  type        = bool
}

variable "rds_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds"
  type        = number
}

variable "rds_enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
}

variable "rds_auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
}

# Secrets Manager Variables
variable "secrets_recovery_window_in_days" {
  description = "Recovery window for secrets in days"
  type        = number
}

# ElastiCache Variables
variable "enable_elasticache" {
  description = "Enable ElastiCache Redis cluster"
  type        = bool
}

variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
}

variable "elasticache_num_cache_nodes" {
  description = "Number of cache nodes in the cluster"
  type        = number
}

variable "elasticache_engine_version" {
  description = "Redis engine version"
  type        = string
}

variable "elasticache_parameter_group_family" {
  description = "ElastiCache parameter group family"
  type        = string
}

variable "elasticache_parameters" {
  description = "ElastiCache parameters"
  type = list(object({
    name  = string
    value = string
  }))
}

variable "elasticache_at_rest_encryption_enabled" {
  description = "Enable encryption at rest for ElastiCache"
  type        = bool
}

variable "elasticache_transit_encryption_enabled" {
  description = "Enable encryption in transit for ElastiCache"
  type        = bool
}

variable "elasticache_automatic_failover_enabled" {
  description = "Enable automatic failover for ElastiCache"
  type        = bool
}

variable "elasticache_multi_az_enabled" {
  description = "Enable Multi-AZ for ElastiCache"
  type        = bool
}

variable "elasticache_snapshot_retention_limit" {
  description = "Number of days to retain ElastiCache snapshots"
  type        = number
}

variable "elasticache_snapshot_window" {
  description = "Daily time range for ElastiCache snapshots (UTC)"
  type        = string
}

variable "elasticache_maintenance_window" {
  description = "Weekly time range for ElastiCache maintenance (UTC)"
  type        = string
}

variable "elasticache_auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades for ElastiCache"
  type        = bool
}

variable "elasticache_apply_immediately" {
  description = "Apply changes immediately for ElastiCache"
  type        = bool
}

# Bastion Variables
variable "enable_bastion" {
  description = "Enable bastion host"
  type        = bool
}

variable "bastion_instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
}

variable "bastion_volume_size" {
  description = "Size of the bastion root volume in GB"
  type        = number
}

variable "bastion_enable_elastic_ip" {
  description = "Enable Elastic IP for bastion host"
  type        = bool
}

# Logs Bucket Variables
variable "cloudtrail_lifecycle_enabled" {
  description = "Enable lifecycle rules for CloudTrail logs"
  type        = bool
}

variable "cloudtrail_log_retention_days" {
  description = "Number of days to retain CloudTrail logs in S3"
  type        = number
}

variable "cloudtrail_transition_to_ia_days" {
  description = "Number of days before transitioning logs to Infrequent Access"
  type        = number
}

variable "cloudtrail_transition_to_glacier_days" {
  description = "Number of days before transitioning logs to Glacier"
  type        = number
}

variable "vpc_flow_logs_lifecycle_enabled" {
  description = "Enable lifecycle rules for VPC Flow Logs"
  type        = bool
}

variable "vpc_flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs in S3"
  type        = number
}

variable "vpc_flow_logs_transition_to_ia_days" {
  description = "Number of days before transitioning VPC Flow Logs to Infrequent Access"
  type        = number
}

variable "waf_logs_lifecycle_enabled" {
  description = "Enable lifecycle rules for WAF logs"
  type        = bool
}

variable "waf_log_retention_days" {
  description = "Number of days to retain WAF logs in S3"
  type        = number
}

variable "waf_transition_to_ia_days" {
  description = "Number of days before transitioning WAF logs to Infrequent Access"
  type        = number
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
}

variable "vpc_flow_logs_traffic_type" {
  description = "Type of traffic to log (ACCEPT, REJECT, or ALL)"
  type        = string
}

# CloudTrail Variables
variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
}

variable "cloudtrail_include_global_service_events" {
  description = "Include global service events in CloudTrail"
  type        = bool
}

variable "cloudtrail_is_multi_region_trail" {
  description = "Enable multi-region trail"
  type        = bool
}

variable "cloudtrail_enable_logging" {
  description = "Enable logging for CloudTrail"
  type        = bool
}

variable "cloudtrail_enable_log_file_validation" {
  description = "Enable log file validation"
  type        = bool
}

variable "cloudtrail_enable_s3_data_events" {
  description = "Enable S3 data events logging"
  type        = bool
}

variable "cloudtrail_enable_lambda_data_events" {
  description = "Enable Lambda data events logging"
  type        = bool
}

variable "cloudtrail_read_write_type" {
  description = "Type of events to log (All, ReadOnly, WriteOnly)"
  type        = string
}

variable "cloudtrail_include_management_events" {
  description = "Include management events in CloudTrail"
  type        = bool
}

variable "cloudtrail_enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs integration for CloudTrail"
  type        = bool
}

variable "cloudtrail_cloudwatch_retention_days" {
  description = "CloudWatch Logs retention in days for CloudTrail"
  type        = number
}

# Frontend Variables
variable "enable_frontend" {
  description = "Enable frontend S3 + CloudFront deployment"
  type        = bool
}

variable "frontend_price_class" {
  description = "CloudFront price class"
  type        = string
}

# WAF Variables
variable "enable_waf_cloudfront" {
  description = "Enable WAF for CloudFront"
  type        = bool
}

variable "enable_waf_alb" {
  description = "Enable WAF for ALB"
  type        = bool
}

variable "enable_waf_cloudfront_logging" {
  description = "Enable logging for CloudFront WAF (saves to S3 via Kinesis Firehose)"
  type        = bool
}

variable "enable_waf_alb_logging" {
  description = "Enable logging for ALB WAF (saves to S3 via Kinesis Firehose)"
  type        = bool
}

# CloudWatch Alarms Variables
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
}

variable "alarm_emails" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
}

variable "ecs_cpu_threshold" {
  description = "CPU utilization threshold for ECS alarms (%)"
  type        = number
}

variable "ecs_memory_threshold" {
  description = "Memory utilization threshold for ECS alarms (%)"
  type        = number
}

variable "min_running_tasks" {
  description = "Minimum number of running tasks before triggering alarm"
  type        = number
}

variable "target_response_time_threshold" {
  description = "Target response time threshold in seconds"
  type        = number
}

variable "rds_cpu_threshold" {
  description = "RDS CPU utilization threshold (%)"
  type        = number
}

variable "rds_connections_threshold" {
  description = "RDS database connections threshold"
  type        = number
}

variable "rds_freeable_memory_threshold" {
  description = "RDS freeable memory threshold in GB"
  type        = number
}

variable "rds_replica_lag_threshold" {
  description = "RDS replica lag threshold in milliseconds"
  type        = number
}

variable "waf_blocked_requests_threshold" {
  description = "Threshold for blocked requests count to trigger WAF alarm"
  type        = number
}

variable "waf_block_rate_threshold" {
  description = "Threshold for block rate percentage to trigger WAF alarm"
  type        = number
}

# Budgets Variables
variable "enable_budgets" {
  description = "Enable AWS Budgets for cost monitoring"
  type        = bool
}

variable "budget_alert_emails" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
}

variable "overall_monthly_budget" {
  description = "Monthly budget limit for all services in USD"
  type        = number
}

variable "database_monthly_budget" {
  description = "Monthly budget limit for database services in USD"
  type        = number
}

variable "compute_monthly_budget" {
  description = "Monthly budget limit for compute services in USD"
  type        = number
}

variable "storage_monthly_budget" {
  description = "Monthly budget limit for storage services in USD"
  type        = number
}

variable "budget_alert_thresholds" {
  description = "List of percentage thresholds for budget alerts (e.g., [50, 80, 100, 150, 200])"
  type        = list(number)
}

# ===================================
# CI/CD Configuration
# ===================================
variable "enable_cicd" {
  description = "Enable CI/CD infrastructure for GitHub Actions with OIDC"
  type        = bool
  default     = false
}

variable "github_repositories" {
  description = "List of GitHub repositories allowed to deploy (format: owner/repo)"
  type        = list(string)
  default     = []
}

