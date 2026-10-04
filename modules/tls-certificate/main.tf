terraform {
  required_version = ">= 1.9"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "common_name" {
  description = "The common name on the certificate."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.common_name))
    error_message = "common_name must be lowercase alphanumerics, dots and dashes."
  }
}

variable "dns_names" {
  description = "Subject alternative names on the certificate."
  type        = list(string)
  default     = []
}

variable "validity_hours" {
  description = "How long the certificate is valid for."
  type        = number
  default     = 720
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "this" {
  private_key_pem = tls_private_key.this.private_key_pem

  subject {
    common_name  = var.common_name
    organization = "openplan demo"
  }

  dns_names             = concat([var.common_name], var.dns_names)
  validity_period_hours = var.validity_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

output "certificate_pem" {
  description = "The generated certificate, PEM encoded."
  value       = tls_self_signed_cert.this.cert_pem
}

output "valid_until" {
  description = "When the certificate stops being valid."
  value       = tls_self_signed_cert.this.validity_end_time
}

output "private_key_pem" {
  description = "The generated private key, PEM encoded."
  value       = tls_private_key.this.private_key_pem
  sensitive   = true
}
