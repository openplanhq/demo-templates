# A fixture for openplanhq/openplan#135: one variable of every complex type,
# a template-shipped auto.tfvars the stack's value must beat, and a string
# holding an interpolation sequence. No providers, so plan needs no cloud.

variable "names" {
  type = list(string)
}

variable "labels" {
  type = map(string)
}

variable "network" {
  type = object({
    cidr = string
    azs  = list(string)
    tags = optional(map(string))
  })
}

variable "zones" {
  type = set(string)
}

variable "pair" {
  type = tuple([string, number])
}

variable "anything" {
  type = any
}

variable "untyped" {}

variable "greeting" {
  type = string
}

# terraform.auto.tfvars sets this; the stack's value must win.
variable "overridden" {
  type = list(string)
}

resource "terraform_data" "echo" {
  input = {
    names      = var.names
    labels     = var.labels
    network    = var.network
    zones      = var.zones
    pair       = var.pair
    anything   = var.anything
    untyped    = var.untyped
    greeting   = var.greeting
    overridden = var.overridden
  }
}

output "names" { value = jsonencode(var.names) }
output "labels" { value = jsonencode(var.labels) }
output "network" { value = jsonencode(var.network) }
output "zones" { value = jsonencode(var.zones) }
output "pair" { value = jsonencode(var.pair) }
output "anything" { value = jsonencode(var.anything) }
output "untyped" { value = jsonencode(var.untyped) }
output "greeting" { value = var.greeting }
output "overridden" { value = jsonencode(var.overridden) }
