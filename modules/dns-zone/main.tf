terraform {
  required_version = ">= 1.9"
}

variable "zone_name" {
  description = "The zone's domain, such as example.com."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.zone_name))
    error_message = "zone_name must be a lowercase domain such as example.com."
  }
}

variable "records" {
  description = "Records to create in the zone."
  type = list(object({
    name  = string
    type  = string
    value = string
    ttl   = optional(number, 300)
  }))
  default = [
    { name = "www", type = "CNAME", value = "app.example.net" },
    { name = "api", type = "A", value = "203.0.113.10", ttl = 60 },
    { name = "@", type = "TXT", value = "v=spf1 -all" },
  ]

  validation {
    condition     = alltrue([for record in var.records : contains(["A", "AAAA", "CNAME", "MX", "TXT"], record.type)])
    error_message = "Record types must be A, AAAA, CNAME, MX or TXT."
  }
}

variable "private_zone" {
  description = "Resolve the zone only inside the network."
  type        = bool
  default     = false
}

resource "terraform_data" "zone" {
  input = {
    name    = var.zone_name
    private = var.private_zone
  }
}

resource "terraform_data" "record" {
  for_each = { for record in var.records : "${record.name}/${record.type}" => record }

  input = {
    fqdn  = each.value.name == "@" ? var.zone_name : "${each.value.name}.${var.zone_name}"
    type  = each.value.type
    value = each.value.value
    ttl   = each.value.ttl
    zone  = terraform_data.zone.output.name
  }
}

output "name_servers" {
  description = "The name servers to delegate the zone to."
  value       = [for index in range(4) : "ns-${index + 1}.${var.zone_name}"]
}

output "records" {
  description = "Every record's fully qualified name."
  value       = sort([for record in terraform_data.record : "${record.output.fqdn} ${record.output.type}"])
}
