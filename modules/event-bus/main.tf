terraform {
  required_version = ">= 1.9"
}

variable "bus_name" {
  description = "Name of the event bus."
  type        = string
  default     = "platform-events"
}

variable "rules" {
  description = "Routing rules: what they match and where matched events go."
  type = list(object({
    name        = string
    source      = string
    detail_type = optional(string)
    targets     = list(string)
    enabled     = optional(bool, true)
  }))
  default = [
    { name = "deploys-to-chat", source = "ci.pipeline", detail_type = "Deployment Finished", targets = ["chat-notifier"] },
    { name = "orders-fanout", source = "shop.orders", targets = ["fulfilment-queue", "analytics-stream", "audit-log"] },
    { name = "security-findings", source = "scanner", detail_type = "Finding", targets = ["pager"], enabled = false },
  ]

  validation {
    condition     = alltrue([for rule in var.rules : length(rule.targets) >= 1 && length(rule.targets) <= 5])
    error_message = "Every rule needs between one and five targets."
  }
}

variable "archive_days" {
  description = "Days every event is archived for replay. Zero turns archiving off."
  type        = number
  default     = 7
}

locals {
  targets = merge([
    for rule in var.rules : {
      for target in rule.targets : "${rule.name}/${target}" => { rule = rule.name, target = target }
    }
  ]...)
}

resource "terraform_data" "bus" {
  input = {
    name = var.bus_name
  }
}

resource "terraform_data" "archive" {
  count = var.archive_days > 0 ? 1 : 0

  input = {
    bus            = terraform_data.bus.output.name
    retention_days = var.archive_days
  }
}

resource "terraform_data" "rule" {
  for_each = { for rule in var.rules : rule.name => rule }

  input = {
    bus     = terraform_data.bus.output.name
    name    = each.key
    pattern = jsonencode(merge({ source = [each.value.source] }, each.value.detail_type == null ? {} : { "detail-type" = [each.value.detail_type] }))
    state   = each.value.enabled ? "ENABLED" : "DISABLED"
  }
}

resource "terraform_data" "target" {
  for_each = local.targets

  input = {
    rule   = terraform_data.rule[each.value.rule].output.name
    target = each.value.target
  }
}

output "routes" {
  description = "Which targets each rule sends to."
  value       = { for rule in var.rules : rule.name => rule.targets }
}
