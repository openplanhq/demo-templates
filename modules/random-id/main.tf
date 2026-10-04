terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "name_prefix" {
  description = "Prefix for the generated identifiers."
  type        = string
  default     = "openplan"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must be lowercase alphanumerics and dashes."
  }
}

variable "identifier_length" {
  description = "Length of the generated hexadecimal identifier."
  type        = number
  default     = 8

  validation {
    condition     = var.identifier_length >= 4 && var.identifier_length <= 64
    error_message = "identifier_length must be between 4 and 64."
  }
}

variable "special_characters" {
  description = "Include special characters in the generated password."
  type        = bool
  default     = true
}

resource "random_pet" "this" {
  length    = 2
  separator = "-"
}

resource "random_id" "this" {
  byte_length = var.identifier_length / 2
  prefix      = "${var.name_prefix}-"
}

resource "random_password" "this" {
  length           = 24
  special          = var.special_characters
  override_special = "!#$%&*+-"
}

output "pet_name" {
  description = "A generated two-word pet name."
  value       = random_pet.this.id
}

output "identifier" {
  description = "A generated hexadecimal identifier."
  value       = random_id.this.hex
}

output "password" {
  description = "A generated password."
  value       = random_password.this.result
  sensitive   = true
}
