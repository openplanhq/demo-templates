# openplan demo templates

Terraform modules used by openplan's screenshots and demo environment.

Every module here plans and applies **without any cloud credentials** — they use
only the built-in `terraform_data` resource and the `random`, `tls`, `local`,
`time`, `null`, `archive` and `cloudinit` providers, none of which talk to a
cloud API. That is deliberate: it means anyone can clone openplan, register
these, and watch a real plan/apply cycle run end to end without signing up for
an AWS account first.

Most modules are shaped like the infrastructure they are named after — a VPC's
subnets are real `cidrsubnet()` arithmetic, a certificate authority really signs
its intermediate — but the resources themselves are `terraform_data`, so
nothing is created anywhere but the state file.

Each module is a normal Terraform root module. Point openplan at the repository
and a `root_path`, and it infers the input variables from the code. Each has a
`template.yaml` beside it with the name, description and tags openplan shows.

## Registering them with openplan

`scripts/register.mjs` signs in to openplan the way a browser does and registers
every module that isn't registered yet. It needs Node 20 or newer and nothing
else. On openplan's local stack, sign in as Dex's static user:

```bash
export OPENPLAN_USER=admin@openplan.local
export OPENPLAN_PASS=<its password, in openplan's docs/authentication.md>
node scripts/register.mjs
```

openplan clones the modules from GitHub, not from this checkout, so push before
registering. `--only vpc-network,redis-cache` registers just those, `--sync`
registers everything again to pick up new commits, `--dry-run` lists what would
be registered, and `--url`, `--repo` and `--ref` point it elsewhere. The top of
the script lists every flag.

## Modules

| Module | What it creates |
| --- | --- |
| **Starter** | |
| `modules/random-id` | A random pet name, a random hex id, and a random password |
| `modules/tls-certificate` | A self-signed certificate and its private key |
| `modules/config-bundle` | A rendered JSON config file written to disk |
| `modules/service-graph` | A `terraform_data` graph: database -> cache -> api -> web |
| **Networking** | |
| `modules/vpc-network` | A network with public and private subnets per zone, and NAT gateways |
| `modules/subnet-plan` | An address space carved into named subnets, with gateways and host counts |
| `modules/dns-zone` | A DNS zone and a list of records |
| `modules/load-balancer` | A load balancer with a listener and target group per port |
| `modules/cdn-distribution` | A CDN distribution, its TLS certificate and per-path cache behaviours |
| `modules/vpn-gateway` | A VPN gateway with a tunnel and generated pre-shared key per peer |
| `modules/firewall-rules` | A security group and its ingress rules |
| `modules/service-mesh` | A mesh CA and a signed mTLS certificate per service |
| **Compute** | |
| `modules/kubernetes-cluster` | A control plane that takes 15 seconds to come up, then its node pools |
| `modules/node-pool` | A pool of worker nodes with labels and taints |
| `modules/vm-fleet` | Virtual machines with generated hostnames and cloud-init user data |
| `modules/autoscaling-group` | A launch template, an autoscaling group and a CPU scaling policy |
| `modules/serverless-function` | A function zipped from inline source, with an HTTP trigger |
| `modules/batch-jobs` | A job queue and scheduled job definitions |
| `modules/container-service` | A container task definition, service and log groups |
| **Data and storage** | |
| `modules/postgres-database` | A Postgres instance, generated admin password and per-app databases |
| `modules/mysql-replica-set` | A MySQL primary, read replicas across zones and a reader endpoint |
| `modules/redis-cache` | A sharded Redis cluster with hash slot ranges and an auth token |
| `modules/object-storage-bucket` | A uniquely named bucket with versioning and lifecycle rules |
| `modules/data-warehouse` | Analytics datasets and their partitioned tables |
| `modules/kafka-cluster` | Kafka brokers and topics, checked against the broker count |
| `modules/search-cluster` | A search cluster with master and data nodes and index templates |
| `modules/backup-plan` | A backup vault, scheduled rules and when each first runs |
| **Messaging** | |
| `modules/message-queue` | Work queues, each with a dead-letter queue |
| `modules/pubsub-topics` | Topics and their pull or push subscriptions |
| `modules/event-bus` | An event bus with routing rules fanning out to targets |
| **Security and identity** | |
| `modules/iam-roles` | Roles with trust and permission policy documents |
| `modules/service-accounts` | Service accounts with access keys that rotate on a schedule |
| `modules/secrets-vault` | Generated secrets in a vault, versioned by hash |
| `modules/ssh-keypair` | An SSH key pair and its fingerprint |
| `modules/certificate-authority` | A root CA and the intermediate CA it signs |
| `modules/kms-keys` | Encryption keys with aliases and rotation schedules |
| `modules/waf-policy` | A WAF policy with managed rules, a rate limit and block lists |
| `modules/oidc-clients` | OIDC client registrations, with secrets for confidential clients |
| **Observability** | |
| `modules/monitoring-dashboard` | A dashboard rendered from a list of panels |
| `modules/alert-rules` | A Prometheus alerting rule group with runbook links |
| `modules/log-pipeline` | Log sources, processors and sinks in dependency order |
| `modules/uptime-checks` | Synthetic HTTPS checks from several regions |
| `modules/slo-budget` | An availability objective turned into an error budget |
| **Applications and delivery** | |
| `modules/static-website` | A bucket, certificate, CDN and DNS record for a static site |
| `modules/web-application` | A load balancer, API servers, cache and database |
| `modules/api-gateway` | An API gateway with routes, a stage and usage plans |
| `modules/feature-flags` | Feature flags with percentage rollouts and a kill switch |
| `modules/github-repository` | A repository with branch protection, team access and labels |
| `modules/ci-pipeline` | Pipeline stages that re-run in order when the version changes |
| **Operations** | |
| `modules/environment-bootstrap` | A naming prefix and standard tags for a new environment |
| `modules/tenant-onboarding` | A namespace, quota, storage prefix and admin invite per tenant |
| `modules/maintenance-window` | A weekly maintenance window and when it next opens |
| **For demos** | |
| `modules/long-running-apply` | An apply that takes as long as you ask, to watch logs or cancel |
| `modules/failing-apply` | An apply that fails part-way on purpose, and recovers when told to |
