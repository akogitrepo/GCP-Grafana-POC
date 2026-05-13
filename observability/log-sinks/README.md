# Log sinks

Created by Terraform (`module.observability`). Two destinations are wired:

1. **Default `_Default` log bucket** — kept by GCP for 30 days, used for ad‑hoc Logs Explorer queries.
2. **BigQuery `platform_logs` dataset** — long‑term analytics, feeds Grafana.

To add a SIEM (Splunk, Chronicle, Datadog) just add another `google_logging_project_sink` with a Pub/Sub destination and a subscription on the SIEM side. Don't widen the BigQuery filter for SIEM — keep them independent so a SIEM outage doesn't lose data for dashboards.

## Common Logs Explorer searches

```text
resource.type="k8s_container" AND severity>=ERROR
resource.type="http_load_balancer" AND httpRequest.status>=500
protoPayload.methodName="io.k8s.core.v1.pods.binding.create"
```
