# ===================================
# RDS Secret Outputs
# ===================================
output "rds_secret_id" {
  description = "ID of the RDS secret"
  value       = aws_secretsmanager_secret.rds.id
}

output "rds_secret_arn" {
  description = "ARN of the RDS secret"
  value       = aws_secretsmanager_secret.rds.arn
}

output "rds_secret_name" {
  description = "Name of the RDS secret"
  value       = aws_secretsmanager_secret.rds.name
}

# ===================================
# Redis Secret Outputs
# ===================================
output "redis_secret_id" {
  description = "ID of the Redis secret"
  value       = aws_secretsmanager_secret.redis.id
}

output "redis_secret_arn" {
  description = "ARN of the Redis secret"
  value       = aws_secretsmanager_secret.redis.arn
}

output "redis_secret_name" {
  description = "Name of the Redis secret"
  value       = aws_secretsmanager_secret.redis.name
}

# ===================================
# Bastion Secret Outputs
# ===================================
output "bastion_secret_id" {
  description = "ID of the Bastion secret"
  value       = aws_secretsmanager_secret.bastion.id
}

output "bastion_secret_arn" {
  description = "ARN of the Bastion secret"
  value       = aws_secretsmanager_secret.bastion.arn
}

output "bastion_secret_name" {
  description = "Name of the Bastion secret"
  value       = aws_secretsmanager_secret.bastion.name
}
