terraform {
  required_version = ">= 1.9"

  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

variable "duration_seconds" {
  description = "Roughly how long the apply takes, split across three steps."
  type        = number
  default     = 90

  validation {
    condition     = var.duration_seconds >= 3 && var.duration_seconds <= 1800
    error_message = "duration_seconds must be between 3 and 1800."
  }
}

variable "slow_destroy" {
  description = "Make destroying take as long as creating."
  type        = bool
  default     = false
}

locals {
  step = "${floor(var.duration_seconds / 3)}s"
}

resource "time_sleep" "provision" {
  create_duration  = local.step
  destroy_duration = var.slow_destroy ? local.step : null
}

resource "time_sleep" "configure" {
  create_duration  = local.step
  destroy_duration = var.slow_destroy ? local.step : null

  depends_on = [time_sleep.provision]
}

resource "time_sleep" "verify" {
  create_duration  = local.step
  destroy_duration = var.slow_destroy ? local.step : null

  depends_on = [time_sleep.configure]
}

resource "terraform_data" "done" {
  input = {
    steps   = ["provision", "configure", "verify"]
    elapsed = "${floor(var.duration_seconds / 3) * 3}s"
  }

  depends_on = [time_sleep.verify]
}

output "elapsed" {
  description = "How long the apply waited in total."
  value       = terraform_data.done.output.elapsed
}
