variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for SNS topic encryption"
  type        = string
}

variable "alert_emails" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
  default     = []
}

variable "overall_monthly_limit" {
  description = "Monthly budget limit for all services in USD"
  type        = number
}

variable "database_monthly_limit" {
  description = "Monthly budget limit for database services (RDS + ElastiCache) in USD"
  type        = number
}

variable "compute_monthly_limit" {
  description = "Monthly budget limit for compute services (ECS + ECR + EC2) in USD"
  type        = number
}

variable "storage_monthly_limit" {
  description = "Monthly budget limit for storage services (S3 + CloudFront) in USD"
  type        = number
}

variable "alert_thresholds" {
  description = "List of percentage thresholds for budget alerts"
  type        = list(number)
  default     = [50, 80, 100, 150, 200]
}
