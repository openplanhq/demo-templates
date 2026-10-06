terraform {
  required_version = ">= 1.9"
}

variable "environment" {
  description = "Which environment the flags apply to."
  type        = string
  default     = "production"
}

variable "flags" {
  description = "Flags by name: the share of users who see each one, from 0 to 100."
  type        = map(number)
  default = {
    new-checkout     = 25
    dark-mode        = 100
    ai-search        = 5
    legacy-reports   = 0
    faster-image-cdn = 50
  }

  validation {
    condition     = alltrue([for percent in values(var.flags) : percent >= 0 && percent <= 100])
    error_message = "Every rollout must be between 0 and 100 percent."
  }
}

variable "kill_switch" {
  description = "Turn every flag off at once."
  type        = bool
  default     = false
}

locals {
  effective = { for name, percent in var.flags : name => var.kill_switch ? 0 : percent }
  document = jsonencode({
    environment = var.environment
    flags = {
      for name, percent in local.effective : name => {
        enabled = percent > 0
        rollout = percent
      }
    }
  })
}

resource "terraform_data" "flag" {
  for_each = local.effective

  input = {
    name    = each.key
    state   = each.value == 0 ? "off" : each.value == 100 ? "on" : "rollout"
    percent = each.value
  }
}

resource "terraform_data" "published" {
  input = {
    environment = var.environment
    etag        = substr(sha256(local.document), 0, 16)
  }

  depends_on = [terraform_data.flag]
}

output "document" {
  description = "The flags document clients read."
  value       = local.document
}

output "rolling_out" {
  description = "Flags partway through a rollout."
  value       = sort([for name, percent in local.effective : name if percent > 0 && percent < 100])
}
