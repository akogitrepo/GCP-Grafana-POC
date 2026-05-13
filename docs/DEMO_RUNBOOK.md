# Demo runbook — apply the stack end-to-end

This walks you through bringing the full platform up on real GCP. Two passes are intentional:

- **Pass 1: Zero-cost validation** — `terraform validate` + `plan`, no resources touched, ~10 min.
- **Pass 2: Full apply** — actually creates a project with everything in it, ~45 min, ~$170–280/day at dev sizing while it's up.

Run from your Mac terminal in the repo root. **Tear down when done** (last section).

---

## 0. Pre-flight checklist

```sh
# Check your tooling
gcloud --version          # need >= 470
terraform -version        # need >= 1.6
kubectl version --client  # any reasonably recent
which kustomize           # any
docker --version

# Authenticate gcloud (interactive, one-time)
gcloud auth login
gcloud auth application-default login

# Figure out your starting numbers
gcloud organizations list                       # note the ID
gcloud billing accounts list                    # note an OPEN account
gcloud resource-manager folders list --organization=<ORG_ID>  # pick a folder or skip
```

You need: **org admin** or **folder admin** on the parent, **billing user** on the billing account, and the GCP APIs you'll enable below need to be available in your org policy.

---

## 1. Pass 1 — validation (free, ~10 min)

### 1.1 Bootstrap the Terraform state bucket

The bucket has to exist *before* terraform can `init` against the GCS backend. Pick a globally-unique name.

```sh
cd "/Users/abojha/Anthropic-POC/GCP-Grafana/GCP - Grafana"

BOOTSTRAP_PROJECT=<existing project where the bucket lives>
BUCKET=<unique-name>-tfstate

./scripts/bootstrap.sh "$BUCKET" "$BOOTSTRAP_PROJECT"
```

That creates the versioned state bucket and, optionally, the Workload Identity Federation pool for GitHub Actions.

### 1.2 Wire the backend

```sh
# Replace the placeholder in BOTH env stacks
sed -i '' "s/REPLACE_ME-tfstate/$BUCKET/" terraform/envs/dev/backend.tf
sed -i '' "s/REPLACE_ME-tfstate/$BUCKET/" terraform/envs/prod/backend.tf
```

### 1.3 Fill in the dev tfvars

```sh
cd terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:

- `project_id` — globally unique, e.g. `mydemo-platform-2026-05`
- `billing_account` — from `gcloud billing accounts list`
- `folder_id` — set to `null` for no folder, or `"folders/123456789012"`
- `hostnames` — list of public hostnames *or* set to `["demo.example.com"]` and skip TLS
- `alert_emails` — your email if you want the 5xx alert wired up

### 1.4 Validate + plan (NO resources created yet)

```sh
terraform init
terraform fmt -check -recursive ../../
terraform validate
terraform plan -out=plan.out
```

`terraform plan` will print every resource it would create — typically **~85 resources** for the dev env. If the plan output looks sane and validates clean, you're good for Pass 2.

> **Hard stop checkpoint.** If validation fails because of an org policy (e.g. "Domain restricted sharing" or "Allowed external IPs"), fix the policy first or have your org admin grant exemption to the project. Common ones to watch for: `iam.allowedPolicyMemberDomains`, `compute.requireShieldedVm`, `compute.vmExternalIpAccess`.

---

## 2. Pass 2 — full apply (real resources, real $)

### 2.1 Apply

```sh
# Same directory as Pass 1
terraform apply plan.out
```

Approximate timing per phase:

| Phase                                        | Wall-clock |
|----------------------------------------------|------------|
| Project create + APIs enable                 | 2–3 min    |
| VPC + subnets + NAT + firewall               | 1 min      |
| IAM + Artifact Registry + Cloud Armor        | 1 min      |
| **GKE primary** (regional, both pools)       | 10–14 min  |
| **GKE secondary** (regional, both pools)     | 10–14 min  |
| Fleet membership + MCI/MCS features          | 2–3 min    |
| Global IP + managed cert (status: PROVISIONING) | < 1 min |
| Cloud Logging sink + BQ dataset              | 1 min      |
| **Total**                                    | **~40 min**|

Both GKE clusters spin up in parallel, so total isn't 28 min for that phase — it's whichever is slower (~14 min).

### 2.2 Connect kubectl to both clusters

```sh
PROJECT=$(terraform output -raw project_id)
gcloud container clusters get-credentials gke-primary-dev   --region us-central1 --project $PROJECT
gcloud container clusters get-credentials gke-secondary-dev --region us-east1    --project $PROJECT

