# General Configuration
aws_region = "us-east-1"
prefix     = "ecommerce"
env        = "qa"

# VPC Configuration
vpc_cidr            = "192.168.0.0/16"
public_subnet_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]
app_subnet_cidrs    = ["192.168.2.0/24", "192.168.3.0/24"]
data_subnet_cidrs   = ["192.168.4.0/24", "192.168.5.0/24"]
availability_zones  = ["us-east-1a", "us-east-1b"]
enable_nat_gateway  = true

# VPC Flow Logs Configuration
enable_vpc_flow_logs                = false
vpc_flow_logs_traffic_type          = "ALL" # ACCEPT, REJECT, or ALL
vpc_flow_logs_lifecycle_enabled     = true
vpc_flow_logs_retention_days        = 90 # 90 days
vpc_flow_logs_transition_to_ia_days = 30 # Move to IA after 30 days

# ALB Configuration
alb_enable_deletion_protection = false
enable_https                   = false
alb_ssl_policy                 = "ELBSecurityPolicy-TLS13-1-2-2021-06"

# Domain and DNS Configuration
domain_name               = "example.com"     # Cambiar por el dominio real
subject_alternative_names = ["*.example.com"] # Cambiar por los SANs reales
route53_zone_id           = null # Cambiar si se usa una zona hospedada existente

# ECS Cluster Configuration
enable_container_insights = true
log_retention_days        = 7

# ECR Configuration
image_tag_mutability = "MUTABLE"
scan_on_push         = true
max_image_count      = 10

# ECS Task Configuration
task_cpu               = 1024    # 1 vCPU
task_memory            = 2048    # 2 GB
ephemeral_storage_size = 21      # 21 GB (minimum allowed)
cpu_architecture       = "ARM64" # ARM64 (Graviton2) or X86

# Auto Scaling Configuration
desired_count       = 2
min_capacity        = 2
max_capacity        = 4
cpu_target_value    = 70.0 # Target CPU utilization percentage for scaling
memory_target_value = 70.0 # Target Memory utilization percentage for scaling

# Services Configuration
services = {
  api = {
    listener_rule_priority = 100
    path_pattern           = "/api/*"
    container_port         = 3000
    health_check_path      = "/api/health"
    health_check_matcher   = "200"
    environment_variables = [
      {
        name  = "NODE_ENV"
        value = "qa"
      },
      {
        name  = "PORT"
        value = "3000"
      }
    ]
  }
  # Se pueden configurar más servicios aquí
}

# KMS Configuration
kms_deletion_window_in_days = 30

# RDS Configuration
rds_database_name                = "ecommerce"
rds_master_username              = "postgres"
rds_engine_version               = "15.8"
rds_instance_class               = "db.r6g.large" # ARM-based Graviton2 (db.r6g) para ARM64 - 2 vCPU, 16 GiB RAM o X86 based (db.m5.large) - 2 vCPU, 8 GiB RAM
rds_parameter_group_family       = "aurora-postgresql15"
rds_cluster_parameters           = []
rds_db_parameters                = []
rds_backup_retention_period      = 7
rds_preferred_backup_window      = "03:00-04:00" # Weekly backup at 3 AM UTC
rds_preferred_maintenance_window = "sun:04:00-sun:05:00"
rds_skip_final_snapshot          = false # Habilitar en producción
rds_deletion_protection          = false # Habilitar en producción
rds_enable_reader                = false # Habilitar réplica de lectura
rds_monitoring_interval          = 60
rds_enable_performance_insights  = true
rds_auto_minor_version_upgrade   = true

# Secrets Manager Configuration
secrets_recovery_window_in_days = 7

