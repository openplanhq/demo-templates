terraform {
  required_version = ">= 1.9"
}

# A dependency graph expressed with the built-in terraform_data resource, so
# `tofu plan` reports real adds in dependency order without needing a cloud
# provider.

variable "service_name" {
  description = "Name of the service the graph describes."
  type        = string
}

variable "replicas" {
  description = "How many replicas the web tier runs."
  type        = number
  default     = 2

  validation {
    condition     = var.replicas >= 1 && var.replicas <= 10
    error_message = "replicas must be between 1 and 10."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "development"
}

resource "terraform_data" "database" {
  input = {
    engine = "postgres"
    name   = "${var.service_name}-db"
  }
}

resource "terraform_data" "cache" {
  input = {
    engine = "redis"
    name   = "${var.service_name}-cache"
  }
  depends_on = [terraform_data.database]
}

resource "terraform_data" "api" {
  input = {
    name     = "${var.service_name}-api"
    replicas = var.replicas
  }
  depends_on = [terraform_data.database, terraform_data.cache]
}

resource "terraform_data" "web" {
  input = {
    name     = "${var.service_name}-web"
    upstream = terraform_data.api.output.name
  }
  depends_on = [terraform_data.api]
}

output "tiers" {
  description = "Every tier in the graph, in dependency order."
  value = [
    terraform_data.database.output.name,
    terraform_data.cache.output.name,
    terraform_data.api.output.name,
    terraform_data.web.output.name,
  ]
}

output "upstream" {
  description = "What the web tier points at."
  value       = terraform_data.web.output.upstream
}
