# openplan demo templates

Terraform modules used by openplan's screenshots and demo environment.

Every module here plans and applies **without any cloud credentials** — they use
only the built-in `terraform_data` resource and the `random`, `tls` and `local`
providers, none of which talk to a cloud API. That is deliberate: it means
anyone can clone openplan, register these, and watch a real plan/apply cycle
run end to end without signing up for an AWS account first.

| Module | What it creates |
| --- | --- |
| `modules/random-id` | A random pet name, a random hex id, and a random password |
| `modules/tls-certificate` | A self-signed certificate and its private key |
| `modules/config-bundle` | A rendered JSON config file written to disk |
| `modules/service-graph` | A `terraform_data` graph: database -> cache -> api -> web |

Each module is a normal Terraform root module. Point openplan at the repository
and a `root_path`, and it infers the input variables from the code.
