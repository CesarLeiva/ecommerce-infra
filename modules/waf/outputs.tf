output "cloudfront_waf_acl_id" {
  description = "ID of the CloudFront WAF Web ACL"
  value       = var.enable_cloudfront_waf ? aws_wafv2_web_acl.cloudfront[0].id : null
}

output "cloudfront_waf_acl_arn" {
  description = "ARN of the CloudFront WAF Web ACL"
  value       = var.enable_cloudfront_waf ? aws_wafv2_web_acl.cloudfront[0].arn : null
}

output "cloudfront_waf_acl_name" {
  description = "Name of the CloudFront WAF Web ACL"
  value       = var.enable_cloudfront_waf ? aws_wafv2_web_acl.cloudfront[0].name : null
}

output "alb_waf_acl_id" {
  description = "ID of the ALB WAF Web ACL"
  value       = var.enable_alb_waf ? aws_wafv2_web_acl.alb[0].id : null
}

output "alb_waf_acl_arn" {
  description = "ARN of the ALB WAF Web ACL"
  value       = var.enable_alb_waf ? aws_wafv2_web_acl.alb[0].arn : null
}

output "alb_waf_acl_name" {
  description = "Name of the ALB WAF Web ACL"
  value       = var.enable_alb_waf ? aws_wafv2_web_acl.alb[0].name : null
}
