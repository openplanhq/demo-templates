terraform {
  required_version = ">= 1.9"
}

variable "queues" {
  description = "Queues by name, with their visibility timeout and how many receives before dead-lettering."
  type = map(object({
    visibility_timeout_s = optional(number, 30)
    max_receives         = optional(number, 5)
    fifo                 = optional(bool, false)
  }))
  default = {
    email-outbound   = {}
    image-resize     = { visibility_timeout_s = 300 }
    payment-captured = { fifo = true, max_receives = 3 }
  }

  validation {
    condition     = alltrue([for queue in values(var.queues) : queue.visibility_timeout_s <= 43200])
    error_message = "visibility_timeout_s must be at most 43200 (12 hours)."
  }
}

variable "message_retention_days" {
  description = "How long an unreceived message is kept."
  type        = number
  default     = 4

  validation {
    condition     = var.message_retention_days >= 1 && var.message_retention_days <= 14
    error_message = "message_retention_days must be between 1 and 14."
  }
}

locals {
  names = { for name, queue in var.queues : name => queue.fifo ? "${name}.fifo" : name }
}

resource "terraform_data" "dead_letter" {
  for_each = var.queues

  input = {
    name           = each.value.fifo ? "${each.key}-dlq.fifo" : "${each.key}-dlq"
    retention_days = 14
  }
}

resource "terraform_data" "queue" {
  for_each = var.queues

  input = {
    name                 = local.names[each.key]
    visibility_timeout_s = each.value.visibility_timeout_s
    retention_days       = var.message_retention_days
    dead_letter_target   = terraform_data.dead_letter[each.key].output.name
    max_receives         = each.value.max_receives
  }
}

output "queue_urls" {
  description = "Where producers send each queue's messages."
  value       = { for name, queue in terraform_data.queue : name => "https://queue.demo.internal/${queue.output.name}" }
}
