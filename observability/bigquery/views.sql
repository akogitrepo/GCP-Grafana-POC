-- Run once per environment. Creates Grafana-friendly views on top of the
-- Cloud Logging export tables.
--
-- Replace ${PROJECT} and ${DATASET} when running:
--   bq query --use_legacy_sql=false --project_id=$PROJECT \
--     "$(envsubst < views.sql)"

-- 1) Application errors per minute, per service.
CREATE OR REPLACE VIEW `${PROJECT}.${DATASET}.v_app_errors_1m` AS
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS ts,
  resource.labels.cluster_name        AS cluster,
  resource.labels.namespace_name      AS namespace,
  COALESCE(JSON_VALUE(jsonPayload, '$.service'), resource.labels.container_name) AS service,
  COUNT(*) AS errors
FROM `${PROJECT}.${DATASET}.stderr`
WHERE resource.type = "k8s_container"
  AND severity IN ("ERROR", "CRITICAL")
GROUP BY ts, cluster, namespace, service;

-- 2) Pod restarts by namespace (from k8s events).
CREATE OR REPLACE VIEW `${PROJECT}.${DATASET}.v_pod_restarts_1h` AS
SELECT
  TIMESTAMP_TRUNC(timestamp, HOUR) AS ts,
  resource.labels.cluster_name      AS cluster,
  JSON_VALUE(jsonPayload, '$.involvedObject.namespace') AS namespace,
  JSON_VALUE(jsonPayload, '$.involvedObject.name')      AS pod,
  COUNT(*) AS restarts
FROM `${PROJECT}.${DATASET}.events`
WHERE JSON_VALUE(jsonPayload, '$.reason') IN ("BackOff", "Killing", "Unhealthy", "Started")
GROUP BY ts, cluster, namespace, pod;

-- 3) LB request latency percentiles.
CREATE OR REPLACE VIEW `${PROJECT}.${DATASET}.v_lb_latency_5m` AS
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS ts,
  httpRequest.requestUrl             AS request_url,
  APPROX_QUANTILES(
    SAFE_DIVIDE(
      CAST(REGEXP_EXTRACT(httpRequest.latency, r"^([0-9.]+)s$") AS FLOAT64) * 1000,
      1
    ),
    100
  )[OFFSET(50)] AS p50_ms,
  APPROX_QUANTILES(
    SAFE_DIVIDE(
      CAST(REGEXP_EXTRACT(httpRequest.latency, r"^([0-9.]+)s$") AS FLOAT64) * 1000,
      1
    ),
    100
  )[OFFSET(95)] AS p95_ms,
  APPROX_QUANTILES(
    SAFE_DIVIDE(
      CAST(REGEXP_EXTRACT(httpRequest.latency, r"^([0-9.]+)s$") AS FLOAT64) * 1000,
      1
    ),
    100
  )[OFFSET(99)] AS p99_ms,
  COUNTIF(httpRequest.status >= 500) AS five_xx,
  COUNTIF(httpRequest.status >= 400 AND httpRequest.status < 500) AS four_xx,
  COUNT(*) AS requests
FROM `${PROJECT}.${DATASET}.requests`
WHERE resource.type = "http_load_balancer"
GROUP BY ts, request_url;

-- 4) Resource utilization derived from the K8s container metrics shipped via
--    logs. (For richer data prefer the Managed Prometheus data source; this
--    keeps everything in BigQuery for a single Grafana datasource.)
CREATE OR REPLACE VIEW `${PROJECT}.${DATASET}.v_container_resources_5m` AS
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS ts,
  resource.labels.cluster_name        AS cluster,
  resource.labels.namespace_name      AS namespace,
  resource.labels.pod_name            AS pod,
  resource.labels.container_name      AS container,
  AVG(SAFE_CAST(JSON_VALUE(jsonPayload, '$.cpu_usage_cores')      AS FLOAT64)) AS avg_cpu_cores,
  AVG(SAFE_CAST(JSON_VALUE(jsonPayload, '$.memory_usage_bytes')   AS FLOAT64)) AS avg_mem_bytes
FROM `${PROJECT}.${DATASET}.stdout`
WHERE resource.type = "k8s_container"
GROUP BY ts, cluster, namespace, pod, container;
