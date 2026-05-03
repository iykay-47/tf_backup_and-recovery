variable "project_name" {
  description = "Name of project"
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

variable "primary_region" {
  type        = string
  description = "Region where original resources are deployed"
}

variable "dr_region" {
  type        = string
  description = "Region to store copy of backup for disaster recovery"
}

variable "enable_cross_region_copy" {
  description = "Enable cross region copy?"
  type        = bool
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

variable "common_tags" {
  description = "Tags you want through the project"
  type        = map(string)
  default     = {}
}