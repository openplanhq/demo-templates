terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "name" {
  description = "Name of the cache."
  type        = string
}

variable "shards" {
  description = "How many shards the keyspace is split across."
  type        = number
  default     = 3

  validation {
    condition     = var.shards >= 1 && var.shards <= 16
    error_message = "shards must be between 1 and 16."
  }
}

variable "replicas_per_shard" {
  description = "Replicas kept for each shard."
  type        = number
  default     = 1

  validation {
    condition     = var.replicas_per_shard >= 0 && var.replicas_per_shard <= 3
    error_message = "replicas_per_shard must be between 0 and 3."
  }
}

variable "eviction_policy" {
  description = "What Redis drops when memory is full."
  type        = string
  default     = "allkeys-lru"

  validation {
    condition     = contains(["allkeys-lru", "allkeys-lfu", "volatile-lru", "volatile-ttl", "noeviction"], var.eviction_policy)
    error_message = "eviction_policy must be a Redis maxmemory-policy."
  }
}

locals {
  slots_per_shard = floor(16384 / var.shards)
}

resource "random_password" "auth_token" {
  length  = 40
  special = false
}

resource "terraform_data" "shard" {
  count = var.shards

  input = {
    name     = format("%s-%04d", var.name, count.index + 1)
    replicas = var.replicas_per_shard
    slots    = "${count.index * local.slots_per_shard}-${count.index == var.shards - 1 ? 16383 : (count.index + 1) * local.slots_per_shard - 1}"
  }
}

resource "terraform_data" "cluster" {
  input = {
    name            = var.name
    shards          = terraform_data.shard[*].output.name
    eviction_policy = var.eviction_policy
    auth_enabled    = random_password.auth_token.result != ""
  }
}

output "configuration_endpoint" {
  description = "Cluster-aware clients connect here."
  value       = "${var.name}.cache.demo.internal:6379"
}

output "slot_ranges" {
  description = "Hash slots each shard owns."
  value       = { for shard in terraform_data.shard : shard.output.name => shard.output.slots }
}

output "nodes" {
  description = "Total nodes, primaries and replicas."
  value       = var.shards * (1 + var.replicas_per_shard)
}

output "auth_token" {
  description = "Token clients authenticate with."
  value       = random_password.auth_token.result
  sensitive   = true
}
