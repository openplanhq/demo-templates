terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "app_name" {
  description = "Name of the application."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,24}$", var.app_name))
    error_message = "app_name must start with a letter and be 3-25 lowercase alphanumerics or dashes."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "environment must be development, staging or production."
  }
}

variable "image" {
  description = "Container image the API servers run."
  type        = string
  default     = "ghcr.io/acme/web:1.0.0"
}

variable "api_instances" {
  description = "API server count. Production runs at least three."
  type        = number
  default     = 2
}

variable "enable_cache" {
  description = "Put a Redis cache between the API and the database."
  type        = bool
  default     = true
}

locals {
  prefix    = "${var.app_name}-${var.environment}"
  instances = var.environment == "production" ? max(3, var.api_instances) : var.api_instances
}

resource "random_password" "database" {
  length  = 32
  special = false
}

resource "terraform_data" "database" {
  input = {
    name          = "${local.prefix}-db"
    engine        = "postgres17"
    password_hash = sha256(random_password.database.result)
  }
}

resource "terraform_data" "cache" {
  count = var.enable_cache ? 1 : 0

  input = {
    name   = "${local.prefix}-cache"
    engine = "redis7"
  }

  depends_on = [terraform_data.database]
}

resource "terraform_data" "api" {
  count = local.instances

  input = {
    name     = format("%s-api-%d", local.prefix, count.index + 1)
    image    = var.image
    database = terraform_data.database.output.name
    cache    = var.enable_cache ? terraform_data.cache[0].output.name : null
  }
}

resource "terraform_data" "load_balancer" {
  input = {
    name    = "${local.prefix}-lb"
    targets = terraform_data.api[*].output.name
  }
}

output "url" {
  description = "Where the application is served."
  value       = var.environment == "production" ? "https://${var.app_name}.demo.example" : "https://${var.app_name}.${var.environment}.demo.example"
}

output "tiers" {
  description = "Every tier, front to back."
  value = compact([
    terraform_data.load_balancer.output.name,
    "${local.instances} x ${local.prefix}-api",
    var.enable_cache ? terraform_data.cache[0].output.name : "",
    terraform_data.database.output.name,
  ])
}
