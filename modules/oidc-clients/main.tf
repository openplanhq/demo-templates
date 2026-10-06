terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "issuer" {
  description = "The identity provider the clients are registered with."
  type        = string
  default     = "https://login.demo.example"

  validation {
    condition     = startswith(var.issuer, "https://")
    error_message = "issuer must be an https:// URL."
  }
}

variable "clients" {
  description = "Clients by name. Public clients (SPAs, mobile apps) get no secret."
  type = map(object({
    redirect_uris = list(string)
    scopes        = optional(list(string), ["openid", "profile", "email"])
    public        = optional(bool, false)
  }))
  default = {
    dashboard = { redirect_uris = ["https://dashboard.demo.example/callback"] }
    mobile    = { redirect_uris = ["com.acme.app:/oauth2redirect"], public = true }
    grafana   = { redirect_uris = ["https://grafana.demo.example/login/generic_oauth"], scopes = ["openid", "email", "groups"] }
  }
}

resource "random_uuid" "client_id" {
  for_each = var.clients
}

resource "random_password" "client_secret" {
  for_each = { for name, client in var.clients : name => client if !client.public }

  length  = 48
  special = false
}

resource "terraform_data" "client" {
  for_each = var.clients

  input = {
    name          = each.key
    client_id     = random_uuid.client_id[each.key].result
    redirect_uris = each.value.redirect_uris
    scopes        = each.value.scopes
    type          = each.value.public ? "public" : "confidential"
  }
}

output "client_ids" {
  description = "Each application's client id."
  value       = { for name, client in terraform_data.client : name => client.output.client_id }
}

output "discovery_url" {
  description = "Where clients read the provider's configuration."
  value       = "${var.issuer}/.well-known/openid-configuration"
}

output "client_secrets" {
  description = "Secrets for the confidential clients."
  value       = { for name, secret in random_password.client_secret : name => secret.result }
  sensitive   = true
}
