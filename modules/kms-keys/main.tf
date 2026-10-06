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

variable "keys" {
  description = "Keys by alias: what they protect and how often they rotate."
  type = map(object({
    usage         = string
    rotation_days = optional(number, 365)
  }))
  default = {
    "app/database" = { usage = "ENCRYPT_DECRYPT" }
    "app/uploads"  = { usage = "ENCRYPT_DECRYPT", rotation_days = 180 }
    "app/tokens"   = { usage = "SIGN_VERIFY", rotation_days = 90 }
  }

  validation {
    condition     = alltrue([for key in values(var.keys) : contains(["ENCRYPT_DECRYPT", "SIGN_VERIFY"], key.usage)])
    error_message = "usage must be ENCRYPT_DECRYPT or SIGN_VERIFY."
  }
}

variable "deletion_window_days" {
  description = "Days a scheduled key deletion waits before it happens."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_days >= 7 && var.deletion_window_days <= 30
    error_message = "deletion_window_days must be between 7 and 30."
  }
}

resource "random_uuid" "key_id" {
  for_each = var.keys
}

resource "time_rotating" "rotation" {
  for_each = var.keys

  rotation_days = each.value.rotation_days
}

resource "terraform_data" "key" {
  for_each = var.keys

  input = {
    id                   = random_uuid.key_id[each.key].result
    usage                = each.value.usage
    deletion_window_days = var.deletion_window_days
    material_generation  = time_rotating.rotation[each.key].id
  }
}

resource "terraform_data" "alias" {
  for_each = var.keys

  input = {
    name   = "alias/${each.key}"
    target = terraform_data.key[each.key].output.id
  }
}

output "key_ids" {
  description = "The key behind each alias."
  value       = { for name, alias in terraform_data.alias : alias.output.name => alias.output.target }
}

output "next_rotation" {
  description = "When each key's material is next rotated."
  value       = { for name, rotation in time_rotating.rotation : name => rotation.rotation_rfc3339 }
}
