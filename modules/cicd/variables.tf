variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "github_repositories" {
  description = "List of GitHub repositories allowed to assume the role (format: owner/repo)"
  type        = list(string)
  default     = []
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs that GitHub Actions can push to"
  type        = list(string)
  default     = []
}

variable "ecs_service_arns" {
  description = "List of ECS service ARNs that GitHub Actions can update"
  type        = list(string)
  default     = []
}

variable "ecs_task_role_arns" {
  description = "List of ECS task/execution role ARNs that GitHub Actions can pass"
  type        = list(string)
  default     = []
}

variable "enable_frontend_deploy" {
  description = "Enable frontend deployment permissions (S3 + CloudFront)"
  type        = bool
  default     = false
}

variable "frontend_bucket_arn" {
  description = "ARN of the S3 bucket for frontend deployment"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution for cache invalidation"
  type        = string
  default     = ""
}
