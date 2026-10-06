terraform {
  required_version = ">= 1.9"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

variable "pipeline_name" {
  description = "Name of the pipeline."
  type        = string
  default     = "storefront"
}

variable "version_tag" {
  description = "Version being delivered. Changing it re-runs every stage."
  type        = string
  default     = "1.0.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.version_tag))
    error_message = "version_tag must be a semantic version such as 1.4.2."
  }
}

variable "run_integration_tests" {
  description = "Include the integration test stage."
  type        = bool
  default     = true
}

variable "deploy_targets" {
  description = "Environments the release is deployed to, in order."
  type        = list(string)
  default     = ["staging", "production"]
}

resource "null_resource" "build" {
  triggers = {
    pipeline = var.pipeline_name
    version  = var.version_tag
  }
}

resource "null_resource" "unit_tests" {
  triggers = {
    build = null_resource.build.id
  }
}

resource "null_resource" "integration_tests" {
  count = var.run_integration_tests ? 1 : 0

  triggers = {
    build = null_resource.build.id
  }
}

resource "null_resource" "publish" {
  triggers = {
    version           = var.version_tag
    unit_tests        = null_resource.unit_tests.id
    integration_tests = join(",", null_resource.integration_tests[*].id)
  }
}

resource "null_resource" "deploy" {
  for_each = { for index, target in var.deploy_targets : target => index }

  triggers = {
    artifact = null_resource.publish.id
    target   = each.key
    order    = each.value
  }
}

output "stages" {
  description = "Stages in the order they run."
  value = concat(
    ["build", "unit-tests"],
    var.run_integration_tests ? ["integration-tests"] : [],
    ["publish"],
    [for target in var.deploy_targets : "deploy-${target}"],
  )
}

output "artifact" {
  description = "What the pipeline publishes."
  value       = "ghcr.io/acme/${var.pipeline_name}:${var.version_tag}"
}
