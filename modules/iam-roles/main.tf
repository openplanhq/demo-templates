terraform {
  required_version = ">= 1.9"
}

variable "roles" {
  description = "Roles by name: who may assume them, the actions they allow and on what."
  type = map(object({
    trusted_principals = list(string)
    actions            = list(string)
    resources          = optional(list(string), ["*"])
    max_session_hours  = optional(number, 1)
  }))
  default = {
    ci-deployer = {
      trusted_principals = ["ci.demo.example"]
      actions            = ["deploy:Create*", "deploy:Update*", "storage:PutObject"]
      resources          = ["arn:demo:deploy:::app/*", "arn:demo:storage:::artifacts/*"]
    }
    read-only-auditor = {
      trusted_principals = ["sso.demo.example"]
      actions            = ["*:Get*", "*:List*", "*:Describe*"]
      max_session_hours  = 8
    }
  }

  validation {
    condition     = alltrue([for role in values(var.roles) : role.max_session_hours >= 1 && role.max_session_hours <= 12])
    error_message = "max_session_hours must be between 1 and 12."
  }
}

variable "permissions_boundary" {
  description = "A boundary policy every role is capped by. Empty for none."
  type        = string
  default     = ""
}

resource "terraform_data" "role" {
  for_each = var.roles

  input = {
    name                 = each.key
    max_session_seconds  = each.value.max_session_hours * 3600
    permissions_boundary = var.permissions_boundary == "" ? null : var.permissions_boundary
    trust_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = each.value.trusted_principals }
      }]
    })
  }
}

resource "terraform_data" "policy" {
  for_each = var.roles

  input = {
    role = terraform_data.role[each.key].output.name
    document = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = each.value.actions
        Resource = each.value.resources
      }]
    })
  }
}

output "role_arns" {
  description = "Each role's identifier."
  value       = { for name, role in terraform_data.role : name => "arn:demo:iam::000000000000:role/${role.output.name}" }
}

output "wildcard_roles" {
  description = "Roles whose policy applies to every resource."
  value       = sort([for name, role in var.roles : name if contains(role.resources, "*")])
}
