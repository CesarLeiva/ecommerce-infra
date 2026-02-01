# ECR Outputs
output "repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}

# ECS Service Outputs
output "service_id" {
  description = "ID of the ECS service"
  value       = module.ecs_service.service_id
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.service_name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = module.ecs_service.service_arn
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = module.ecs_service.task_definition_arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.ecs_service.target_group_arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group"
  value       = module.ecs_service.target_group_arn_suffix
}

output "security_group_id" {
  description = "ID of the service security group"
  value       = module.ecs_service.security_group_id
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.ecs_service.task_role_arn
}

output "execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = module.ecs_service.task_execution_role_arn
}
