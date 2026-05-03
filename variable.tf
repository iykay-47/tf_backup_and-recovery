# Consider Uisng locals on some variables that do not require constraints.

# Project-wide

variable "project_name" {
  description = "Name of Project"
  type        = string
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment. Must be dev, staging, or prod."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# Regions 

variable "primary_region" {
  description = "Primary region to deploy resources"
  type        = string
}

variable "dr_region" {
  description = "disaster recovery region"
  type        = string
}

# EC2 Workload

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

variable "my_ip" {
  description = "My ip adress"
  type        = string
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

variable "ssh_access" {
  description = "Enable SSH on public instances or Not"
  type        = bool
  default     = false
}

# Backup

variable "enable_cross_region_copy" {
  description = "Enable cross region copy?"
  type        = bool
  default     = true
}

variable "retention_counts" {
  description = "Retention counts for different backup types"
  type = object({
    daily_count       = number
    weekly_count      = number
    monthly_count     = number
    snapshot_count    = number
    dr_retention_days = number
  })
  default = {
    daily_count       = 7
    weekly_count      = 4
    monthly_count     = 12
    snapshot_count    = 14
    dr_retention_days = 30
  }
}

variable "backup_schedules" {
  description = "Backup schedule configurations. weekly_day must be a 3-letter abbreviation e.g. SUN, MON."
  type = object({
    daily_time  = string # "02:00"
    weekly_day  = string # e.g. "SUN", "MON"
    monthly_day = number # 1
  })
  default = {
    daily_time  = "02:00"
    weekly_day  = "SUN"
    monthly_day = 1
  }

  validation {
    condition     = contains(["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"], var.backup_schedules.weekly_day)
    error_message = "backup_schedules.weekly_day must be a valid 3-letter day abbreviation: SUN, MON, TUE, WED, THU, FRI, or SAT."
  }
}

# Recovery

variable "dr_availability_zones" {
  description = "List of AZs in DR region"
  type        = list(string)
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

variable "dr_instance_configs" {
  description = "Instance configurations for DR"
  type = map(object({
    instance_type = string
  }))
  default = {}
}

# variable "kms_key_arn" {
#   description = "KMS key ARN from the backup module for DR volume encryption/Decryption. Must be in the DR region."
#   type        = string

# 
#   validation {
#     condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
#     error_message = "kms_key_arn must be a valid KMS key ARN starting with arn:aws:kms:"
#   }
# }