# ElastiCache Configuration
enable_elasticache                     = true
elasticache_node_type                  = "cache.t3.medium"
elasticache_num_cache_nodes            = 1 # Aumentar a 2 o más para multi-node y alta disponibilidad
elasticache_engine_version             = "7.0"
elasticache_parameter_group_family     = "redis7"
elasticache_parameters                 = []
elasticache_at_rest_encryption_enabled = true
elasticache_transit_encryption_enabled = false
elasticache_automatic_failover_enabled = false # Solo con multi-node
elasticache_multi_az_enabled           = false # Solo con multi-node
elasticache_snapshot_retention_limit   = 5 # Número de snapshots a retener - Días de duración de c/u
elasticache_snapshot_window            = "05:00-06:00"
elasticache_maintenance_window         = "sun:06:00-sun:07:00"
elasticache_auto_minor_version_upgrade = true
elasticache_apply_immediately          = false # Aplicar cambios durante la ventana de mantenimiento

# Bastion Configuration
enable_bastion            = true
bastion_instance_type     = "t3.micro"
bastion_volume_size       = 20
bastion_enable_elastic_ip = false

# CloudTrail Configuration
enable_cloudtrail                        = false # Guardar los logs en S3
cloudtrail_lifecycle_enabled             = true
cloudtrail_log_retention_days            = 365 # 1 year
cloudtrail_transition_to_ia_days         = 90  # Move to IA after 90 days
cloudtrail_transition_to_glacier_days    = 180 # Move to Glacier after 180 days
cloudtrail_include_global_service_events = true
cloudtrail_is_multi_region_trail         = true
cloudtrail_enable_logging                = true
cloudtrail_enable_log_file_validation    = true
cloudtrail_enable_s3_data_events         = false # Activar sólo si se va a auditar S3 y sus eventos - $$$
cloudtrail_enable_lambda_data_events     = false # Activar sólo si se va a auditar Lambda y sus eventos - $$$
cloudtrail_read_write_type               = "All" # All, ReadOnly, WriteOnly
cloudtrail_include_management_events     = true
cloudtrail_enable_cloudwatch_logs        = false # Opcional, activar si se necesitan consultas en CloudWatch Insights
cloudtrail_cloudwatch_retention_days     = 30

# Frontend Configuration
enable_frontend      = true
frontend_price_class = "PriceClass_100" # PriceClass_100 (USA, Europa), PriceClass_200 (+Asia, África), PriceClass_All (Global)

# WAF Configuration
enable_waf_cloudfront         = true
enable_waf_alb                = true
enable_waf_cloudfront_logging = false # Activar para guardar logs en S3 (vía Kinesis Firehose)
enable_waf_alb_logging        = false # Activar para guardar logs en S3 (vía Kinesis Firehose)
waf_logs_lifecycle_enabled    = true
waf_log_retention_days        = 90 # 90 days
waf_transition_to_ia_days     = 30 # Move to IA after 30 days

# CloudWatch Alarms Configuration
enable_cloudwatch_alarms = true
alarm_emails             = ["cesaleacu@gmail.com"]

# ECS Alarms Thresholds
ecs_cpu_threshold              = 80 # CPU utilization % threshold
ecs_memory_threshold           = 80 # Memory utilization % threshold
min_running_tasks              = 2  # Minimum running tasks before alert
target_response_time_threshold = 5  # Seconds

# RDS Alarms Thresholds
rds_cpu_threshold             = 80   # CPU utilization % threshold
rds_connections_threshold     = 80   # Database connections threshold
rds_freeable_memory_threshold = 2    # GB of freeable memory threshold
rds_replica_lag_threshold     = 1000 # Milliseconds - Con réplica de lectura activa

# WAF Alarms Thresholds (Attack Detection)
waf_blocked_requests_threshold = 1000 # Blocked requests count in 5 minutes
waf_block_rate_threshold       = 50   # Block rate percentage

# AWS Budgets Configuration
enable_budgets          = true
budget_alert_emails     = ["cesaleacu@gmail.com"]
overall_monthly_budget  = 850
database_monthly_budget = 510 # On demand cost with reader enabled
compute_monthly_budget  = 80
storage_monthly_budget  = 40
budget_alert_thresholds = [50, 80, 100, 150, 200] # Porcentajes de alertas

# ===================================
# CI/CD Configuration
# ===================================
enable_cicd         = false
github_repositories = ["ecommerce-backend-repo", "ecommerce-frontend-repo"] # Cambiar por los repositorios (ver documentación de CICD_SETUP.md)
