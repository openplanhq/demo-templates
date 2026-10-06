terraform {
  required_version = ">= 1.9"
}

variable "service" {
  description = "The service the objective covers."
  type        = string
  default     = "checkout"
}

variable "objective_percent" {
  description = "Target availability, such as 99.9."
  type        = number
  default     = 99.9

  validation {
    condition     = var.objective_percent >= 90 && var.objective_percent < 100
    error_message = "objective_percent must be at least 90 and below 100."
  }
}

variable "window_days" {
  description = "Rolling window the objective is measured over."
  type        = number
  default     = 28

  validation {
    condition     = contains([7, 28, 30, 90], var.window_days)
    error_message = "window_days must be 7, 28, 30 or 90."
  }
}

variable "requests_per_day" {
  description = "Typical daily request volume."
  type        = number
  default     = 2500000
}

# Rounded to the nearest unit: 99.9 is not exact in binary, so an unrounded
# floor() would report one request fewer than the budget allows.
locals {
  budget_fraction = (100 - var.objective_percent) / 100
  window_minutes  = var.window_days * 24 * 60
}

resource "terraform_data" "slo" {
  input = {
    service     = var.service
    objective   = "${var.objective_percent}%"
    window      = "${var.window_days}d"
    burn_alerts = ["14.4x over 1h", "6x over 6h", "1x over 3d"]
  }
}

output "allowed_downtime_minutes" {
  description = "Minutes of full outage the window allows."
  value       = floor(local.window_minutes * local.budget_fraction * 10 + 0.5) / 10
}

output "allowed_failed_requests" {
  description = "Failed requests the window allows at typical volume."
  value       = floor(var.requests_per_day * var.window_days * local.budget_fraction + 0.5)
}
