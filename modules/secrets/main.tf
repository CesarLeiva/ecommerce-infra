# ===================================
# RDS Database Credentials
# ===================================
resource "aws_secretsmanager_secret" "rds" {
  name                    = "${var.prefix}-${var.env}-rds-credentials"
  description             = "RDS database credentials and connection information"
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = var.kms_key_id

  tags = {
    Name        = "${var.prefix}-${var.env}-rds-credentials"
    Environment = var.env
    Resource    = "RDS"
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = var.db_engine
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
    endpoint = var.db_endpoint
  })
}

# ===================================
# ElastiCache Redis Credentials
# ===================================
resource "aws_secretsmanager_secret" "redis" {
  name                    = "${var.prefix}-${var.env}-redis-credentials"
  description             = "ElastiCache Redis connection information and credentials"
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = var.kms_key_id

  tags = {
    Name        = "${var.prefix}-${var.env}-redis-credentials"
    Environment = var.env
    Resource    = "Redis"
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    engine                 = "redis"
    host                   = var.redis_primary_endpoint != null ? var.redis_primary_endpoint : ""
    reader_endpoint        = var.redis_reader_endpoint != null ? var.redis_reader_endpoint : ""
    configuration_endpoint = var.redis_configuration_endpoint != null ? var.redis_configuration_endpoint : ""
    port                   = tostring(var.redis_port)
    auth_token             = var.redis_auth_token != null ? var.redis_auth_token : ""
    transit_encryption     = tostring(var.transit_encryption_enabled)
    at_rest_encryption     = tostring(var.at_rest_encryption_enabled)
    cluster_enabled        = tostring(var.num_cache_nodes > 1)
  })
}

# ===================================
# Bastion Host Credentials
# ===================================
resource "aws_secretsmanager_secret" "bastion" {
  name                    = "${var.prefix}-${var.env}-bastion-credentials"
  description             = "Bastion host SSH credentials and connection information"
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = var.kms_key_id

  tags = {
    Name        = "${var.prefix}-${var.env}-bastion-credentials"
    Environment = var.env
    Resource    = "Bastion"
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "bastion" {
  secret_id = aws_secretsmanager_secret.bastion.id
  secret_string = jsonencode({
    instance_id = var.bastion_instance_id
    private_ip  = var.bastion_private_ip
    public_ip   = var.bastion_public_ip
    elastic_ip  = var.bastion_elastic_ip != null ? var.bastion_elastic_ip : ""
    key_name    = var.bastion_key_name
    private_key = var.bastion_private_key
    public_key  = var.bastion_public_key
    ssh_user    = "ec2-user"
    ssh_command = var.bastion_elastic_ip != null && var.bastion_elastic_ip != "" ? "ssh -i bastion-key.pem ec2-user@${var.bastion_elastic_ip}" : "ssh -i bastion-key.pem ec2-user@${var.bastion_public_ip}"
  })
}
