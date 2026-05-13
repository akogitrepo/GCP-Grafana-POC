# Architecture

This document mirrors the original specification section-by-section and points to the concrete artifacts that implement each piece.

## 1. Project structure & governance

- New GCP project under an org folder, billing linked, default network disabled. See [`terraform/modules/project/`](../terraform/modules/project/).
- Required APIs are enabled in one place (`activate_apis` variable) to make adding/removing capabilities a one-line change.
- VPC with two regional subnets (one per cluster) and dedicated secondary ranges for Pods and Services so the clusters are VPC-native. See [`terraform/modules/network/`](../terraform/modules/network/).
- Cloud NAT per region for outbound egress; Private Service Access for Cloud SQL / Memorystore; IAP-SSH firewall for break-glass to nodes.
- Persona IAM (`Dev`, `Ops`, `SRE`, `CI/CD`) configured via the `personas` variable. CI/CD has its own service account. See [`terraform/modules/iam/`](../terraform/modules/iam/).
- Centralized logging + monitoring sinks live in [`terraform/modules/observability/`](../terraform/modules/observability/).

Shared VPC is out of the default module set; in an enterprise where networking is centrally managed, switch the `network` module call for a host-project lookup and pass the `subnetwork` self-link to each `gke-cluster` module.

## 2. GKE cluster architecture

Two clusters, one per region. Identical modules with different inputs:

| Setting              | Primary (us-central1)  | Secondary (us-east1)   |
|----------------------|------------------------|------------------------|
| Mode                 | GKE Standard (regional)| GKE Standard (regional)|
| Networking           | VPC-native, private    | VPC-native, private    |
| Workload Identity    | Enabled                | Enabled                |
| Managed Prometheus   | Enabled                | Enabled                |
| Release channel      | REGULAR                | REGULAR                |
| Binary Authorization | enforce-policy         | enforce-policy         |
| Node pools           | `system`, `apps`       | `system`, `apps`       |

Why regional, not Autopilot? Two reasons: (a) we still need to tune node pools for the workload mix (system add-ons + ingress) and Autopilot pricing per-pod gets expensive at scale; (b) regional Standard gives us the same SLA without Autopilot's API surface restrictions. The module is structured so swapping to Autopilot is a localized change. See [`docs/design-decisions.md`](design-decisions.md).

## 3. Application deployment

Both apps follow the same shape: stateless, multi-pod Deployment, ConfigMap-driven config, Workload Identity for downstream auth, HPA on CPU + memory, PDB (`minAvailable: 2`), topology spread across zones, dependency-aware `/readyz`, graceful drain on SIGTERM. See [`kubernetes/apps/`](../kubernetes/apps/) and [`apps/`](../apps/).

`web-app-a` is purely stateless (Cloud SQL HA at most). `web-app-b` adds Pub/Sub + Memorystore — included in its `/readyz` so a Redis outage takes a pod out of rotation without restarting it.

## 4. Customer traffic flow

Implemented by:

- Cloud DNS A-record → global anycast IP (Terraform: `module.mci.global_ip_address`).
- Google-managed SSL cert covering all hostnames (Terraform: `module.mci.managed_cert_name`).
- `MultiClusterIngress` + `MultiClusterService` (see [`kubernetes/ingress/`](../kubernetes/ingress/)) applied to the config-cluster.
- `BackendConfig` per Service ties in Cloud Armor + LB health checks + structured logging.
- Path routing: `/a/*` → `web-app-a`, `/b/*` → `web-app-b`, `/*` → `web-app-a` (the catch-all).

The flow is described step-by-step in the [README](../README.md#3-end-to-end-traffic-flow) and visually in [`docs/traffic-flow.mmd`](traffic-flow.mmd).

## 5. Observability

Every cluster ships:

- Container logs + Kubernetes events → Cloud Logging (via the default GKE logging agent).
- Metrics → Cloud Monitoring with Managed Prometheus + Pod-level kube-state metrics.
- Traces → Cloud Trace (apps emit OTel spans; or rely on the LB and ASM telemetry hooks).
- Profiles → Cloud Profiler.
- Errors → Error Reporting aggregates structured exceptions.

A sink in `terraform/modules/observability` exports logs to BigQuery (`platform_logs`). On top of those tables we materialize four views (see [`observability/bigquery/views.sql`](../observability/bigquery/views.sql)) that back the four required Grafana panels:

1. **Application errors per minute** (per service)
2. **Pod restarts by namespace**
3. **Request latency p50 / p95 / p99**
4. **Container CPU & memory**

The Grafana dashboard JSON is at [`observability/grafana/dashboards/platform-overview.json`](../observability/grafana/dashboards/platform-overview.json).

Uptime checks + a 5xx-rate alert are configured by `module.observability`. Add more by extending `google_monitoring_alert_policy` blocks.

## 6. High availability & disaster recovery

- Two regional clusters; MCI auto-fails over within seconds when health checks drop.
- Cloud SQL HA + cross-region read replicas for any persisted state.
- Memorystore Standard tier with HA + cross-region async replication if needed.
- Artifact Registry is multi-regional (`us`) so image pull works during a regional outage.
- Terraform state in GCS with versioning + 7-day soft-delete.
- etcd backed up by GKE's managed control plane (no operator action needed).

## 7. Security

- Workload Identity binds KSAs → GSAs; no JSON keys in pods.
- Secret Manager for all secrets, mounted via CSI driver (extension: see `kubernetes/platform/` for the CSI install).
- Private nodes; IAP-SSH for break-glass only.
- Cloud Armor preconfigured OWASP rules + adaptive protection.
- Binary Authorization in enforce mode with a Cloud Build attestor.
- KMS-encrypted persistent disks.
- Default-deny NetworkPolicy in each app namespace; explicit allows for in-cluster traffic + LB health checks + 443 egress.

## 8. Deliverables status

| Deliverable                                        | Where                                                |
|----------------------------------------------------|------------------------------------------------------|
| Terraform reproducing entire setup                 | [`terraform/`](../terraform/)                        |
| Architecture diagram                               | [`docs/architecture-diagram.svg`](architecture-diagram.svg) + Mermaid sources |
| Step-by-step setup instructions                    | [`README.md`](../README.md), [`terraform/README.md`](../terraform/README.md) |
| BigQuery schema + sample queries                   | [`observability/bigquery/`](../observability/bigquery/) |
| Design decisions & rationale                       | [`docs/design-decisions.md`](design-decisions.md)    |
| Sample apps + Dockerfiles                          | [`apps/`](../apps/)                                  |
| CI/CD                                              | [`cicd/`](../cicd/)                                  |
| Runbook                                            | [`docs/runbook.md`](runbook.md)                      |
