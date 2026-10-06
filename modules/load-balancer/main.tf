terraform {
  required_version = ">= 1.9"
}

variable "name" {
  description = "Name of the load balancer."
  type        = string
}

variable "listeners" {
  description = "Ports the load balancer listens on, and what it forwards to."
  type = list(object({
    port        = number
    protocol    = string
    target_port = number
  }))
  default = [
    { port = 80, protocol = "HTTP", target_port = 8080 },
    { port = 443, protocol = "HTTPS", target_port = 8080 },
  ]

  validation {
    condition     = alltrue([for listener in var.listeners : contains(["HTTP", "HTTPS", "TCP"], listener.protocol)])
    error_message = "protocol must be HTTP, HTTPS or TCP."
  }
}

variable "health_check_path" {
  description = "Path the target groups are health-checked on."
  type        = string
  default     = "/healthz"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must start with a slash."
  }
}

variable "internal" {
  description = "Reachable only from inside the network."
  type        = bool
  default     = false
}

resource "terraform_data" "load_balancer" {
  input = {
    name   = var.name
    scheme = var.internal ? "internal" : "internet-facing"
  }
}

resource "terraform_data" "target_group" {
  for_each = { for listener in var.listeners : tostring(listener.port) => listener }

  input = {
    name         = "${var.name}-tg-${each.key}"
    port         = each.value.target_port
    health_check = var.health_check_path
  }
}

resource "terraform_data" "listener" {
  for_each = { for listener in var.listeners : tostring(listener.port) => listener }

  input = {
    load_balancer = terraform_data.load_balancer.output.name
    port          = each.value.port
    protocol      = each.value.protocol
    forward_to    = terraform_data.target_group[each.key].output.name
  }
}

output "dns_name" {
  description = "The load balancer's address."
  value       = "${var.name}.lb.demo.internal"
}

output "listeners" {
  description = "Each listening port and the target group it forwards to."
  value       = { for port, listener in terraform_data.listener : port => listener.output.forward_to }
}
