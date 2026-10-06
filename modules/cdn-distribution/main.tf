terraform {
  required_version = ">= 1.9"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "domain" {
  description = "The domain the distribution serves."
  type        = string
}

variable "origin_domain" {
  description = "Where cache misses are fetched from."
  type        = string
  default     = "origin.demo.internal"
}

variable "price_class" {
  description = "Which edge locations serve traffic."
  type        = string
  default     = "regional"

  validation {
    condition     = contains(["regional", "continental", "global"], var.price_class)
    error_message = "price_class must be regional, continental or global."
  }
}

variable "cache_behaviours" {
  description = "Cache lifetime in seconds per path pattern."
  type        = map(number)
  default = {
    "/static/*" = 86400
    "/api/*"    = 0
    "*"         = 300
  }
}

resource "tls_private_key" "edge" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "edge" {
  private_key_pem = tls_private_key.edge.private_key_pem

  subject {
    common_name  = var.domain
    organization = "openplan demo"
  }

  dns_names             = [var.domain, "www.${var.domain}"]
  validity_period_hours = 2160
  allowed_uses          = ["digital_signature", "server_auth"]
}

resource "terraform_data" "origin" {
  input = {
    domain   = var.origin_domain
    protocol = "https-only"
  }
}

resource "terraform_data" "distribution" {
  input = {
    domain      = var.domain
    origin      = terraform_data.origin.output.domain
    price_class = var.price_class
    certificate = sha256(tls_self_signed_cert.edge.cert_pem)
  }
}

resource "terraform_data" "cache_behaviour" {
  for_each = var.cache_behaviours

  input = {
    distribution = terraform_data.distribution.output.domain
    path_pattern = each.key
    ttl_seconds  = each.value
  }
}

output "edge_domain" {
  description = "The distribution's edge hostname."
  value       = "${replace(var.domain, ".", "-")}.edge.demo.internal"
}

output "certificate_expires" {
  description = "When the edge certificate stops being valid."
  value       = tls_self_signed_cert.edge.validity_end_time
}
