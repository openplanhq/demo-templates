terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

variable "team" {
  description = "Team that owns the environment."
  type        = string
}

variable "environment" {
  description = "Kind of environment."
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production", "sandbox"], var.environment)
    error_message = "environment must be development, staging, production or sandbox."
  }
}

variable "cost_center" {
  description = "Cost centre the environment's spend is charged to."
  type        = string
  default     = "CC-1000"

  validation {
    condition     = can(regex("^CC-[0-9]{4}$", var.cost_center))
    error_message = "cost_center must look like CC-1234."
  }
}

variable "extra_tags" {
  description = "Tags added to the standard set."
  type        = map(string)
  default     = {}
}

resource "random_pet" "codename" {
  length = 2

  keepers = {
    team        = var.team
    environment = var.environment
  }
}

resource "time_static" "created" {
  triggers = {
    codename = random_pet.codename.id
  }
}

locals {
  short_env = {
    development = "dev"
    staging     = "stg"
    production  = "prd"
    sandbox     = "sbx"
  }[var.environment]
}

resource "terraform_data" "environment" {
  input = {
    name_prefix = "${var.team}-${local.short_env}"
    codename    = random_pet.codename.id
    created_at  = time_static.created.rfc3339
  }
}

output "name_prefix" {
  description = "Prefix every resource in the environment is named with."
  value       = terraform_data.environment.output.name_prefix
}

output "tags" {
  description = "Tags every resource in the environment carries."
  value = merge(var.extra_tags, {
    team        = var.team
    environment = var.environment
    cost_center = var.cost_center
    codename    = random_pet.codename.id
    created_at  = time_static.created.rfc3339
    managed_by  = "openplan"
  })
}
