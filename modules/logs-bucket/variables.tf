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

# CloudTrail Lifecycle
variable "cloudtrail_enabled" {
  description = "Enable CloudTrail logs lifecycle"
  type        = bool
}

variable "cloudtrail_retention_days" {
  description = "CloudTrail logs retention in days"
  type        = number
}

variable "cloudtrail_transition_to_ia_days" {
  description = "CloudTrail logs transition to IA after days"
  type        = number
}

variable "cloudtrail_transition_to_glacier_days" {
  description = "CloudTrail logs transition to Glacier after days"
  type        = number
}

# VPC Flow Logs Lifecycle
variable "vpc_flow_logs_enabled" {
  description = "Enable VPC Flow Logs lifecycle"
  type        = bool
}

variable "vpc_flow_logs_retention_days" {
  description = "VPC Flow Logs retention in days"
  type        = number
}

variable "vpc_flow_logs_transition_to_ia_days" {
  description = "VPC Flow Logs transition to IA after days"
  type        = number
}

# WAF Logs Lifecycle
variable "waf_enabled" {
  description = "Enable WAF logs lifecycle"
  type        = bool
}

variable "waf_retention_days" {
  description = "WAF logs retention in days"
  type        = number
}

variable "waf_transition_to_ia_days" {
  description = "WAF logs transition to IA after days"
  type        = number
}
