output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = var.enable_certificate ? aws_acm_certificate.main[0].arn : null
}

output "certificate_id" {
  description = "ID of the ACM certificate"
  value       = var.enable_certificate ? aws_acm_certificate.main[0].id : null
}

output "certificate_domain_name" {
  description = "Domain name of the ACM certificate"
  value       = var.enable_certificate ? aws_acm_certificate.main[0].domain_name : null
}

output "certificate_status" {
  description = "Status of the ACM certificate"
  value       = var.enable_certificate ? aws_acm_certificate.main[0].status : null
}
