terraform {
  required_version = ">= 1.9"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "bucket_prefix" {
  description = "Start of the bucket name. A random suffix makes it globally unique."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,40}$", var.bucket_prefix))
    error_message = "bucket_prefix must be 3-41 lowercase alphanumerics or dashes."
  }
}

variable "versioning" {
  description = "Keep every version of every object."
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "Per-prefix rules: move to cold storage after some days, delete after more."
  type = list(object({
    prefix          = string
    transition_days = optional(number)
    expiration_days = optional(number)
  }))
  default = [
    { prefix = "logs/", transition_days = 30, expiration_days = 365 },
    { prefix = "tmp/", expiration_days = 7 },
  ]
}

variable "force_destroy" {
  description = "Allow destroying the bucket while it still holds objects."
  type        = bool
  default     = false
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "terraform_data" "bucket" {
  input = {
    name          = "${var.bucket_prefix}-${random_id.suffix.hex}"
    versioning    = var.versioning
    encryption    = "AES256"
    public_access = "blocked"
    force_destroy = var.force_destroy
  }
}

resource "terraform_data" "lifecycle_rule" {
  for_each = { for rule in var.lifecycle_rules : rule.prefix => rule }

  input = {
    bucket          = terraform_data.bucket.output.name
    prefix          = each.key
    transition_days = each.value.transition_days
    expiration_days = each.value.expiration_days
  }
}

output "bucket_name" {
  description = "The bucket's globally unique name."
  value       = terraform_data.bucket.output.name
}

output "bucket_url" {
  description = "Where the bucket is addressed."
  value       = "s3://${terraform_data.bucket.output.name}"
}
