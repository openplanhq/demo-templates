terraform {
  required_version = ">= 1.9"
}

variable "policy_name" {
  description = "Name of the policy."
  type        = string
  default     = "edge-protection"
}

variable "mode" {
  description = "Block matching requests, or only count them."
  type        = string
  default     = "block"

  validation {
    condition     = contains(["block", "count"], var.mode)
    error_message = "mode must be block or count."
  }
}

variable "managed_rule_groups" {
  description = "Managed rule groups to enable, in priority order."
  type        = list(string)
  default     = ["core-rule-set", "known-bad-inputs", "sql-injection", "linux-os"]
}

variable "rate_limit_per_5m" {
  description = "Requests one client IP may make in five minutes."
  type        = number
  default     = 2000

  validation {
    condition     = var.rate_limit_per_5m >= 100
    error_message = "rate_limit_per_5m must be at least 100."
  }
}

variable "blocked_ips" {
  description = "Address ranges always blocked."
  type        = list(string)
  default     = ["192.0.2.0/24"]
}

variable "blocked_countries" {
  description = "ISO country codes requests are refused from."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for country in var.blocked_countries : can(regex("^[A-Z]{2}$", country))])
    error_message = "Countries must be two-letter ISO codes such as FR."
  }
}

locals {
  rules = concat(
    length(var.blocked_ips) > 0 ? [{ name = "ip-block-list", kind = "ip-set" }] : [],
    [{ name = "rate-limit", kind = "rate-based" }],
    length(var.blocked_countries) > 0 ? [{ name = "geo-restriction", kind = "geo-match" }] : [],
    [for group in var.managed_rule_groups : { name = group, kind = "managed" }],
  )
}

resource "terraform_data" "ip_set" {
  count = length(var.blocked_ips) > 0 ? 1 : 0

  input = {
    name      = "${var.policy_name}-blocked"
    addresses = var.blocked_ips
  }
}

resource "terraform_data" "rule" {
  for_each = { for index, rule in local.rules : rule.name => merge(rule, { priority = index + 1 }) }

  input = {
    policy   = var.policy_name
    name     = each.key
    kind     = each.value.kind
    priority = each.value.priority
    action   = var.mode
  }

  depends_on = [terraform_data.ip_set]
}

resource "terraform_data" "policy" {
  input = {
    name        = var.policy_name
    rule_count  = length(local.rules)
    rate_limit  = var.rate_limit_per_5m
    geo_blocked = var.blocked_countries
  }

  depends_on = [terraform_data.rule]
}

output "rules_in_order" {
  description = "Every rule, in the order it is evaluated."
  value       = [for rule in local.rules : rule.name]
}
