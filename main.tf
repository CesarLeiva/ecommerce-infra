module "vpc" {
  source = "./modules/vpc"

  prefix                  = var.prefix
  env                     = var.env
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = var.public_subnet_cidrs
  app_subnet_cidrs        = var.app_subnet_cidrs
  data_subnet_cidrs       = var.data_subnet_cidrs
  availability_zones      = var.availability_zones
  enable_nat_gateway      = var.enable_nat_gateway
  enable_flow_logs        = var.enable_vpc_flow_logs
  flow_logs_s3_bucket_arn = module.logs_bucket.bucket_arn
  flow_logs_traffic_type  = var.vpc_flow_logs_traffic_type

  depends_on = [module.logs_bucket]
}

module "acm" {
  source = "./modules/acm"

  prefix                    = var.prefix
  env                       = var.env
  enable_certificate        = var.enable_https
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  route53_zone_id           = var.route53_zone_id
}

# Frontend (S3 + CloudFront)
module "frontend" {
  count  = var.enable_frontend ? 1 : 0
  source = "./modules/frontend"

  prefix              = var.prefix
  env                 = var.env
  domain_name         = var.enable_https ? var.domain_name : ""
  acm_certificate_arn = var.enable_https ? module.acm.certificate_arn : ""
  price_class         = var.frontend_price_class
  waf_web_acl_arn     = var.enable_waf_cloudfront ? module.waf.cloudfront_waf_acl_arn : ""

  depends_on = [module.acm, module.waf]
}

module "alb" {
  source = "./modules/alb"

  prefix                     = var.prefix
  env                        = var.env
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.public_subnet_ids
  enable_deletion_protection = var.alb_enable_deletion_protection
  enable_https               = var.enable_https
  ssl_policy                 = var.alb_ssl_policy
  certificate_arn            = module.acm.certificate_arn
  enable_waf                 = var.enable_waf_alb
  waf_web_acl_arn            = var.enable_waf_alb ? module.waf.alb_waf_acl_arn : ""

  depends_on = [module.acm, module.waf]
}

module "route53" {
  source = "./modules/route53"

  zone_id                  = var.route53_zone_id
  enable_alb_record        = var.enable_https
  alb_subdomain            = "api.${var.domain_name}"
  alb_dns_name             = module.alb.alb_dns_name
  alb_zone_id              = module.alb.alb_zone_id
  enable_cloudfront_record = var.enable_frontend
  cloudfront_domain        = var.domain_name
  cloudfront_dns_name      = var.enable_frontend ? module.frontend[0].cloudfront_domain_name : ""
  cloudfront_zone_id       = var.enable_frontend ? module.frontend[0].cloudfront_hosted_zone_id : ""
}

# ECS Cluster
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  prefix                    = var.prefix
  env                       = var.env
  enable_container_insights = var.enable_container_insights
  log_retention_days        = var.log_retention_days
}

# Compute Services (ECS + ECR)
module "compute" {
  source   = "./modules/compute"
  for_each = var.services

  prefix                    = var.prefix
  env                       = var.env
  service_name              = each.key
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.app_subnet_ids
  cluster_id                = module.ecs_cluster.cluster_id
  cluster_name              = module.ecs_cluster.cluster_name
  alb_security_group_id     = module.alb.alb_security_group_id
  bastion_security_group_id = var.enable_bastion ? module.bastion[0].security_group_id : ""
  listener_arn              = var.enable_https ? module.alb.https_listener_arn : module.alb.http_listener_arn
  listener_rule_priority    = each.value.listener_rule_priority
  path_pattern              = each.value.path_pattern
  container_port            = each.value.container_port
  task_cpu                  = var.task_cpu
  task_memory               = var.task_memory
  ephemeral_storage_size    = var.ephemeral_storage_size
  desired_count             = var.desired_count
  min_capacity              = var.min_capacity
  max_capacity              = var.max_capacity
  cpu_target_value          = var.cpu_target_value
  memory_target_value       = var.memory_target_value
  health_check_path         = each.value.health_check_path
  health_check_matcher      = each.value.health_check_matcher
  environment_variables     = each.value.environment_variables
  image_tag_mutability      = var.image_tag_mutability
  scan_on_push              = var.scan_on_push
  max_image_count           = var.max_image_count
  log_group_name            = module.ecs_cluster.log_group_name
  aws_region                = var.aws_region
  cpu_architecture          = var.cpu_architecture

