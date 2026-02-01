variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "recovery_window_in_days" {
  description = "Number of days to retain secret after deletion"
  type        = number
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting secrets"
  type        = string
  default     = null
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_engine" {
  description = "Database engine"
  type        = string
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_endpoint" {
  description = "Database endpoint"
  type        = string
}

# Redis Variables
variable "redis_primary_endpoint" {
  description = "Redis primary endpoint"
  type        = string
  default     = ""
}

variable "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  type        = string
  default     = ""
}

variable "redis_configuration_endpoint" {
  description = "Redis configuration endpoint"
  type        = string
  default     = ""
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_auth_token" {
  description = "Redis AUTH token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "transit_encryption_enabled" {
  description = "Whether transit encryption is enabled for Redis"
  type        = bool
  default     = false
}

variable "at_rest_encryption_enabled" {
  description = "Whether at-rest encryption is enabled for Redis"
  type        = bool
  default     = false
}

variable "num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

# Bastion Variables
variable "bastion_instance_id" {
  description = "Bastion instance ID"
  type        = string
  default     = ""
}

variable "bastion_private_ip" {
  description = "Bastion private IP address"
  type        = string
  default     = ""
}

variable "bastion_public_ip" {
  description = "Bastion public IP address"
  type        = string
  default     = ""
}

variable "bastion_elastic_ip" {
  description = "Bastion elastic IP address"
  type        = string
  default     = ""
}

variable "bastion_key_name" {
  description = "Bastion SSH key name"
  type        = string
  default     = ""
}

variable "bastion_private_key" {
  description = "Bastion SSH private key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "bastion_public_key" {
  description = "Bastion SSH public key"
  type        = string
  default     = ""
}
