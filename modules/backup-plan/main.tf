terraform {
  required_version = ">= 1.9"

  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

variable "plan_name" {
  description = "Name of the backup plan."
  type        = string
  default     = "standard-backups"
}

variable "rules" {
  description = "Backup rules by name: how often in hours, and how many days copies are kept."
  type = map(object({
    every_hours    = number
    retention_days = number
  }))
  default = {
    hourly = { every_hours = 1, retention_days = 2 }
    daily  = { every_hours = 24, retention_days = 35 }
    weekly = { every_hours = 168, retention_days = 365 }
  }

  validation {
    condition     = alltrue([for rule in values(var.rules) : rule.every_hours >= 1 && rule.retention_days >= 1])
    error_message = "Rules run at most hourly and keep copies for at least a day."
  }
}

variable "selection_tag" {
  description = "Resources carrying this tag key with the value true are backed up."
  type        = string
  default     = "backup"
}

resource "time_static" "created" {}

resource "terraform_data" "vault" {
  input = {
    name       = "${var.plan_name}-vault"
    encryption = "managed-key"
  }
}

resource "terraform_data" "rule" {
  for_each = var.rules

  input = {
    vault          = terraform_data.vault.output.name
    name           = each.key
    every_hours    = each.value.every_hours
    retention_days = each.value.retention_days
  }
}

resource "time_offset" "first_run" {
  for_each = var.rules

  base_rfc3339 = time_static.created.rfc3339
  offset_hours = each.value.every_hours
}

resource "terraform_data" "selection" {
  input = {
    plan     = var.plan_name
    selector = "tag:${var.selection_tag}=true"
    rules    = sort(keys(terraform_data.rule))
  }
}

output "first_runs" {
  description = "When each rule first runs."
  value       = { for name, offset in time_offset.first_run : name => offset.rfc3339 }
}

output "copies_kept" {
  description = "How many copies each rule holds at steady state."
  value       = { for name, rule in var.rules : name => ceil(rule.retention_days * 24 / rule.every_hours) }
}
