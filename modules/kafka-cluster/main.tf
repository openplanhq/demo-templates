terraform {
  required_version = ">= 1.9"
}

variable "cluster_name" {
  description = "Name of the cluster."
  type        = string
  default     = "events"
}

variable "broker_count" {
  description = "How many brokers the cluster runs."
  type        = number
  default     = 3

  validation {
    condition     = var.broker_count >= 1 && var.broker_count <= 9
    error_message = "broker_count must be between 1 and 9."
  }
}

variable "topics" {
  description = "Topics to create."
  type = list(object({
    name               = string
    partitions         = number
    replication_factor = optional(number, 3)
    retention_hours    = optional(number, 168)
    compacted          = optional(bool, false)
  }))
  default = [
    { name = "orders.created", partitions = 12 },
    { name = "orders.shipped", partitions = 6 },
    { name = "customers.profile", partitions = 3, compacted = true, retention_hours = -1 },
  ]
}

resource "terraform_data" "broker" {
  count = var.broker_count

  input = {
    id      = count.index + 1
    address = "${var.cluster_name}-broker-${count.index + 1}.kafka.demo.internal:9092"
  }
}

resource "terraform_data" "topic" {
  for_each = { for topic in var.topics : topic.name => topic }

  input = {
    name               = each.key
    partitions         = each.value.partitions
    replication_factor = each.value.replication_factor
    cleanup_policy     = each.value.compacted ? "compact" : "delete"
    retention_ms       = each.value.retention_hours < 0 ? -1 : each.value.retention_hours * 3600000
  }

  lifecycle {
    precondition {
      condition     = each.value.replication_factor <= var.broker_count
      error_message = "Topic ${each.key} wants ${each.value.replication_factor} replicas but the cluster has ${var.broker_count} brokers."
    }
  }

  depends_on = [terraform_data.broker]
}

output "bootstrap_servers" {
  description = "Brokers clients bootstrap from."
  value       = join(",", terraform_data.broker[*].output.address)
}

output "total_partitions" {
  description = "Partitions across every topic, before replication."
  value       = sum([for topic in var.topics : topic.partitions])
}
