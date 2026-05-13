# Design decisions

## Two regional GKE Standard clusters, not one regional + one zonal

Two regional clusters means each cluster has its control plane replicated across 3 zones in its region. A regional+zonal mix saves money but creates an asymmetric failure mode where the zonal cluster's control plane is single-zone and can disappear during a zonal maintenance event. The cost difference is small in dev because we keep min-nodes low.

## Standard, not Autopilot

Autopilot is excellent for greenfield app teams but constrains node-pool taints, daemonsets, and Linux kernel tuning, all of which we use here (Calico, system-only taint, dedicated app pool). Standard with `autoscaling` on both pools gives the same operator ergonomics without the constraints. The `gke-cluster` module is structured so swapping to Autopilot is a localized change.

## Multi-Cluster Ingress, not GCLB+independent ingress controllers

MCI gives us:
- one global IP, one managed cert, one Cloud Armor policy
- proximity routing baked in
- failover on health-check loss (no DNS shenanigans, no client retry burden)
- fleet visibility for free

The alternative — one regional ingress per cluster behind a DNS-level routing service — costs more (multiple IPs, multiple certs), takes longer to fail over (TTL-bound), and gives an operator a worse story when something breaks.

We left Anthos Service Mesh as an opt-in (`istio-injection: enabled` on the namespaces) so mTLS + traffic splitting can be added later without changing the topology.

## BigQuery as the Grafana data source

Reasons:
1. The spec explicitly asks for BigQuery + Grafana.
2. Cloud Logging → BigQuery is a managed export with zero infra to run.
3. The same data backs ad-hoc forensic queries (logs analytics) — we don't have to choose between "good dashboards" and "good investigations".
4. The BigQuery Grafana plugin is GA and supports parameterized queries.

Tradeoffs: query latency is higher than Loki or Cortex (several seconds), and per-scan cost can grow. We partition by `timestamp` (Cloud Logging does this automatically), expose **views** with pre-aggregations, and set `default_table_expiration_ms` to 60 days by default. For sub-second metric dashboards, Managed Prometheus is the right tool — we expose it but keep the four required panels on BigQuery as specified.

## Kustomize, not Helm

Two apps, no charts to publish, no parameter explosion. Kustomize's base-plus-overlays gives us per-region image pinning, region tags in env config, and ServiceAccount-annotation swaps without templating. If the platform later needs to publish reusable charts, swap in Helm; the manifests already separate base + overlays cleanly.

## Workload Identity Federation for CI/CD, not service-account keys

Keys leak; WIF doesn't. GitHub OIDC + WIF gives ephemeral, repo-scoped access. Bootstrap script (`scripts/bootstrap.sh`) creates the pool and provider in one shot.

## Cloud Armor on the LB, not in-cluster WAF

A WAF inside the cluster (e.g. ModSecurity sidecar) means every pod pays the latency and the egress already escaped Google's edge before the deny. Cloud Armor evaluates at the LB, before traffic touches our cluster — cheaper, faster, and the rule set is managed.

## Binary Authorization in **enforce**, with a dry-run break-glass

Enforce blocks unattested images at admission time. We pair it with a Cloud Build attestor so anything our pipeline builds is automatically allowed; emergency-mode is `gcloud beta container binauthz policy import` to flip to dry-run.

## VPC-native (alias IPs), not routes-based

Required by MCI and by every modern GKE feature; also gives us non-overlapping Pod and Service CIDRs that don't pollute the VPC routing table. The subnet design assigns /14 for Pods to support up to 256k pods per cluster — generous, but cheap, and removes a future re-IP migration.

## Topology-spread + PDB + dependency-aware readyz, not raw replica count

A 6-replica deployment that all sit on one node provides 0 availability. Topology-spread across zones, `minAvailable: 2` PDB, and SIGTERM drain in the app give us actual zero-downtime rollouts and zonal-evacuation behavior.

## Two ConfigMaps + WI, no env-baked secrets

Region, log level, and app name are environment config (ConfigMap). Anything sensitive (DB passwords, OAuth client secrets) goes to Secret Manager and is read via Workload Identity at startup, never baked into the image.
