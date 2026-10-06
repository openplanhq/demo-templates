terraform {
  required_version = ">= 1.9"
}

variable "location" {
  description = "Where the data is stored."
  type        = string
  default     = "EU"

  validation {
    condition     = contains(["EU", "US", "ASIA"], var.location)
    error_message = "location must be EU, US or ASIA."
  }
}

variable "datasets" {
  description = "Datasets by name, each with its tables and their partition column."
  type = map(object({
    description = string
    tables      = map(string)
  }))
  default = {
    raw_events = {
      description = "Events as they arrive from the collectors."
      tables      = { page_views = "event_time", clicks = "event_time", signups = "created_at" }
    }
    marts = {
      description = "Modelled tables for dashboards."
      tables      = { daily_active_users = "day", revenue_by_plan = "month" }
    }
  }
}

variable "table_expiration_days" {
  description = "Days before a table partition expires. Zero keeps data forever."
  type        = number
  default     = 0
}

variable "reader_groups" {
  description = "Groups given read access to every dataset."
  type        = list(string)
  default     = ["analysts@example.com"]
}

locals {
  tables = merge([
    for dataset, spec in var.datasets : {
      for table, partition in spec.tables : "${dataset}.${table}" => {
        dataset   = dataset
        partition = partition
      }
    }
  ]...)
}

resource "terraform_data" "dataset" {
  for_each = var.datasets

  input = {
    name        = each.key
    description = each.value.description
    location    = var.location
    readers     = var.reader_groups
  }
}

resource "terraform_data" "table" {
  for_each = local.tables

  input = {
    id              = each.key
    dataset         = terraform_data.dataset[each.value.dataset].output.name
    partitioned_by  = each.value.partition
    expiration_days = var.table_expiration_days
  }
}

output "tables" {
  description = "Every table, qualified by its dataset."
  value       = sort(keys(terraform_data.table))
}
