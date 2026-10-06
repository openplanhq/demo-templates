terraform {
  required_version = ">= 1.9"

  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

variable "cluster_name" {
  description = "Name of the cluster."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,39}$", var.cluster_name))
    error_message = "cluster_name must start with a letter and be 3-40 lowercase alphanumerics or dashes."
  }
}

variable "kubernetes_version" {
  description = "Control plane version."
  type        = string
  default     = "1.33"

  validation {
    condition     = contains(["1.31", "1.32", "1.33"], var.kubernetes_version)
    error_message = "kubernetes_version must be 1.31, 1.32 or 1.33."
  }
}

variable "node_pools" {
  description = "Node pools by name: machine type and autoscaling bounds."
  type = map(object({
    machine_type = string
    min_nodes    = number
    max_nodes    = number
    spot         = optional(bool, false)
  }))
  default = {
    system  = { machine_type = "standard-2", min_nodes = 1, max_nodes = 3 }
    general = { machine_type = "standard-4", min_nodes = 2, max_nodes = 10 }
    batch   = { machine_type = "highcpu-8", min_nodes = 0, max_nodes = 20, spot = true }
  }

  validation {
    condition     = alltrue([for pool in values(var.node_pools) : pool.min_nodes <= pool.max_nodes])
    error_message = "Every pool's min_nodes must be no greater than its max_nodes."
  }
}

variable "private_endpoint" {
  description = "Serve the API server only inside the network."
  type        = bool
  default     = true
}

resource "terraform_data" "control_plane" {
  input = {
    name             = var.cluster_name
    version          = var.kubernetes_version
    private_endpoint = var.private_endpoint
  }
}

# Stands in for the minutes a real control plane takes to become ready.
resource "time_sleep" "control_plane_ready" {
  create_duration = "15s"

  triggers = {
    control_plane = terraform_data.control_plane.output.name
  }
}

resource "terraform_data" "node_pool" {
  for_each = var.node_pools

  input = {
    cluster      = time_sleep.control_plane_ready.triggers.control_plane
    name         = each.key
    machine_type = each.value.machine_type
    min_nodes    = each.value.min_nodes
    max_nodes    = each.value.max_nodes
    capacity     = each.value.spot ? "spot" : "on-demand"
  }
}

output "endpoint" {
  description = "The API server address."
  value       = var.private_endpoint ? "https://${var.cluster_name}.internal:6443" : "https://${var.cluster_name}.k8s.demo.example:6443"
}

output "max_nodes" {
  description = "How many nodes the cluster can scale to across every pool."
  value       = sum([for pool in values(var.node_pools) : pool.max_nodes])
}

output "node_pools" {
  description = "Each pool's machine type and capacity."
  value       = { for name, pool in terraform_data.node_pool : name => "${pool.output.machine_type} (${pool.output.capacity})" }
}
