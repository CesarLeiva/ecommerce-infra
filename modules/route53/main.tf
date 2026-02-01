# Route53 Record for ALB (A Record)
resource "aws_route53_record" "alb" {
  count = var.enable_alb_record && var.zone_id != null ? 1 : 0

  zone_id = var.zone_id
  name    = var.alb_subdomain
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Route53 Record for CloudFront - Root Domain (A Record)
resource "aws_route53_record" "cloudfront_root" {
  count = var.enable_cloudfront_record && var.zone_id != null && var.cloudfront_domain != "" ? 1 : 0

  zone_id = var.zone_id
  name    = var.cloudfront_domain
  type    = "A"

  alias {
    name                   = var.cloudfront_dns_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# Route53 Record for CloudFront - WWW Subdomain (A Record)
resource "aws_route53_record" "cloudfront_www" {
  count = var.enable_cloudfront_record && var.zone_id != null && var.cloudfront_domain != "" ? 1 : 0

  zone_id = var.zone_id
  name    = "www.${var.cloudfront_domain}"
  type    = "A"

  alias {
    name                   = var.cloudfront_dns_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}
