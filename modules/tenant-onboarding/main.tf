terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "tenants" {
  description = "Tenants by slug: their plan and first administrator."
  type = map(object({
    plan        = string
    admin_email = string
    region      = optional(string, "eu")
  }))
  default = {
    globex   = { plan = "enterprise", admin_email = "it@globex.example" }
    initech  = { plan = "team", admin_email = "ops@initech.example", region = "us" }
    umbrella = { plan = "free", admin_email = "admin@umbrella.example" }
  }

  validation {
    condition     = alltrue([for tenant in values(var.tenants) : contains(["free", "team", "enterprise"], tenant.plan)])
    error_message = "plan must be free, team or enterprise."
  }

  validation {
    condition     = alltrue([for tenant in values(var.tenants) : can(regex("^[^@]+@[^@]+$", tenant.admin_email))])
    error_message = "admin_email must be an email address."
  }
}

locals {
  quotas = {
    free       = { cpu = 2, memory_gb = 4, storage_gb = 10 }
    team       = { cpu = 16, memory_gb = 64, storage_gb = 500 }
    enterprise = { cpu = 128, memory_gb = 512, storage_gb = 10000 }
  }
}

resource "terraform_data" "namespace" {
  for_each = var.tenants

  input = {
    name   = "tenant-${each.key}"
    region = each.value.region
    plan   = each.value.plan
  }
}

resource "terraform_data" "quota" {
  for_each = var.tenants

  input = merge(local.quotas[each.value.plan], {
    namespace = terraform_data.namespace[each.key].output.name
  })
}

resource "random_id" "storage_prefix" {
  for_each = var.tenants

  byte_length = 6
}

resource "random_password" "invite_code" {
  for_each = var.tenants

  length  = 20
  special = false
}

resource "terraform_data" "admin_invite" {
  for_each = var.tenants

  input = {
    namespace   = terraform_data.namespace[each.key].output.name
    email       = each.value.admin_email
    code_digest = substr(sha256(random_password.invite_code[each.key].result), 0, 12)
  }
}

output "namespaces" {
  description = "Each tenant's namespace and plan."
  value       = { for slug, namespace in terraform_data.namespace : slug => "${namespace.output.name} (${namespace.output.plan})" }
}

output "storage_prefixes" {
  description = "Each tenant's storage prefix."
  value       = { for slug, prefix in random_id.storage_prefix : slug => "tenants/${prefix.hex}/" }
}

output "invite_codes" {
  description = "Invite codes sent to each tenant's first administrator."
  value       = { for slug, code in random_password.invite_code : slug => code.result }
  sensitive   = true
}
