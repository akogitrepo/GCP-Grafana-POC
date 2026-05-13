# BigQuery schema (Cloud Logging export)

Cloud Logging creates a separate partitioned table per log channel inside `platform_logs`. The tables we care about for the Grafana dashboards:

| Table                             | Source                                    |
|-----------------------------------|-------------------------------------------|
| `stdout`                          | Container stdout (App A + App B)          |
| `stderr`                          | Container stderr                          |
| `events`                          | Kubernetes events (Pod restarts, OOM, …)  |
| `requests`                        | HTTP(S) Load Balancer request logs        |
| `cloudaudit_googleapis_com_activity` | GCP admin activity (cluster, IAM, LB)  |

Every table shares this core schema (subset shown):

| Column           | Type      | Notes                                                  |
|------------------|-----------|--------------------------------------------------------|
| `timestamp`      | TIMESTAMP | Partition key                                          |
| `severity`       | STRING    | DEFAULT, INFO, WARNING, ERROR, …                       |
| `resource.type`  | STRING    | `k8s_container`, `k8s_cluster`, `http_load_balancer`…  |
| `resource.labels`| RECORD    | e.g. `cluster_name`, `namespace_name`, `pod_name`      |
| `labels`         | RECORD    | LogEntry labels                                        |
| `textPayload`    | STRING    | Unstructured logs                                      |
| `jsonPayload`    | RECORD    | Structured logs from the app (preserves nested keys)   |
| `httpRequest`    | RECORD    | LB request log fields (latency, status, URL, …)        |
| `trace`          | STRING    | `projects/<id>/traces/<trace_id>` — joins to Cloud Trace |

The application emits JSON to stdout, so `jsonPayload.service`, `jsonPayload.region`, `jsonPayload.pod`, `jsonPayload.msg`, etc. are all queryable directly.
