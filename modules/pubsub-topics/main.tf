terraform {
  required_version = ">= 1.9"
}

variable "topics" {
  description = "Topics by name, each with its subscriptions."
  type = map(map(object({
    push_endpoint = optional(string)
    filter        = optional(string, "")
    ack_deadline  = optional(number, 20)
  })))
  default = {
    user-events = {
      analytics-ingest = {}
      crm-sync         = { push_endpoint = "https://crm.demo.example/hooks/users", filter = "attributes.type = \"signup\"" }
    }
    invoice-events = {
      ledger      = { ack_deadline = 60 }
      email-sends = { push_endpoint = "https://mailer.demo.example/hooks/invoices" }
    }
  }

  validation {
    condition = alltrue(flatten([
      for subscriptions in values(var.topics) : [
        for subscription in values(subscriptions) :
        subscription.push_endpoint == null ? true : startswith(subscription.push_endpoint, "https://")
      ]
    ]))
    error_message = "Push endpoints must use https://."
  }
}

variable "message_retention_hours" {
  description = "How long a topic keeps messages for late subscribers."
  type        = number
  default     = 24
}

locals {
  subscriptions = merge([
    for topic, subscriptions in var.topics : {
      for name, subscription in subscriptions : "${topic}/${name}" => merge(subscription, { topic = topic, name = name })
    }
  ]...)
}

resource "terraform_data" "topic" {
  for_each = var.topics

  input = {
    name            = each.key
    retention_hours = var.message_retention_hours
  }
}

resource "terraform_data" "subscription" {
  for_each = local.subscriptions

  input = {
    name         = each.value.name
    topic        = terraform_data.topic[each.value.topic].output.name
    delivery     = each.value.push_endpoint == null ? "pull" : "push"
    endpoint     = each.value.push_endpoint
    filter       = each.value.filter
    ack_deadline = each.value.ack_deadline
  }
}

output "subscriptions" {
  description = "Every subscription and how it is delivered."
  value       = { for key, subscription in terraform_data.subscription : key => subscription.output.delivery }
}
