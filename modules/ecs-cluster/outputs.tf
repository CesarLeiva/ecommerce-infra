output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs.arn
}

output "elasticache_log_group_name" {
  description = "Name of the ElastiCache CloudWatch log group"
  value       = aws_cloudwatch_log_group.elasticache.name
}

output "elasticache_log_group_arn" {
  description = "ARN of the ElastiCache CloudWatch log group"
  value       = aws_cloudwatch_log_group.elasticache.arn
}
