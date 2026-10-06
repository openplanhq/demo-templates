terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "domain" {
  description = "The site's domain, such as docs.example.com."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.domain))
    error_message = "domain must be a lowercase domain such as docs.example.com."
  }
}

variable "index_document" {
  description = "Page served for a directory."
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Page served when nothing matches."
  type        = string
  default     = "404.html"
}

variable "spa_mode" {
  description = "Serve the index document for unknown paths, for single-page apps."
  type        = bool
  default     = false
}

resource "random_id" "bucket_suffix" {
  byte_length = 3
}

resource "terraform_data" "bucket" {
  input = {
    name           = "${replace(var.domain, ".", "-")}-${random_id.bucket_suffix.hex}"
    index_document = var.index_document
    error_document = var.spa_mode ? var.index_document : var.error_document
  }
}

resource "tls_private_key" "site" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "site" {
  private_key_pem = tls_private_key.site.private_key_pem

  subject {
    common_name = var.domain
  }

  dns_names             = [var.domain]
  validity_period_hours = 2160
  allowed_uses          = ["digital_signature", "server_auth"]
}

resource "terraform_data" "cdn" {
  input = {
    aliases     = [var.domain]
    origin      = terraform_data.bucket.output.name
    certificate = sha256(tls_self_signed_cert.site.cert_pem)
    hostname    = "${random_id.bucket_suffix.hex}.cdn.demo.internal"
  }
}

resource "terraform_data" "dns_record" {
  input = {
    name  = var.domain
    type  = "CNAME"
    value = terraform_data.cdn.output.hostname
  }
}

output "url" {
  description = "Where the site is served."
  value       = "https://${var.domain}/"
}

output "upload_to" {
  description = "Bucket the site's files are uploaded to."
  value       = "s3://${terraform_data.bucket.output.name}/"
}
