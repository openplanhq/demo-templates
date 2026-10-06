terraform {
  required_version = ">= 1.9"
}

# An address plan: cidrsubnets() carves the base range into one subnet per
# entry, sized by how many bits each adds to the prefix.

variable "base_cidr" {
  description = "The address space to divide."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.base_cidr, 0))
    error_message = "base_cidr must be a valid IPv4 CIDR block."
  }
}

variable "subnets" {
  description = "Subnet names and how many bits each adds to the base prefix."
  type        = map(number)
  default = {
    app      = 4
    data     = 4
    ingress  = 8
    platform = 6
  }

  validation {
    condition     = alltrue([for bits in values(var.subnets) : bits >= 1 && bits <= 12])
    error_message = "Each subnet adds between 1 and 12 bits."
  }
}

locals {
  names  = sort(keys(var.subnets))
  ranges = cidrsubnets(var.base_cidr, [for name in local.names : var.subnets[name]]...)
  plan = {
    for index, name in local.names : name => {
      cidr_block = local.ranges[index]
      gateway    = cidrhost(local.ranges[index], 1)
      hosts      = pow(2, 32 - tonumber(split("/", local.ranges[index])[1])) - 2
    }
  }
}

resource "terraform_data" "subnet" {
  for_each = local.plan

  input = merge(each.value, { name = each.key })
}

output "plan" {
  description = "Every subnet's range, gateway and usable host count."
  value       = local.plan
}
