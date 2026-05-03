variable "project_name" {
  description = "Name of Project"
  type        = string
  default     = "backup-and-recovery"

}

variable "environment" {
  type        = string
  description = "Deployment environment. Must be dev, staging, or prod."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "DR region name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for DR VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs in DR region"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets"
  type        = bool
  default     = false # Cost optimization: disabled by default
}

variable "recovery_ami_ids" {
  description = "Map of instance names to recovery AMI IDs (populated during recovery)"
  type        = map(string)
  default     = {}
}

variable "instance_configs" {
  description = "Instance configurations for DR"
  type = map(object({
    instance_type = string
  }))
  default = {}
}

variable "kms_key_arn" {
  description = "KMS key ARN from the backup module for DR volume encryption/Decryption. Must be in the DR region."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a valid KMS key ARN starting with arn:aws:kms:"
  }
}

variable "my_ip" {
  description = "My ip adress"
  type        = string
}

variable "ssh_access" {
  description = "Enable SSH or Not"
  type        = bool
  default     = false
}

variable "dr_sec_group_config" {
  description = "Security group Configuration"
  type = map(object({
    port        = number
    cidr        = string
    description = string
  }))

  default = {
    http = {
      port        = 80
      cidr        = "0.0.0.0/0"
      description = "HTTP Acess"
    }

    https = {
      port        = 443
      cidr        = "0.0.0.0/0"
      description = "HTTPS Access"
    }
  }
}