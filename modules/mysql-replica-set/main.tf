terraform {
  required_version = ">= 1.9"
}

variable "cluster_name" {
  description = "Name of the replica set."
  type        = string
  default     = "orders-mysql"
}

variable "replica_count" {
  description = "How many read replicas follow the primary."
  type        = number
  default     = 2

  validation {
    condition     = var.replica_count >= 0 && var.replica_count <= 5
    error_message = "replica_count must be between 0 and 5."
  }
}

variable "zones" {
  description = "Zones the members are spread across, in order."
  type        = list(string)
  default     = ["zone-a", "zone-b", "zone-c"]
}

variable "binlog_retention_hours" {
  description = "How long the primary keeps binary logs for replicas to catch up."
  type        = number
  default     = 24
}

resource "terraform_data" "primary" {
  input = {
    name            = "${var.cluster_name}-primary"
    zone            = var.zones[0]
    binlog_retained = "${var.binlog_retention_hours}h"
  }
}

resource "terraform_data" "replica" {
  count = var.replica_count

  input = {
    name        = format("%s-replica-%d", var.cluster_name, count.index + 1)
    zone        = var.zones[(count.index + 1) % length(var.zones)]
    replicating = terraform_data.primary.output.name
  }
}

resource "terraform_data" "reader_endpoint" {
  count = var.replica_count > 0 ? 1 : 0

  input = {
    name    = "${var.cluster_name}-ro"
    members = terraform_data.replica[*].output.name
  }
}

output "writer_endpoint" {
  description = "Address for writes."
  value       = "${terraform_data.primary.output.name}.mysql.demo.internal:3306"
}

output "reader_endpoint" {
  description = "Address for reads, or the writer when there are no replicas."
  value       = var.replica_count > 0 ? "${var.cluster_name}-ro.mysql.demo.internal:3306" : "${terraform_data.primary.output.name}.mysql.demo.internal:3306"
}

output "members_by_zone" {
  description = "Which zone every member runs in."
  value = merge(
    { (terraform_data.primary.output.name) = terraform_data.primary.output.zone },
    { for replica in terraform_data.replica : replica.output.name => replica.output.zone },
  )
}
