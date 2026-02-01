# KMS Key for RDS Encryption
resource "aws_kms_key" "rds" {
  description             = "${var.prefix}-${var.env}-rds-encryption-key"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  tags = {
    Name        = "${var.prefix}-${var.env}-rds-kms"
    Environment = var.env
    ManagedBy   = "Terraform"
    Purpose     = "RDS Encryption"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.prefix}-${var.env}-rds"
  target_key_id = aws_kms_key.rds.key_id
}