# Rename contexts for readability
kubectl config rename-context gke_${PROJECT}_us-central1_gke-primary-dev   primary
kubectl config rename-context gke_${PROJECT}_us-east1_gke-secondary-dev    secondary

# Apply platform-wide manifests to BOTH clusters
for ctx in primary secondary; do
  kubectl --context $ctx apply -f ../../../kubernetes/platform/
done
```

### 2.3 Build and push the app images

```sh
cd ../../../   # back to repo root
REPO=$(terraform -chdir=terraform/envs/dev output -raw artifact_registry_url)
gcloud auth configure-docker us-docker.pkg.dev --quiet

for APP in web-app-a web-app-b; do
  docker build -t "$REPO/$APP:v1.0.0" -t "$REPO/$APP:latest" apps/$APP
  docker push --all-tags "$REPO/$APP"
done
```

### 2.4 Deploy the apps to both clusters

```sh
# Quick sed in-place to point the kustomize overlays at YOUR project
PROJECT=$(terraform -chdir=terraform/envs/dev output -raw project_id)
find kubernetes/apps -name 'kustomization.yaml' -exec \
  sed -i '' "s|myorg-platform-prod|$PROJECT|g" {} \;

# Apply to both clusters
for OVR in primary secondary; do
  CTX=$OVR
  for APP in web-app-a web-app-b; do
    kubectl --context $CTX apply -k kubernetes/apps/$APP/overlays/$OVR
  done
done

# Wait for rollouts
for CTX in primary secondary; do
  for APP in web-app-a web-app-b; do
    kubectl --context $CTX -n $APP rollout status deploy/$APP --timeout=5m
  done
done
```

### 2.5 Wire the global LB

```sh
# MCI/MCS objects go to the CONFIG cluster only (= primary)
kubectl --context primary apply -f kubernetes/ingress/

# Watch MCI program the LB
watch -n 5 kubectl --context primary -n web-app-a describe mci platform-edge
```

The LB is "ready" when **all backend NEGs report healthy** under `Backend Services`. That typically takes 5–10 minutes after the pods are Ready.

### 2.6 Point DNS (only if you supplied a real domain)

```sh
LB_IP=$(terraform -chdir=terraform/envs/dev output -raw global_lb_ip)
echo "Add an A record:  www.yourdomain  IN A  $LB_IP"
```

Then wait for the managed SSL cert to flip from `PROVISIONING` → `ACTIVE`:

```sh
gcloud compute ssl-certificates describe platform-edge-cert --global --format='value(managed.status)'
```

That takes 15–60 minutes after DNS propagates. **Without DNS, the cert never goes ACTIVE** — you can still demo HTTP by hitting the IP directly:

```sh
curl -sv http://$LB_IP/        # default -> web-app-a
curl -sv http://$LB_IP/b/      # -> web-app-b
```

### 2.7 Verify failover

```sh
# Drain the primary cluster's web pods — traffic should shift to secondary
kubectl --context primary -n web-app-a scale deploy/web-app-a --replicas=0
kubectl --context primary -n web-app-b scale deploy/web-app-b --replicas=0

# Hit the LB IP in a loop — should keep responding (from secondary)
for i in $(seq 1 20); do curl -s -o /dev/null -w "%{http_code} %{remote_ip}\n" http://$LB_IP/; sleep 1; done

