# Terraform — GCP Platform

This directory provisions the entire GCP platform: project, VPC, two GKE clusters, IAM, Cloud Armor, Artifact Registry, Multi-Cluster Ingress, and observability sinks.

## Layout

```
terraform/
├── envs/
│   ├── dev/    # composes the modules for the dev project
│   └── prod/   # composes the modules for the prod project
└── modules/
    ├── project/                  # Project + APIs
    ├── network/                  # VPC, subnets, NAT, FW, PSA
    ├── iam/                      # Personas + Workload Identity
    ├── gke-cluster/              # Reusable GKE Standard cluster
    ├── multi-cluster-ingress/    # Fleet, MCI, global IP, managed cert
    ├── artifact-registry/        # Docker repo + cleanup policy
    ├── cloud-armor/              # Edge WAF policy
    └── observability/            # BQ log sink, alerts, uptime
```

## Order of operations

The modules wire dependencies automatically; you only need to run `terraform apply` in `envs/<env>/`. Internally Terraform brings up:

1. `project` → enables required APIs.
2. `network` → VPC, two regional subnets with secondary ranges, Cloud NAT, PSA.
3. `iam`, `artifact_registry`, `cloud_armor`, `observability` → run in parallel once project is up.
4. `gke_primary`, `gke_secondary` → two regional clusters, both private and VPC-native.
5. `mci` → registers both clusters into a fleet, enables MCI/MCS, reserves the global IP and managed cert.

## Bootstrap

```sh
# One-time: create the TF state bucket + grant access to the bootstrap user.
./../scripts/bootstrap.sh myorg-tfstate

# Replace REPLACE_ME-tfstate in envs/<env>/backend.tf with the bucket name above.

cd envs/dev
cp terraform.tfvars.example terraform.tfvars   # fill in values
terraform init
terraform plan -out=plan.out
terraform apply plan.out
```

## State

Remote state is stored in GCS. Lock contention is handled by GCS object generation. Use one state file per environment; do not share state between dev and prod.

## Adding a new env

Copy `envs/dev/` → `envs/<name>/`, update CIDRs (no overlaps), tweak sizing, and run apply. Each env should land in its own GCP project for blast-radius isolation.
