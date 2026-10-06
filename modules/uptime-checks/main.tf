terraform {
  required_version = ">= 1.9"
}

variable "checks" {
  description = "Checks by name: the URL, how often, and the status expected."
  type = map(object({
    url             = string
    interval_s      = optional(number, 60)
    expected_status = optional(number, 200)
    contains        = optional(string)
  }))
  default = {
    homepage = { url = "https://www.demo.example/" }
    api      = { url = "https://api.demo.example/healthz", interval_s = 30 }
    login    = { url = "https://login.demo.example/", contains = "Sign in" }
  }

  validation {
    condition     = alltrue([for check in values(var.checks) : startswith(check.url, "https://")])
    error_message = "Every check URL must use https://."
  }

  validation {
    condition     = alltrue([for check in values(var.checks) : contains([30, 60, 300, 900], check.interval_s)])
    error_message = "interval_s must be 30, 60, 300 or 900."
  }
}

variable "regions" {
  description = "Regions the checks run from."
  type        = list(string)
  default     = ["eu-west", "us-east", "ap-southeast"]
}

variable "alert_after_failures" {
  description = "Consecutive failed regions before an alert fires."
  type        = number
  default     = 2
}

resource "terraform_data" "check" {
  for_each = var.checks

  input = {
    name            = each.key
    url             = each.value.url
    interval_s      = each.value.interval_s
    expected_status = each.value.expected_status
    body_contains   = each.value.contains
    regions         = var.regions
    alert_after     = var.alert_after_failures
  }
}

output "probes_per_day" {
  description = "Requests every check makes in a day, across all regions."
  value       = { for name, check in var.checks : name => floor(86400 / check.interval_s) * length(var.regions) }
}
