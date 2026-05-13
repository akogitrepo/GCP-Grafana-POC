# BigQuery — log analytics for Grafana

The Cloud Logging sink (Terraform: `module.observability`) exports all Kubernetes container, cluster, LB, network, and VM logs to a partitioned BigQuery dataset (`platform_logs` by default).

Cloud Logging creates one table per log channel — e.g. `stdout`, `stderr`, `events`, `cloudaudit_googleapis_com_activity`, `requests` for the LB. These tables are partitioned by `timestamp` and the JSON payload from structured logs is preserved in the `jsonPayload` column.

`views.sql` flattens these into Grafana-friendly views; `sample-queries.sql` shows the queries that back each dashboard panel.

## Quickstart

```sh
DATASET=platform_logs
PROJECT=myorg-platform-prod

bq --project_id=$PROJECT query --use_legacy_sql=false < views.sql
```

## Connecting Grafana

In a Cloud-hosted Grafana instance:

1. Add a data source → **BigQuery**.
2. Auth mode: **Google JWT**. Paste a service-account key with `roles/bigquery.dataViewer` and `roles/bigquery.jobUser` on `$PROJECT`.
3. Default project: `$PROJECT`. Default dataset: `$DATASET`.
4. Import the four dashboards from `../grafana/dashboards/`.
