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

variable "subnet_id" {
  description = "Subnet ID for bastion host (should be a public subnet)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
}

variable "volume_size" {
  description = "Size of the root volume in GB"
  type        = number
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for EBS encryption"
  type        = string
}

variable "enable_elastic_ip" {
  description = "Enable Elastic IP for bastion host"
  type        = bool
}
