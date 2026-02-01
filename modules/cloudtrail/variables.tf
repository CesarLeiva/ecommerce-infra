variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of S3 bucket for CloudTrail logs"
  type        = string
}

# CloudTrail Configuration
variable "include_global_service_events" {
  description = "Include global service events (e.g., IAM)"
  type        = bool
}

variable "is_multi_region_trail" {
  description = "Enable multi-region trail"
  type        = bool
}

variable "enable_logging" {
  description = "Enable logging for CloudTrail"
  type        = bool
}

variable "enable_log_file_validation" {
  description = "Enable log file validation"
  type        = bool
}

# Event Selectors
variable "enable_s3_data_events" {
  description = "Enable S3 data events logging"
  type        = bool
}

variable "enable_lambda_data_events" {
  description = "Enable Lambda data events logging"
  type        = bool
}

variable "read_write_type" {
  description = "Type of events to log (All, ReadOnly, WriteOnly)"
  type        = string
}

variable "include_management_events" {
  description = "Include management events"
  type        = bool
}

# CloudWatch Logs Integration
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs integration"
  type        = bool
}

variable "cloudwatch_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
}

variable "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN (if using existing)"
  type        = string
  default     = ""
}

variable "cloudwatch_logs_role_arn" {
  description = "CloudWatch Logs Role ARN (if using existing)"
  type        = string
  default     = ""
}
