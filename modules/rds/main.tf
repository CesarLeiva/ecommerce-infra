# Random password for RDS
resource "random_password" "db_password" {
  length  = 32
  special = true
  lifecycle {
    ignore_changes = [
      length,
      special,
      override_special,
    ]
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.prefix}-${var.env}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.prefix}-${var.env}-db-subnet-group"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.prefix}-${var.env}-rds-sg"
  description = "Security group for RDS PostgreSQL database"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS services"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  # Allow bastion access
  dynamic "ingress" {
    for_each = var.bastion_security_group_id != "" ? [1] : []
    content {
      description     = "PostgreSQL from Bastion"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [var.bastion_security_group_id]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-rds-sg"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# RDS DB Parameter Group
resource "aws_db_parameter_group" "main" {
  name        = "${var.prefix}-${var.env}-db-pg"
  family      = var.parameter_group_family
  description = "DB parameter group for ${var.prefix}-${var.env}"

  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-db-pg"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# RDS Instance - Primary
resource "aws_db_instance" "main" {
  identifier     = "${var.prefix}-${var.env}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn
  iops              = var.storage_type == "io1" || var.storage_type == "io2" ? var.iops : null

  db_name  = var.database_name
  username = var.master_username
  password = random_password.db_password.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  publicly_accessible = false
  multi_az            = var.multi_az

  backup_retention_period      = var.backup_retention_period
  backup_window                = var.preferred_backup_window
  maintenance_window           = var.preferred_maintenance_window
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${var.prefix}-${var.env}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  copy_tags_to_snapshot        = true
  delete_automated_backups     = true
  deletion_protection          = var.deletion_protection
  auto_minor_version_upgrade   = var.auto_minor_version_upgrade
  apply_immediately            = false

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_kms_key_id       = var.enable_performance_insights ? var.kms_key_arn : null
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  tags = {
    Name        = "${var.prefix}-${var.env}-postgres"
    Environment = var.env
    ManagedBy   = "Terraform"
  }

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

# RDS Instance - Read Replica (optional)
resource "aws_db_instance" "replica" {
  count = var.enable_reader ? 1 : 0

  identifier     = "${var.prefix}-${var.env}-postgres-replica"
  replicate_source_db = aws_db_instance.main.identifier

  instance_class    = var.instance_class
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  publicly_accessible        = false
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = false

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_kms_key_id       = var.enable_performance_insights ? var.kms_key_arn : null
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null

  tags = {
    Name        = "${var.prefix}-${var.env}-postgres-replica"
    Role        = "ReadReplica"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.prefix}-${var.env}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-${var.env}-rds-monitoring-role"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
