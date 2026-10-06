terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "fail_on_apply" {
  description = "Fail the health check during apply."
  type        = bool
  default     = true
}

variable "failure_message" {
  description = "What the failed health check reports."
  type        = string
  default     = "health check failed: upstream returned 503"
}

resource "random_id" "deployment" {
  byte_length = 4
}

resource "terraform_data" "database" {
  input = {
    name = "db-${random_id.deployment.hex}"
  }
}

resource "terraform_data" "service" {
  input = {
    name     = "svc-${random_id.deployment.hex}"
    database = terraform_data.database.output.name
  }
}

# The condition depends on a value only known once applied, so the plan
# passes and the failure lands mid-apply, after the resources above exist.
resource "terraform_data" "health_check" {
  input = {
    target = terraform_data.service.output.name
  }

  lifecycle {
    postcondition {
      condition     = !var.fail_on_apply || self.output.target == ""
      error_message = var.failure_message
    }
  }
}

output "service" {
  description = "The service that passed its health check."
  value       = terraform_data.health_check.output.target
}
