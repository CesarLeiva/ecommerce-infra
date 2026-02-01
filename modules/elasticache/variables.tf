variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ElastiCache subnet group"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "List of security group IDs allowed to access Redis"
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
}

variable "num_cache_nodes" {
  description = "Number of cache nodes in the cluster"
  type        = number
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
}

variable "parameter_group_family" {
  description = "ElastiCache parameter group family"
  type        = string
}

variable "parameters" {
  description = "List of parameters for the parameter group"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit"
  type        = bool
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover"
  type        = bool
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ"
  type        = bool
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
}

variable "snapshot_window" {
  description = "Daily time range for snapshots (UTC)"
  type        = string
}

variable "maintenance_window" {
  description = "Weekly time range for maintenance (UTC)"
  type        = string
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
}

variable "apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
}

variable "log_group_name" {
  description = "CloudWatch log group name for Redis logs"
  type        = string
}
