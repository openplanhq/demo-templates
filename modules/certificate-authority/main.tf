terraform {
  required_version = ">= 1.9"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "organization" {
  description = "Organization named on both certificates."
  type        = string
  default     = "Acme Corp"
}

variable "root_validity_years" {
  description = "How long the root CA is valid."
  type        = number
  default     = 10

  validation {
    condition     = var.root_validity_years >= 1 && var.root_validity_years <= 25
    error_message = "root_validity_years must be between 1 and 25."
  }
}

variable "intermediate_validity_years" {
  description = "How long the intermediate CA is valid. Keep it shorter than the root."
  type        = number
  default     = 3
}

resource "tls_private_key" "root" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "root" {
  private_key_pem = tls_private_key.root.private_key_pem

  subject {
    common_name  = "${var.organization} Root CA"
    organization = var.organization
  }

  is_ca_certificate     = true
  validity_period_hours = var.root_validity_years * 8766
  allowed_uses          = ["cert_signing", "crl_signing"]
}

resource "tls_private_key" "intermediate" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "intermediate" {
  private_key_pem = tls_private_key.intermediate.private_key_pem

  subject {
    common_name  = "${var.organization} Issuing CA"
    organization = var.organization
  }
}

resource "tls_locally_signed_cert" "intermediate" {
  cert_request_pem   = tls_cert_request.intermediate.cert_request_pem
  ca_private_key_pem = tls_private_key.root.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root.cert_pem

  is_ca_certificate     = true
  validity_period_hours = var.intermediate_validity_years * 8766
  allowed_uses          = ["cert_signing", "crl_signing", "digital_signature"]

  lifecycle {
    precondition {
      condition     = var.intermediate_validity_years < var.root_validity_years
      error_message = "The intermediate CA must expire before the root CA."
    }
  }
}

output "root_certificate_pem" {
  description = "The root certificate to distribute to trust stores."
  value       = tls_self_signed_cert.root.cert_pem
}

output "chain_pem" {
  description = "Intermediate then root, as servers present them."
  value       = "${tls_locally_signed_cert.intermediate.cert_pem}${tls_self_signed_cert.root.cert_pem}"
}

output "intermediate_expires" {
  description = "When the issuing CA must be replaced."
  value       = tls_locally_signed_cert.intermediate.validity_end_time
}