  depends_on = [module.ecs_cluster, module.alb]
}

# KMS Key for RDS
module "kms" {
  source = "./modules/kms"

  prefix                  = var.prefix
  env                     = var.env
  deletion_window_in_days = var.kms_deletion_window_in_days
}

# Logs Bucket (Centralized S3 bucket for all logs)
module "logs_bucket" {
  source = "./modules/logs-bucket"

  prefix                                = var.prefix
  env                                   = var.env
  kms_key_arn                           = module.kms.kms_key_arn
  cloudtrail_enabled                    = var.cloudtrail_lifecycle_enabled
  cloudtrail_retention_days             = var.cloudtrail_log_retention_days
  cloudtrail_transition_to_ia_days      = var.cloudtrail_transition_to_ia_days
  cloudtrail_transition_to_glacier_days = var.cloudtrail_transition_to_glacier_days
  vpc_flow_logs_enabled                 = var.vpc_flow_logs_lifecycle_enabled
  vpc_flow_logs_retention_days          = var.vpc_flow_logs_retention_days
  vpc_flow_logs_transition_to_ia_days   = var.vpc_flow_logs_transition_to_ia_days
  waf_enabled                           = var.waf_logs_lifecycle_enabled
  waf_retention_days                    = var.waf_log_retention_days
  waf_transition_to_ia_days             = var.waf_transition_to_ia_days

  depends_on = [module.kms]
}

# WAF
module "waf" {
  source = "./modules/waf"

  prefix                        = var.prefix
  env                           = var.env
  enable_cloudfront_waf         = var.enable_waf_cloudfront
  enable_alb_waf                = var.enable_waf_alb
  enable_cloudfront_waf_logging = var.enable_waf_cloudfront_logging
  enable_alb_waf_logging        = var.enable_waf_alb_logging
  s3_bucket_arn                 = module.logs_bucket.bucket_arn

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  depends_on = [module.logs_bucket]
}

# CloudTrail
module "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  source = "./modules/cloudtrail"

  prefix                        = var.prefix
  env                           = var.env
  kms_key_arn                   = module.kms.kms_key_arn
  s3_bucket_name                = module.logs_bucket.bucket_name
  include_global_service_events = var.cloudtrail_include_global_service_events
  is_multi_region_trail         = var.cloudtrail_is_multi_region_trail
  enable_logging                = var.cloudtrail_enable_logging
  enable_log_file_validation    = var.cloudtrail_enable_log_file_validation
  enable_s3_data_events         = var.cloudtrail_enable_s3_data_events
  enable_lambda_data_events     = var.cloudtrail_enable_lambda_data_events
  read_write_type               = var.cloudtrail_read_write_type
  include_management_events     = var.cloudtrail_include_management_events
  enable_cloudwatch_logs        = var.cloudtrail_enable_cloudwatch_logs
  cloudwatch_retention_days     = var.cloudtrail_cloudwatch_retention_days

  depends_on = [module.kms, module.logs_bucket]
}

# Bastion Host
module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "./modules/bastion"

  prefix            = var.prefix
  env               = var.env
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  instance_type     = var.bastion_instance_type
  volume_size       = var.bastion_volume_size
  kms_key_arn       = module.kms.kms_key_arn
  enable_elastic_ip = var.bastion_enable_elastic_ip

  depends_on = [module.vpc, module.kms]
}

# RDS Cluster
module "rds" {
  source = "./modules/rds"

