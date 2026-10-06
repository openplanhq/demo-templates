terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

variable "accounts" {
  description = "Service accounts by name, with the roles each is granted."
  type        = map(list(string))
  default = {
    billing-worker = ["queue.consumer", "db.writer"]
    report-builder = ["warehouse.reader", "storage.writer"]
    metrics-agent  = ["metrics.writer"]
  }
}

variable "key_rotation_days" {
  description = "Days before each account's access key is replaced."
  type        = number
  default     = 90

  validation {
    condition     = var.key_rotation_days >= 1 && var.key_rotation_days <= 365
    error_message = "key_rotation_days must be between 1 and 365."
  }
}

resource "terraform_data" "account" {
  for_each = var.accounts

  input = {
    name  = each.key
    email = "${each.key}@service.demo.internal"
    roles = each.value
  }
}

resource "time_rotating" "key" {
  for_each = var.accounts

  rotation_days = var.key_rotation_days
}

resource "random_id" "key_id" {
  for_each = var.accounts

  byte_length = 10
  prefix      = "AK"

  keepers = {
    rotated_at = time_rotating.key[each.key].id
  }
}

resource "random_password" "key_secret" {
  for_each = var.accounts

  length  = 40
  special = false

  keepers = {
    key_id = random_id.key_id[each.key].hex
  }
}

output "access_key_ids" {
  description = "Each account's current access key id."
  value       = { for name, key in random_id.key_id : name => upper(key.hex) }
}

output "keys_rotate_at" {
  description = "When each key is next replaced."
  value       = { for name, rotation in time_rotating.key : name => rotation.rotation_rfc3339 }
}

output "access_key_secrets" {
  description = "Each account's current secret."
  value       = { for name, secret in random_password.key_secret : name => secret.result }
  sensitive   = true
}
