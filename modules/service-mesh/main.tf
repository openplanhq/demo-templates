terraform {
  required_version = ">= 1.9"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "trust_domain" {
  description = "The mesh's trust domain, used in every workload identity."
  type        = string
  default     = "cluster.local"
}

variable "services" {
  description = "Services that join the mesh."
  type        = set(string)
  default     = ["checkout", "inventory", "payments", "storefront"]

  validation {
    condition     = length(var.services) > 0
    error_message = "Give at least one service."
  }
}

variable "workload_cert_hours" {
  description = "How long each workload certificate is valid."
  type        = number
  default     = 24

  validation {
    condition     = var.workload_cert_hours >= 1 && var.workload_cert_hours <= 720
    error_message = "workload_cert_hours must be between 1 and 720."
  }
}

resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "${var.trust_domain} mesh CA"
    organization = "openplan demo"
  }

  is_ca_certificate     = true
  validity_period_hours = 8760
  allowed_uses          = ["cert_signing", "crl_signing"]
}

resource "tls_private_key" "workload" {
  for_each = var.services

  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "workload" {
  for_each = var.services

  private_key_pem = tls_private_key.workload[each.key].private_key_pem
  uris            = ["spiffe://${var.trust_domain}/ns/default/sa/${each.key}"]

  subject {
    common_name = each.key
  }
}

resource "tls_locally_signed_cert" "workload" {
  for_each = var.services

  cert_request_pem      = tls_cert_request.workload[each.key].cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = var.workload_cert_hours
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth", "client_auth"]
}

output "ca_certificate_pem" {
  description = "The mesh CA certificate every workload trusts."
  value       = tls_self_signed_cert.ca.cert_pem
}

output "identities" {
  description = "Each service's SPIFFE identity."
  value       = { for service in var.services : service => "spiffe://${var.trust_domain}/ns/default/sa/${service}" }
}

output "workload_certificates_expire" {
  description = "When each workload certificate stops being valid."
  value       = { for service, cert in tls_locally_signed_cert.workload : service => cert.validity_end_time }
}