  prefix                       = var.prefix
  env                          = var.env
  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = module.vpc.data_subnet_ids
  allowed_security_groups      = [for service in module.compute : service.security_group_id]
  bastion_security_group_id    = var.enable_bastion ? module.bastion[0].security_group_id : ""
  kms_key_arn                  = module.kms.kms_key_arn
  database_name                = var.rds_database_name
  master_username              = var.rds_master_username
  engine_version               = var.rds_engine_version
  instance_class               = var.rds_instance_class
  parameter_group_family       = var.rds_parameter_group_family
  cluster_parameters           = var.rds_cluster_parameters
  db_parameters                = var.rds_db_parameters
  backup_retention_period      = var.rds_backup_retention_period
  preferred_backup_window      = var.rds_preferred_backup_window
  preferred_maintenance_window = var.rds_preferred_maintenance_window
  skip_final_snapshot          = var.rds_skip_final_snapshot
  deletion_protection          = var.rds_deletion_protection
  enable_reader                = var.rds_enable_reader
  monitoring_interval          = var.rds_monitoring_interval
  enable_performance_insights  = var.rds_enable_performance_insights
  auto_minor_version_upgrade   = var.rds_auto_minor_version_upgrade

  depends_on = [module.kms, module.compute, module.bastion]
}

# Secrets Manager for RDS Credentials
module "secrets" {
  source = "./modules/secrets"

  prefix                  = var.prefix
  env                     = var.env
  recovery_window_in_days = var.secrets_recovery_window_in_days
  kms_key_id              = module.kms.kms_key_id

  # RDS
  db_username = module.rds.master_username
  db_password = module.rds.master_password
  db_engine   = "aurora-postgresql"
  db_host     = module.rds.cluster_endpoint
  db_port     = module.rds.cluster_port
  db_name     = module.rds.database_name
  db_endpoint = module.rds.cluster_endpoint

  # Redis
  redis_primary_endpoint       = var.enable_elasticache ? module.elasticache[0].primary_endpoint_address : ""
  redis_reader_endpoint        = var.enable_elasticache ? module.elasticache[0].reader_endpoint_address : ""
  redis_configuration_endpoint = var.enable_elasticache ? module.elasticache[0].configuration_endpoint_address : ""
  redis_port                   = var.enable_elasticache ? module.elasticache[0].port : 6379
  redis_auth_token             = var.enable_elasticache ? module.elasticache[0].auth_token : ""
  transit_encryption_enabled   = var.elasticache_transit_encryption_enabled
  at_rest_encryption_enabled   = var.elasticache_at_rest_encryption_enabled
  num_cache_nodes              = var.elasticache_num_cache_nodes

  # Bastion
  bastion_instance_id = var.enable_bastion ? module.bastion[0].instance_id : ""
  bastion_private_ip  = var.enable_bastion ? module.bastion[0].private_ip : ""
  bastion_public_ip   = var.enable_bastion ? module.bastion[0].public_ip : ""
  bastion_elastic_ip  = var.enable_bastion ? module.bastion[0].elastic_ip : ""
  bastion_key_name    = var.enable_bastion ? module.bastion[0].key_name : ""
  bastion_private_key = var.enable_bastion ? module.bastion[0].private_key_pem : ""
  bastion_public_key  = var.enable_bastion ? module.bastion[0].public_key_openssh : ""

  depends_on = [module.rds, module.elasticache, module.bastion]
}

# ElastiCache Redis Cluster
module "elasticache" {
  count  = var.enable_elasticache ? 1 : 0
  source = "./modules/elasticache"

  prefix                     = var.prefix
  env                        = var.env
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.data_subnet_ids
  allowed_security_groups    = [for service in module.compute : service.security_group_id]
  node_type                  = var.elasticache_node_type
  num_cache_nodes            = var.elasticache_num_cache_nodes
  engine_version             = var.elasticache_engine_version
  parameter_group_family     = var.elasticache_parameter_group_family
  parameters                 = var.elasticache_parameters
  at_rest_encryption_enabled = var.elasticache_at_rest_encryption_enabled
  transit_encryption_enabled = var.elasticache_transit_encryption_enabled
  automatic_failover_enabled = var.elasticache_automatic_failover_enabled
  multi_az_enabled           = var.elasticache_multi_az_enabled
  snapshot_retention_limit   = var.elasticache_snapshot_retention_limit
  snapshot_window            = var.elasticache_snapshot_window
  maintenance_window         = var.elasticache_maintenance_window
  auto_minor_version_upgrade = var.elasticache_auto_minor_version_upgrade
  apply_immediately          = var.elasticache_apply_immediately
  log_group_name             = module.ecs_cluster.elasticache_log_group_name

