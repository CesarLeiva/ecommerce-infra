variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Bastion security group ID"
  type        = string
  default     = ""
}

variable "listener_arn" {
  description = "ALB listener ARN"
  type        = string
}

# ECR Variables
variable "image_tag_mutability" {
  description = "Image tag mutability setting for repository"
  type        = string
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
}

variable "max_image_count" {
  description = "Maximum number of images to retain"
  type        = number
}

# ECS Service Variables
variable "listener_rule_priority" {
  description = "Priority for the listener rule"
  type        = number
}

variable "path_pattern" {
  description = "Path pattern for routing"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "container_image" {
  description = "Container image URL (optional, defaults to ECR repository)"
  type        = string
  default     = ""
}

variable "task_cpu" {
  description = "Task CPU units (1024 = 1 vCPU)"
  type        = number
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = number
}

variable "ephemeral_storage_size" {
  description = "Ephemeral storage size in GiB"
  type        = number
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage"
  type        = number
}

variable "memory_target_value" {
  description = "Target memory utilization percentage"
  type        = number
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
}

variable "health_check_matcher" {
  description = "Health check success codes"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cpu_architecture" {
  description = "CPU architecture (ARM64 or X86_64)"
  type        = string
}
