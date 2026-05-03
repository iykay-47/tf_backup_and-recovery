variable "project_name" {
  description = "Name of Project"
  type        = string
  default     = "backup-and-recovery"
}

variable "vpc_id" {
  description = "VPC ID for EC2 instances. If not provided, the default VPC is used."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of subnet IDs for multi-AZ deployment. If not provided, default VPC subnets are used."
  type        = list(string)
  default     = null
}

variable "instance_configs" {
  description = "Map of instance configurations"
  type = map(object({
    instance_type = string
    backup_policy = string
    public_ip     = bool
    key_name      = string
    additional_volumes = list(object({
      size         = number
      type         = string
      fast_restore = bool
    }))
  }))

  validation {
    condition = alltrue([
      for instance in values(var.instance_configs) :
      contains(["daily", "weekly", "monthly", "critical"], instance.backup_policy)
    ])
    error_message = "Each instance backup_policy must be one of: daily, weekly, monthly, critical."
  }
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  type        = string
  description = "Deployment environment. Must be dev, staging, or prod."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "my_ip" {
  description = "My ip adress"
  type        = string
}

variable "ssh_access" {
  description = "Enable SSH on public instances or Not"
  type        = bool
  default     = false
}

variable "public_sec_group_config" {
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