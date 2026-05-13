# Project plan — feasibility, scope and timeline

## Feasibility — yes, fully buildable

Every capability in the spec is GA on Google Cloud today (regional GKE Standard, VPC-native networking, Multi-Cluster Ingress via GKE Hub, Cloud Armor, Managed Prometheus, Cloud Logging → BigQuery sinks, Workload Identity, Binary Authorization, Artifact Registry). The Terraform providers (`hashicorp/google` 5.x) cover all of it without resorting to gcloud one-shots.

The only items that need real-world wait time (not engineering effort) are:

| Wait                                               | Typical duration            |
|----------------------------------------------------|-----------------------------|
| Org policy / billing approval for a new project    | 0.5–2 business days         |
| Managed SSL cert ACME validation                   | 15–60 minutes after DNS     |
| MCI propagation (NEGs registered + LB programmed)  | 5–15 minutes                |
| Binary Authorization attestor first-time setup     | ~30 minutes (manual KMS)    |

Plan these into the calendar separately from engineering hours.

## Effort estimate

| Workstream                                                        | Engineer-days  |
|-------------------------------------------------------------------|----------------|
| 1. Project / IAM / VPC / NAT / firewall (Terraform)               | 1.5            |
| 2. GKE clusters x 2 with Workload Identity + node pools           | 2.0            |
| 3. Multi-Cluster Ingress: fleet, MCI, MCS, global IP, cert        | 1.5            |
| 4. Cloud Armor policy + BackendConfig wiring                      | 0.5            |
| 5. Artifact Registry + Binary Authorization                       | 0.5            |
| 6. App skeletons + Dockerfiles + health/ready/metrics             | 1.0            |
| 7. Kubernetes manifests (Kustomize: base + 2 overlays per app)    | 1.5            |
| 8. CI/CD: Cloud Build + GitHub Actions + WIF                      | 1.5            |
| 9. Log sink, BigQuery dataset + views                             | 1.0            |
| 10. Grafana provisioning + 4-panel dashboard                      | 1.0            |
| 11. Alerts, uptime checks, runbook                                | 0.5            |
| 12. Hardening (NetworkPolicy, PDB, PSS, drain logic)              | 1.0            |
| 13. End-to-end smoke test (failover, image rollback, DB recovery) | 1.0            |
| 14. Documentation + design-decisions write-up                     | 1.0            |
| **Total**                                                         | **~15.5 days** |

## Calendar timeline

| Crew                                                | Calendar days  |
|-----------------------------------------------------|----------------|
| **Solo engineer**, focused, prior GCP+GKE+TF skill  | 15–20 days     |
| **2 engineers** (1 platform, 1 app/obs)             | 10–12 days     |
| **3+ engineers** with parallel workstreams          | 7–9 days       |

Add buffer of **~3 calendar days** for the org/billing/DNS waits above when the project starts cold.

## Suggested sprint breakdown (2-person crew, 2-week sprint)

### Sprint week 1
- Day 1–2: Bootstrap (state bucket, WIF), project + VPC + IAM, Artifact Registry, Cloud Armor.
- Day 3: Two GKE clusters up; node pools sized; Workload Identity verified end-to-end.
- Day 4: Multi-Cluster Ingress fleet registration; global IP and managed cert reserved.
- Day 5: Apps containerized; `BackendConfig`, NEGs, NetworkPolicies; first end-to-end request lands on a pod.

### Sprint week 2
- Day 6: Kustomize overlays, HPA/PDB/topology-spread, drain logic; SLO smoke test.
- Day 7: CI/CD (Cloud Build + GitHub Actions); deploy-on-merge to dev cluster pair.
- Day 8: Log sink → BigQuery; views; Grafana datasource + dashboard.
- Day 9: Alerts, uptime checks, DR drill (kill primary cluster's pods, confirm MCI failover within target).
- Day 10: Documentation, runbook, design-decisions; handover demo.

## Out of scope by default (call out before commitment)

- **Anthos Service Mesh / mTLS east-west** — module-friendly to add but adds ~3 days for install + workload migration. Wire-frame is left in `kubernetes/apps/*/base` (`istio-injection: enabled` namespace label).
- **Shared VPC** with a centrally-managed host project — adds ~1 day for cross-project IAM and subnet sharing.
- **Hybrid / on-prem fleet** — requires Connect Gateway + private agents. Not included.
- **Synthetic monitoring at scale** — beyond the single uptime check. Use a 3rd-party (Datadog Synthetics, Pingdom) if needed.

## Risks

| Risk                                                            | Mitigation                                                |
|-----------------------------------------------------------------|-----------------------------------------------------------|
| Managed SSL cert stuck in PROVISIONING                          | Confirm DNS A-record propagates before claiming "done"     |
| MCI features disabled at the project level                      | `gke-hub` + `multiclusteringress` APIs already in module  |
| BinAuth enforce blocks first deploy                             | Run dry-run mode for the first 24h, then flip to enforce  |
| BigQuery sink hits quota on log volume                          | Filter aggressively (`severity>=INFO` in apps); partitioning ON |
| Region-pair latency hurts user experience                       | Add a 3rd cluster in eu-west1 — MCI handles N clusters    |
