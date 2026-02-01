output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "app_subnet_ids" {
  description = "IDs of application subnets"
  value       = module.vpc.app_subnet_ids
}

output "data_subnet_ids" {
  description = "IDs of data subnets"
  value       = module.vpc.data_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = module.vpc.nat_gateway_id
}

output "vpn_gateway_id" {
  description = "ID of the Virtual Private Gateway"
  value       = module.vpc.vpn_gateway_id
}

# ALB Outputs
output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = module.alb.alb_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb.alb_security_group_id
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = module.alb.http_listener_arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = module.alb.https_listener_arn
}

# ACM Outputs
output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.acm.certificate_arn
}

output "alb_endpoint" {
  description = "Endpoint URL for the ALB"
  value       = var.enable_https ? "https://api.${var.domain_name}" : "http://${module.alb.alb_dns_name}"
}

# Route53 Outputs
output "alb_record_fqdn" {
  description = "FQDN of the ALB DNS record"
  value       = module.route53.alb_record_fqdn
}

# ECS Cluster Outputs
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

# Services Outputs
output "services" {
  description = "Map of service information"
  value = {
    for service_name, service in module.compute : service_name => {
      repository_url      = service.repository_url
      service_name        = service.service_name
      service_arn         = service.service_arn
      target_group_arn    = service.target_group_arn
      task_definition_arn = service.task_definition_arn
    }
  }
}

# KMS Outputs
output "kms_key_id" {
  description = "KMS key ID for RDS encryption"
  value       = module.kms.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for RDS encryption"
  value       = module.kms.kms_key_arn
}

# Logs Bucket Outputs
output "logs_bucket_id" {
  description = "ID of the centralized logs S3 bucket"
  value       = module.logs_bucket.bucket_id
}

output "logs_bucket_arn" {
  description = "ARN of the centralized logs S3 bucket"
  value       = module.logs_bucket.bucket_arn
}

output "logs_bucket_name" {
  description = "Name of the centralized logs S3 bucket"
  value       = module.logs_bucket.bucket_name
}

# CloudWatch Alarms Outputs
output "alarms_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = var.enable_cloudwatch_alarms ? module.cloudwatch_alarms[0].sns_topic_arn : null
}

output "alarms_sns_topic_name" {
  description = "SNS topic name for CloudWatch alarms"
  value       = var.enable_cloudwatch_alarms ? module.cloudwatch_alarms[0].sns_topic_name : null
}

# Budgets Outputs
output "budget_alerts_sns_topic_arn" {
  description = "SNS topic ARN for budget alerts"
  value       = var.enable_budgets ? module.budgets[0].budget_alerts_sns_topic_arn : null
}

output "budget_alerts_sns_topic_name" {
  description = "SNS topic name for budget alerts"
  value       = var.enable_budgets ? module.budgets[0].budget_alerts_sns_topic_name : null
}

# RDS Outputs
output "rds_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_instance_address" {
  description = "RDS instance address"
  value       = module.rds.db_instance_address
}

output "rds_instance_port" {
  description = "RDS instance port"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.database_name
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.rds.db_instance_id
}

output "rds_replica_endpoint" {
  description = "RDS read replica endpoint (if enabled)"
  value       = module.rds.replica_endpoint
}

# Secrets Manager Outputs
output "secrets_manager_rds_secret_arn" {
  description = "ARN of the RDS credentials secret"
  value       = module.secrets.rds_secret_arn
}

output "secrets_manager_rds_secret_name" {
  description = "Name of the RDS credentials secret"
  value       = module.secrets.rds_secret_name
}

output "secrets_manager_redis_secret_arn" {
  description = "ARN of the Redis credentials secret"
  value       = module.secrets.redis_secret_arn
}

output "secrets_manager_redis_secret_name" {
  description = "Name of the Redis credentials secret"
  value       = module.secrets.redis_secret_name
}

# ElastiCache Outputs
output "elasticache_primary_endpoint" {
  description = "ElastiCache primary endpoint address"
  value       = var.enable_elasticache ? module.elasticache[0].primary_endpoint_address : null
}

output "elasticache_port" {
  description = "ElastiCache port"
  value       = var.enable_elasticache ? module.elasticache[0].port : null
}

output "elasticache_replication_group_id" {
  description = "ElastiCache replication group ID"
  value       = var.enable_elasticache ? module.elasticache[0].replication_group_id : null
}

# Bastion Outputs
output "bastion_instance_id" {
  description = "Bastion instance ID"
  value       = var.enable_bastion ? module.bastion[0].instance_id : null
}

output "bastion_private_ip" {
  description = "Bastion private IP address"
  value       = var.enable_bastion ? module.bastion[0].private_ip : null
}

output "bastion_public_ip" {
  description = "Bastion public IP address"
  value       = var.enable_bastion ? module.bastion[0].public_ip : null
}

output "bastion_elastic_ip" {
  description = "Bastion elastic IP address"
  value       = var.enable_bastion ? module.bastion[0].elastic_ip : null
}

output "bastion_key_name" {
  description = "Bastion SSH key name"
  value       = var.enable_bastion ? module.bastion[0].key_name : null
}

output "secrets_manager_bastion_secret_arn" {
  description = "ARN of the Bastion credentials secret"
  value       = module.secrets.bastion_secret_arn
}

output "secrets_manager_bastion_secret_name" {
  description = "Name of the Bastion credentials secret"
  value       = module.secrets.bastion_secret_name
}

# CloudTrail Outputs
output "cloudtrail_id" {
  description = "CloudTrail ID"
  value       = var.enable_cloudtrail ? module.cloudtrail[0].cloudtrail_id : null
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = var.enable_cloudtrail ? module.cloudtrail[0].cloudtrail_arn : null
}

output "cloudtrail_s3_bucket" {
  description = "CloudTrail S3 bucket name"
  value       = var.enable_cloudtrail ? module.cloudtrail[0].s3_bucket_name : null
}

# Frontend Outputs
output "frontend_s3_bucket" {
  description = "Frontend S3 bucket name"
  value       = var.enable_frontend ? module.frontend[0].s3_bucket_name : null
}

output "frontend_cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.enable_frontend ? module.frontend[0].cloudfront_distribution_id : null
}

output "frontend_cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.enable_frontend ? module.frontend[0].cloudfront_domain_name : null
}

output "frontend_url" {
  description = "Frontend URL"
  value       = var.enable_frontend ? (var.domain_name != "" ? "https://${var.domain_name}" : "https://${module.frontend[0].cloudfront_domain_name}") : null
}

# WAF Outputs
output "waf_cloudfront_acl_arn" {
  description = "CloudFront WAF Web ACL ARN"
  value       = var.enable_waf_cloudfront ? module.waf.cloudfront_waf_acl_arn : null
}

output "waf_alb_acl_arn" {
  description = "ALB WAF Web ACL ARN"
  value       = var.enable_waf_alb ? module.waf.alb_waf_acl_arn : null
}

# ===================================
# CI/CD Outputs
# ===================================
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions (use in workflows with role-to-assume)"
  value       = var.enable_cicd ? module.cicd[0].github_actions_role_arn : ""
}

output "github_actions_role_name" {
  description = "Name of the IAM role for GitHub Actions"
  value       = var.enable_cicd ? module.cicd[0].github_actions_role_name : ""
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = var.enable_cicd ? module.cicd[0].oidc_provider_arn : ""
}

