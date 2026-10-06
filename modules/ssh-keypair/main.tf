terraform {
  required_version = ">= 1.9"

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "key_name" {
  description = "Name the key is registered under."
  type        = string
  default     = "deploy"
}

variable "algorithm" {
  description = "Key algorithm."
  type        = string
  default     = "ED25519"

  validation {
    condition     = contains(["ED25519", "RSA", "ECDSA"], var.algorithm)
    error_message = "algorithm must be ED25519, RSA or ECDSA."
  }
}

variable "comment" {
  description = "Comment appended to the public key."
  type        = string
  default     = "openplan-demo"
}

resource "tls_private_key" "this" {
  algorithm   = var.algorithm
  rsa_bits    = var.algorithm == "RSA" ? 4096 : null
  ecdsa_curve = var.algorithm == "ECDSA" ? "P384" : null
}

resource "terraform_data" "registered_key" {
  input = {
    name        = var.key_name
    fingerprint = tls_private_key.this.public_key_fingerprint_sha256
  }
}

output "public_key" {
  description = "The public key, ready for authorized_keys."
  value       = "${trimspace(tls_private_key.this.public_key_openssh)} ${var.comment}"
}

output "fingerprint" {
  description = "The key's SHA256 fingerprint."
  value       = tls_private_key.this.public_key_fingerprint_sha256
}

output "private_key_openssh" {
  description = "The private key, in OpenSSH format."
  value       = tls_private_key.this.private_key_openssh
  sensitive   = true
}
