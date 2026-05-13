# Runbook

## On-call cheatsheet

| Symptom                                        | First check                                              | Likely cause                  |
|------------------------------------------------|----------------------------------------------------------|-------------------------------|
| 5xx rate alert firing                          | Grafana p95/p99 panel + Logs Explorer `severity>=ERROR`  | Bad deploy or downstream out  |
| Pods crashlooping                              | `kubectl describe pod`, then `kubectl logs --previous`   | Config/secret mismatch or OOM |
| LB 502 with no pod errors                      | `BackendConfig` health check path; pod readiness         | Drift in `/readyz` semantics  |
| Failover not happening                         | `kubectl describe mci platform-edge`                     | NEGs unhealthy in both regions|
| BigQuery view query slow                       | Check partition pruning; verify `timestamp` filter       | Missing partition filter       |
| Cost spike                                     | Cloud Logging exclusion filters + BQ table size          | Verbose app logs              |

## Failover (planned)

```sh
PROJECT=myorg-platform-prod

# Drain the primary cluster's web pods so MCI shifts traffic to secondary.
gcloud container clusters get-credentials gke-primary --region us-central1 --project $PROJECT
kubectl -n web-app-a scale deploy/web-app-a --replicas=0
kubectl -n web-app-b scale deploy/web-app-b --replicas=0

# Watch MCI report secondary as the active backend.
kubectl -n web-app-a describe mci platform-edge | grep -A2 "Backend Services"
```

To restore: scale back to 3 (or trigger the deploy script for the current tag).

## Image rollback

```sh
TAG=v1.0.3-stable
./scripts/deploy.sh web-app-a $TAG    # also redeploys to secondary
```

Or via kubectl directly:

```sh
kubectl -n web-app-a set image deploy/web-app-a app=us-docker.pkg.dev/$PROJECT/platform-images/web-app-a:$TAG
kubectl -n web-app-a rollout status deploy/web-app-a
```

## Cloud SQL recovery

```sh
gcloud sql backups list --instance=platform-db
gcloud sql backups restore <BACKUP_ID> --restore-instance=platform-db-recover --backup-instance=platform-db
```

Point-in-time recovery is enabled — use `gcloud sql instances clone --point-in-time` for finer-grained recovery.

## Cluster-level break-glass

```sh
# IAP-tunnel SSH into a node (after using `gcloud auth login`):
gcloud compute ssh gke-primary-apps-XXXX --zone us-central1-b --tunnel-through-iap

# Pause Binary Authorization enforcement (temporarily) to deploy an emergency image:
gcloud beta container binauthz policy import policy-dryrun.yaml
# … deploy the fix …
gcloud beta container binauthz policy import policy-enforce.yaml
```

Document any break-glass action in the incident channel within 15 minutes.

## Common Logs Explorer one-liners

```text
# 5xx rate from the LB:
resource.type="http_load_balancer" httpRequest.status>=500

# Pod crashloops:
resource.type="k8s_pod" jsonPayload.reason="BackOff"

# App-emitted errors for web-app-a in last 30m:
resource.type="k8s_container"
resource.labels.namespace_name="web-app-a"
severity>=ERROR
timestamp >= "PT30M"
```
