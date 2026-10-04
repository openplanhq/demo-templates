terraform {
  required_version = ">= 1.9"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "name" {
  description = "Name of the rendered configuration bundle."
  type        = string
}

variable "environment" {
  description = "Deployment environment the bundle describes."
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "environment must be development, staging or production."
  }
}

variable "settings" {
  description = "Arbitrary settings merged into the bundle."
  type        = map(string)
  default     = {}
}

locals {
  bundle = jsonencode(merge(
    { name = var.name, environment = var.environment },
    var.settings,
  ))
}

resource "local_file" "this" {
  filename        = "${path.module}/${var.name}.bundle.json"
  content         = local.bundle
  file_permission = "0644"
}

output "path" {
  description = "Where the bundle was written."
  value       = local_file.this.filename
}

output "bundle" {
  description = "The rendered bundle."
  value       = local.bundle
}
