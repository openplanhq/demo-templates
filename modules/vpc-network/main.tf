terraform {
  required_version = ">= 1.9"
}

# A VPC expressed with terraform_data: one network, a public and a private
# subnet per availability zone, and optionally a NAT gateway per zone. The
# subnet ranges are real cidrsubnet() arithmetic.

variable "name" {
  description = "Name of the network."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must start with a letter and be 2-31 lowercase alphanumerics or dashes."
  }
}

variable "cidr_block" {
  description = "The network's IPv4 address range."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Zones to spread the subnets across."
  type        = list(string)
  default     = ["zone-a", "zone-b", "zone-c"]

  validation {
    condition     = length(var.availability_zones) >= 1 && length(var.availability_zones) <= 6
    error_message = "Give between one and six availability zones."
  }
}

variable "enable_nat_gateway" {
  description = "Give each zone a NAT gateway so private subnets can reach out."
  type        = bool
  default     = true
}

locals {
  zones = { for index, zone in var.availability_zones : zone => index }
}

resource "terraform_data" "network" {
  input = {
    name       = var.name
    cidr_block = var.cidr_block
  }
}

resource "terraform_data" "public_subnet" {
  for_each = local.zones

  input = {
    name       = "${var.name}-public-${each.key}"
    zone       = each.key
    cidr_block = cidrsubnet(var.cidr_block, 4, each.value)
    network    = terraform_data.network.output.name
  }
}

resource "terraform_data" "private_subnet" {
  for_each = local.zones

  input = {
    name       = "${var.name}-private-${each.key}"
    zone       = each.key
    cidr_block = cidrsubnet(var.cidr_block, 4, each.value + 8)
    network    = terraform_data.network.output.name
  }
}

resource "terraform_data" "nat_gateway" {
  for_each = var.enable_nat_gateway ? local.zones : {}

  input = {
    name   = "${var.name}-nat-${each.key}"
    subnet = terraform_data.public_subnet[each.key].output.name
  }
}

output "network" {
  description = "The network's name and range."
  value       = terraform_data.network.output
}

output "public_subnets" {
  description = "Public subnet ranges by zone."
  value       = { for zone, subnet in terraform_data.public_subnet : zone => subnet.output.cidr_block }
}

output "private_subnets" {
  description = "Private subnet ranges by zone."
  value       = { for zone, subnet in terraform_data.private_subnet : zone => subnet.output.cidr_block }
}
