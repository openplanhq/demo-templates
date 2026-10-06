terraform {
  required_version = ">= 1.9"

  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

variable "day" {
  description = "Day of the week the window opens."
  type        = string
  default     = "Sun"

  validation {
    condition     = contains(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], var.day)
    error_message = "day must be Mon, Tue, Wed, Thu, Fri, Sat or Sun."
  }
}

variable "start_hour_utc" {
  description = "Hour the window opens, in UTC."
  type        = number
  default     = 2

  validation {
    condition     = var.start_hour_utc >= 0 && var.start_hour_utc <= 23 && floor(var.start_hour_utc) == var.start_hour_utc
    error_message = "start_hour_utc must be a whole hour from 0 to 23."
  }
}

variable "duration_hours" {
  description = "How long the window stays open."
  type        = number
  default     = 4

  validation {
    condition     = var.duration_hours >= 1 && var.duration_hours <= 12
    error_message = "duration_hours must be between 1 and 12."
  }
}

resource "time_static" "anchor" {
  triggers = {
    day  = var.day
    hour = var.start_hour_utc
  }
}

locals {
  days         = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  today        = index(local.days, formatdate("EEE", time_static.anchor.rfc3339))
  days_ahead   = (index(local.days, var.day) - local.today + 7) % 7
  minutes_now  = time_static.anchor.hour * 60 + time_static.anchor.minute
  minutes_away = local.days_ahead * 1440 + var.start_hour_utc * 60 - local.minutes_now
  # A window already open or past today waits for next week.
  minutes_until = local.minutes_away > 0 ? local.minutes_away : local.minutes_away + 7 * 1440
}

resource "time_offset" "opens" {
  base_rfc3339   = time_static.anchor.rfc3339
  offset_minutes = local.minutes_until
  offset_seconds = -time_static.anchor.second
}

resource "time_offset" "closes" {
  base_rfc3339 = time_offset.opens.rfc3339
  offset_hours = var.duration_hours
}

output "schedule" {
  description = "The recurring window, in words."
  value       = format("Every %s, %02d:00 to %02d:00 UTC", var.day, var.start_hour_utc, (var.start_hour_utc + var.duration_hours) % 24)
}

output "next_opens" {
  description = "When the next window opens."
  value       = time_offset.opens.rfc3339
}

output "next_closes" {
  description = "When the next window closes."
  value       = time_offset.closes.rfc3339
}
