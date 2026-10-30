# Fixture for openplan's sensitive variables (openplanhq/openplan#439). No
# provider, so a run downloads nothing. The outputs are hashes, never the
# values: a run's log proves the value arrived intact without showing it.

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Required. Set it as the secret TF_VAR_db_password."
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "A multi-line PEM key. Set it as the secret TF_VAR_ssh_private_key."
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Something to apply, so the hashes come from an applied resource and a
# rotated secret shows up as a change.
resource "terraform_data" "proof" {
  input = {
    db_password     = sha256(var.db_password)
    ssh_private_key = sha256(var.ssh_private_key)
  }
}

output "db_password_sha256" {
  value = nonsensitive(terraform_data.proof.output.db_password)
}

output "ssh_private_key_sha256" {
  value = nonsensitive(terraform_data.proof.output.ssh_private_key)
}

output "region" {
  value = var.region
}
