variable "zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = null
}

variable "enable_alb_record" {
  description = "Enable ALB DNS record creation"
  type        = bool
}

variable "alb_subdomain" {
  description = "Subdomain for ALB record"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB"
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID of the ALB"
  type        = string
}

variable "enable_cloudfront_record" {
  description = "Enable CloudFront DNS record creation"
  type        = bool
  default     = false
}

variable "cloudfront_domain" {
  description = "Domain name for CloudFront (root domain, e.g., example.com)"
  type        = string
  default     = ""
}

variable "cloudfront_dns_name" {
  description = "DNS name of the CloudFront distribution"
  type        = string
  default     = ""
}

variable "cloudfront_zone_id" {
  description = "Zone ID of the CloudFront distribution"
  type        = string
  default     = ""
}
