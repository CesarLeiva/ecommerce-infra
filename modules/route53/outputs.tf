output "alb_record_fqdn" {
  description = "FQDN of the ALB DNS record"
  value       = var.enable_alb_record && var.zone_id != null ? aws_route53_record.alb[0].fqdn : null
}

output "alb_record_name" {
  description = "Name of the ALB DNS record"
  value       = var.enable_alb_record && var.zone_id != null ? aws_route53_record.alb[0].name : null
}

output "cloudfront_root_fqdn" {
  description = "FQDN of the CloudFront root domain DNS record"
  value       = var.enable_cloudfront_record && var.zone_id != null ? aws_route53_record.cloudfront_root[0].fqdn : null
}

output "cloudfront_www_fqdn" {
  description = "FQDN of the CloudFront www subdomain DNS record"
  value       = var.enable_cloudfront_record && var.zone_id != null ? aws_route53_record.cloudfront_www[0].fqdn : null
}