# Restore
kubectl --context primary -n web-app-a scale deploy/web-app-a --replicas=3
kubectl --context primary -n web-app-b scale deploy/web-app-b --replicas=3
```

### 2.8 Stand up the Grafana dashboard

```sh
# Apply the BQ views
bq --project_id=$PROJECT query --use_legacy_sql=false \
   "$(sed "s/\${PROJECT}/$PROJECT/g; s/\${DATASET}/platform_logs/g" observability/bigquery/views.sql)"

# In a Cloud-hosted Grafana:
#   1. Add the BigQuery datasource (observability/grafana/datasources/bigquery.yaml)
#   2. Import observability/grafana/dashboards/platform-overview.json
#   3. Set the PROJECT template variable to your project ID
```

Generate some traffic so the dashboard has data:

```sh
hey -z 2m -c 10 http://$LB_IP/         # or: for i in $(seq 1 1000); do curl -s $LB_IP/ > /dev/null; done
```

Logs take **~1–2 minutes** to land in BigQuery after they're emitted.

---

## 3. Teardown (do this when done — every hour costs ~$10)

```sh
# Drain LB cleanly first (otherwise MCI gets stuck on dangling NEGs)
kubectl --context primary delete -f kubernetes/ingress/

# Wait ~2 min for the LB to deprogram, then:
cd terraform/envs/dev
terraform destroy -auto-approve
```

`terraform destroy` itself takes ~15 min — most of it is the GKE clusters disappearing. If destroy hangs on the project, manually delete the network's lingering NEGs, then re-run.

---

## 4. Demo script (what to say during the demo)

A 7-minute talk track that hits every architectural pillar:

1. **`terraform output`** — "Here's everything we got from one apply: a new project, two clusters, a global IP, the LB cert, the BQ dataset."
2. **`gcloud container clusters list`** — "Two regional clusters, private, Workload-Identity-enabled. Same module, different region."
3. **`kubectl get mci -n web-app-a platform-edge -o yaml`** — "MCI's the magic: one IP, NEGs in both clusters, proximity routing."
4. **`curl $LB_IP/` × 10 + show source pod region in response** — "Right now you're hitting the closest cluster."
5. **Failover demo from §2.7** — "I drain primary, traffic shifts to secondary, no DNS change, no human in the loop."
6. **Grafana dashboard** — "Logs ingested, BigQuery view, four panels: app errors, pod restarts, latency p95/p99, CPU/memory. Everything's queryable in BQ for forensics."
7. **`terraform destroy`** — "And it all came up from `terraform apply` in one shot. Re-runnable, deletable, idempotent."

---

## 5. Common failure modes & fixes

| Symptom                                                       | Cause                                          | Fix                                                  |
|---------------------------------------------------------------|------------------------------------------------|------------------------------------------------------|
| `terraform apply` errors on `google_project` with "callerHasNoPermission" | Org policy / billing user role missing  | Get `roles/billing.user` and `roles/resourcemanager.projectCreator` on the org/folder |
| GKE creation fails with "INVALID_ARGUMENT: ipAllocationPolicy" | CIDR overlap with existing VPCs              | Edit `local.subnets` CIDRs in `envs/dev/main.tf`     |
| Managed cert stuck in PROVISIONING for > 60 min               | DNS A record not pointing at the global IP    | Confirm `dig www.yourdomain` resolves to `$LB_IP`     |
| MCI backend services all UNHEALTHY                            | Pod `/healthz` returning non-200             | `kubectl exec` into pod, curl `localhost:8080/healthz` |
| Push to AR fails with PERMISSION_DENIED                       | `gcloud auth configure-docker` not run        | Run it, re-push                                       |
| Binary Authorization blocks first deploy                      | No attestor for the image yet                | Either disable BinAuth temporarily or run the `attest` step in `cicd/cloudbuild.yaml` |

---

## 6. Cost ceiling (set this NOW, not later)

```sh
gcloud billing budgets create \
  --billing-account=<ACCOUNT> \
  --display-name="gcp-grafana-poc-cap" \
  --budget-amount=200USD \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0 \
  --filter-projects=projects/$PROJECT
```

You'll get an email at 50% / 90% / 100% so a stuck demo doesn't turn into a $5k weekend.
