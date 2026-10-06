terraform {
  required_version = ">= 1.9"
}

# Shaped like the integrations/github provider's resources, but expressed with
# terraform_data so no GitHub token is needed.

variable "name" {
  description = "Repository name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,100}$", var.name))
    error_message = "name may contain letters, digits, dots, dashes and underscores."
  }
}

variable "visibility" {
  description = "Who can see the repository."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private", "internal"], var.visibility)
    error_message = "visibility must be public, private or internal."
  }
}

variable "required_checks" {
  description = "Status checks that must pass before merging."
  type        = list(string)
  default     = ["build", "test", "lint"]
}

variable "required_approvals" {
  description = "Approving reviews needed to merge."
  type        = number
  default     = 1

  validation {
    condition     = var.required_approvals >= 0 && var.required_approvals <= 6
    error_message = "required_approvals must be between 0 and 6."
  }
}

variable "team_permissions" {
  description = "Teams and the permission each has."
  type        = map(string)
  default = {
    platform = "admin"
    backend  = "push"
    support  = "pull"
  }

  validation {
    condition     = alltrue([for permission in values(var.team_permissions) : contains(["pull", "triage", "push", "maintain", "admin"], permission)])
    error_message = "Permissions must be pull, triage, push, maintain or admin."
  }
}

variable "labels" {
  description = "Issue labels and their colours."
  type        = map(string)
  default = {
    bug                = "d73a4a"
    enhancement        = "a2eeef"
    documentation      = "0075ca"
    "good first issue" = "7057ff"
  }
}

resource "terraform_data" "repository" {
  input = {
    name                   = var.name
    visibility             = var.visibility
    default_branch         = "main"
    delete_branch_on_merge = true
    allow_squash_merge     = true
    allow_merge_commit     = false
  }
}

resource "terraform_data" "branch_protection" {
  input = {
    repository         = terraform_data.repository.output.name
    pattern            = "main"
    required_checks    = var.required_checks
    required_approvals = var.required_approvals
    enforce_admins     = false
  }
}

resource "terraform_data" "team_access" {
  for_each = var.team_permissions

  input = {
    repository = terraform_data.repository.output.name
    team       = each.key
    permission = each.value
  }
}

resource "terraform_data" "label" {
  for_each = var.labels

  input = {
    repository = terraform_data.repository.output.name
    name       = each.key
    color      = each.value
  }
}

output "clone_url" {
  description = "Where the repository is cloned from."
  value       = "git@github.com:acme/${var.name}.git"
}
