variable "environment" {
  description = "Environment name"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "DR region"
  type        = string
}

variable "dlm_policy_ids" {
  description = "Map of DLM policy IDs to monitor"
  type        = map(string)
}

variable "instance_ids" {
  description = "Map of instance names to IDs"
  type        = map(string)
}

variable "notification_email" {
  description = "Email address for backup notifications"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "alert_thresholds" {
  description = "Thresholds for CloudWatch alarms"
  type = object({
    snapshot_failure_count = number
    missing_backup_hours   = number
    storage_cost_dollars   = number
  })
  default = {
    snapshot_failure_count = 1
    missing_backup_hours   = 6
    storage_cost_dollars   = 50
  }
}