terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "vault_name" {
  description = "Name of the secrets store."
  type        = string
  default     = "app-secrets"
}

variable "secrets" {
  description = "Secrets to generate: length, and whether symbols are allowed."
  type = map(object({
    length  = optional(number, 32)
    special = optional(bool, true)
  }))
  default = {
    "session-signing-key" = { length = 64, special = false }
    "webhook-secret"      = {}
    "database-password"   = { length = 40 }
  }

  validation {
    condition     = alltrue([for secret in values(var.secrets) : secret.length >= 16 && secret.length <= 128])
    error_message = "Every secret must be between 16 and 128 characters."
  }
}

variable "recovery_window_days" {
  description = "Days a deleted secret can still be restored."
  type        = number
  default     = 7
}

resource "terraform_data" "vault" {
  input = {
    name                 = var.vault_name
    recovery_window_days = var.recovery_window_days
  }
}

resource "random_password" "value" {
  for_each = var.secrets

  length           = each.value.length
  special          = each.value.special
  override_special = "!#%&*+-=?@^_"
}

resource "terraform_data" "secret" {
  for_each = var.secrets

  input = {
    vault   = terraform_data.vault.output.name
    path    = "${var.vault_name}/${each.key}"
    version = substr(sha256(random_password.value[each.key].result), 0, 10)
  }
}

output "secret_paths" {
  description = "Where each secret is stored, and its version."
  value       = { for name, secret in terraform_data.secret : secret.output.path => secret.output.version }
}
