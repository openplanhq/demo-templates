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
  description = "Name of the gateway."
  type        = string
  default     = "edge-vpn"
}

variable "peers" {
  description = "Peer networks by name, and the CIDR block each one routes."
  type        = map(string)
  default = {
    office-london = "192.168.10.0/24"
    office-berlin = "192.168.20.0/24"
  }

  validation {
    condition     = alltrue([for cidr in values(var.peers) : can(cidrhost(cidr, 0))])
    error_message = "Every peer must route a valid IPv4 CIDR block."
  }
}

variable "ike_version" {
  description = "IKE protocol version for the tunnels."
  type        = number
  default     = 2

  validation {
    condition     = contains([1, 2], var.ike_version)
    error_message = "ike_version must be 1 or 2."
  }
}

resource "terraform_data" "gateway" {
  input = {
    name = var.name
    asn  = 64512
  }
}

resource "random_password" "pre_shared_key" {
  for_each = var.peers

  length  = 32
  special = false
}

resource "terraform_data" "tunnel" {
  for_each = var.peers

  input = {
    gateway     = terraform_data.gateway.output.name
    peer        = each.key
    route       = each.value
    ike_version = var.ike_version
    key_digest  = substr(sha256(random_password.pre_shared_key[each.key].result), 0, 12)
  }
}

output "tunnels" {
  description = "Each tunnel's peer and the route it carries."
  value       = { for peer, tunnel in terraform_data.tunnel : peer => tunnel.output.route }
}

output "pre_shared_keys" {
  description = "The generated pre-shared key for each tunnel."
  value       = { for peer, key in random_password.pre_shared_key : peer => key.result }
  sensitive   = true
}
