terraform {
  required_version = ">= 1.9"
}

variable "cluster_name" {
  description = "The cluster the pool joins."
  type        = string
}

variable "pool_name" {
  description = "Name of the pool."
  type        = string
  default     = "workers"
}

variable "machine_type" {
  description = "Machine type for every node."
  type        = string
  default     = "standard-4"
}

variable "node_count" {
  description = "How many nodes the pool starts with."
  type        = number
  default     = 3

  validation {
    condition     = var.node_count >= 0 && var.node_count <= 25 && floor(var.node_count) == var.node_count
    error_message = "node_count must be a whole number between 0 and 25."
  }
}

variable "labels" {
  description = "Kubernetes labels applied to every node."
  type        = map(string)
  default = {
    workload = "general"
  }
}

variable "taints" {
  description = "Taints applied to every node, as key=value:effect."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for taint in var.taints : can(regex("^[a-z0-9./-]+=[a-z0-9-]*:(NoSchedule|PreferNoSchedule|NoExecute)$", taint))])
    error_message = "Each taint must look like key=value:NoSchedule."
  }
}

resource "terraform_data" "pool" {
  input = {
    cluster      = var.cluster_name
    name         = var.pool_name
    machine_type = var.machine_type
    labels       = var.labels
    taints       = var.taints
  }
}

resource "terraform_data" "node" {
  count = var.node_count

  input = {
    name = format("%s-%s-%03d", var.cluster_name, var.pool_name, count.index + 1)
    pool = terraform_data.pool.output.name
  }
}

output "nodes" {
  description = "Every node's name."
  value       = terraform_data.node[*].output.name
}
