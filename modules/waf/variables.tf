variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "enable_cloudfront_waf" {
  description = "Enable WAF for CloudFront"
  type        = bool
}

variable "enable_alb_waf" {
  description = "Enable WAF for ALB"
  type        = bool
}

variable "enable_cloudfront_waf_logging" {
  description = "Enable logging for CloudFront WAF"
  type        = bool
  default     = false
}

variable "enable_alb_waf_logging" {
  description = "Enable logging for ALB WAF"
  type        = bool
  default     = false
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for WAF logs"
  type        = string
  default     = ""
}