  depends_on = [module.ecs_cluster, module.compute]
}

# CloudWatch Alarms
module "cloudwatch_alarms" {
  count  = var.enable_cloudwatch_alarms ? 1 : 0
  source = "./modules/cloudwatch-alarms"

  prefix       = var.prefix
  env          = var.env
  aws_region   = var.aws_region
  kms_key_id   = module.kms.kms_key_id
  alarm_emails = var.alarm_emails

  # ECS Alarms
  ecs_services = {
    for service_name, service_config in var.services : service_name => {
      service_name = module.compute[service_name].service_name
    }
  }
  cluster_name         = module.ecs_cluster.cluster_name
  ecs_cpu_threshold    = var.ecs_cpu_threshold
  ecs_memory_threshold = var.ecs_memory_threshold
  min_running_tasks    = var.min_running_tasks

  # ALB Alarms
  target_groups = {
    for service_name, service_config in var.services : service_name => {
      arn_suffix = module.compute[service_name].target_group_arn_suffix
    }
  }
  alb_arn_suffix                 = module.alb.alb_arn_suffix
  target_response_time_threshold = var.target_response_time_threshold

  # RDS Alarms
  enable_rds_alarms             = true
  rds_cluster_id                = module.rds.cluster_identifier
  has_rds_reader                = var.rds_enable_reader
  rds_cpu_threshold             = var.rds_cpu_threshold
  rds_connections_threshold     = var.rds_connections_threshold
  rds_freeable_memory_threshold = var.rds_freeable_memory_threshold * 1024 * 1024 * 1024 # Convert GB to bytes
  rds_replica_lag_threshold     = var.rds_replica_lag_threshold

  # WAF Alarms
  enable_waf_cloudfront_alarms   = var.enable_waf_cloudfront
  enable_waf_alb_alarms          = var.enable_waf_alb
  waf_cloudfront_web_acl_name    = var.enable_waf_cloudfront ? module.waf.cloudfront_waf_acl_name : ""
  waf_alb_web_acl_name           = var.enable_waf_alb ? module.waf.alb_waf_acl_name : ""
  waf_blocked_requests_threshold = var.waf_blocked_requests_threshold
  waf_block_rate_threshold       = var.waf_block_rate_threshold

  depends_on = [module.kms, module.ecs_cluster, module.compute, module.alb, module.rds, module.waf]
}

# AWS Budgets
module "budgets" {
  count  = var.enable_budgets ? 1 : 0
  source = "./modules/budgets"

  prefix       = var.prefix
  env          = var.env
  kms_key_id   = module.kms.kms_key_id
  alert_emails = var.budget_alert_emails

  overall_monthly_limit  = var.overall_monthly_budget
  database_monthly_limit = var.database_monthly_budget
  compute_monthly_limit  = var.compute_monthly_budget
  storage_monthly_limit  = var.storage_monthly_budget
  alert_thresholds       = var.budget_alert_thresholds

  depends_on = [module.kms]
}

# CI/CD - GitHub Actions OIDC
module "cicd" {
  count  = var.enable_cicd ? 1 : 0
  source = "./modules/cicd"

  prefix              = var.prefix
  env                 = var.env
  github_repositories = var.github_repositories

  # ECR permissions
  ecr_repository_arns = [
    for service_name, service in var.services :
    module.compute[service_name].repository_arn
  ]

  # ECS permissions
  ecs_service_arns = [
    for service_name, service in var.services :
    module.compute[service_name].service_arn
  ]

  ecs_task_role_arns = flatten([
    for service_name, service in var.services : [
      module.compute[service_name].task_role_arn,
      module.compute[service_name].execution_role_arn
    ]
  ])

  # Frontend permissions
  enable_frontend_deploy      = var.enable_frontend
  frontend_bucket_arn         = var.enable_frontend ? module.frontend[0].s3_bucket_arn : ""
  cloudfront_distribution_arn = var.enable_frontend ? module.frontend[0].cloudfront_distribution_arn : ""

  depends_on = [module.compute, module.frontend]
}

