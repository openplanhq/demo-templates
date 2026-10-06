terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "identifier" {
  description = "Name of the database instance."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.identifier))
    error_message = "identifier must start with a letter and be 3-63 lowercase alphanumerics or dashes."
  }
}

variable "engine_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "17"

  validation {
    condition     = contains(["15", "16", "17"], var.engine_version)
    error_message = "engine_version must be 15, 16 or 17."
  }
}

variable "instance_class" {
  description = "Size of the instance."
  type        = string
  default     = "db.medium"
}

variable "storage_gb" {
  description = "Allocated storage."
  type        = number
  default     = 50

  validation {
    condition     = var.storage_gb >= 20 && var.storage_gb <= 4096
    error_message = "storage_gb must be between 20 and 4096."
  }
}

variable "databases" {
  description = "Databases to create, each with an owner role of the same name."
  type        = set(string)
  default     = ["app"]
}

variable "high_availability" {
  description = "Keep a synchronous standby in a second zone."
  type        = bool
  default     = false
}

resource "random_password" "admin" {
  length  = 32
  special = false
}

resource "terraform_data" "parameter_group" {
  input = {
    name   = "${var.identifier}-pg${var.engine_version}"
    family = "postgres${var.engine_version}"
    parameters = {
      log_min_duration_statement = "500"
      max_connections            = "200"
    }
  }
}

resource "terraform_data" "instance" {
  input = {
    identifier        = var.identifier
    engine_version    = var.engine_version
    instance_class    = var.instance_class
    storage_gb        = var.storage_gb
    multi_az          = var.high_availability
    parameter_group   = terraform_data.parameter_group.output.name
    admin_secret_hash = sha256(random_password.admin.result)
  }
}

resource "terraform_data" "database" {
  for_each = var.databases

  input = {
    instance = terraform_data.instance.output.identifier
    name     = each.key
    owner    = "${each.key}_owner"
  }
}

output "endpoint" {
  description = "Host and port to connect to."
  value       = "${var.identifier}.postgres.demo.internal:5432"
}

output "connection_strings" {
  description = "A connection string per database, without the password."
  value       = { for name in var.databases : name => "postgres://${name}_owner@${var.identifier}.postgres.demo.internal:5432/${name}" }
}

output "admin_password" {
  description = "The generated admin password."
  value       = random_password.admin.result
  sensitive   = true
}
