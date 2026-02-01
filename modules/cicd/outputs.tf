output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.name
}

output "ecr_policy_arn" {
  description = "ARN of the ECR access policy"
  value       = aws_iam_policy.ecr_access.arn
}

output "ecs_policy_arn" {
  description = "ARN of the ECS deployment policy"
  value       = aws_iam_policy.ecs_deploy.arn
}

output "s3_policy_arn" {
  description = "ARN of the S3 frontend deployment policy"
  value       = var.enable_frontend_deploy ? aws_iam_policy.s3_frontend[0].arn : ""
}

output "cloudfront_policy_arn" {
  description = "ARN of the CloudFront invalidation policy"
  value       = var.enable_frontend_deploy ? aws_iam_policy.cloudfront_invalidation[0].arn : ""
}
