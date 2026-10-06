terraform {
  required_version = ">= 1.9"
}

variable "name" {
  description = "Name of the security group."
  type        = string
}

variable "ingress_rules" {
  description = "Inbound rules: a description, a port range, a protocol and who may connect."
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = optional(string, "tcp")
    sources     = list(string)
  }))
  default = [
    { description = "HTTPS from anywhere", from_port = 443, to_port = 443, sources = ["0.0.0.0/0"] },
    { description = "SSH from the office", from_port = 22, to_port = 22, sources = ["198.51.100.0/24"] },
  ]

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      rule.from_port >= 0 && rule.to_port <= 65535 && rule.from_port <= rule.to_port
    ])
    error_message = "Ports must be within 0-65535, and from_port no greater than to_port."
  }

  validation {
    condition     = alltrue([for rule in var.ingress_rules : contains(["tcp", "udp", "icmp"], rule.protocol)])
    error_message = "protocol must be tcp, udp or icmp."
  }
}

variable "allow_all_egress" {
  description = "Allow every outbound connection."
  type        = bool
  default     = true
}

resource "terraform_data" "security_group" {
  input = {
    name = var.name
  }
}

resource "terraform_data" "ingress" {
  for_each = { for rule in var.ingress_rules : "${rule.protocol}-${rule.from_port}-${rule.to_port}" => rule }

  input = {
    security_group = terraform_data.security_group.output.name
    description    = each.value.description
    ports          = each.value.from_port == each.value.to_port ? tostring(each.value.from_port) : "${each.value.from_port}-${each.value.to_port}"
    protocol       = each.value.protocol
    sources        = each.value.sources
  }
}

resource "terraform_data" "egress" {
  count = var.allow_all_egress ? 1 : 0

  input = {
    security_group = terraform_data.security_group.output.name
    destination    = "0.0.0.0/0"
  }
}

output "open_ports" {
  description = "Every opened port range and protocol."
  value       = sort(keys(terraform_data.ingress))
}

output "world_reachable" {
  description = "Rules open to the whole internet."
  value       = sort([for key, rule in terraform_data.ingress : key if contains(rule.output.sources, "0.0.0.0/0")])
}
