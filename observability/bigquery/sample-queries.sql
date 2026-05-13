-- Sample queries used by the Grafana dashboards. ${__from} / ${__to} are
-- Grafana time-range macros for the BigQuery data source.

-- Panel 1: Application error rate
SELECT ts, service, errors
FROM `${PROJECT}.${DATASET}.v_app_errors_1m`
WHERE ts BETWEEN TIMESTAMP_MILLIS(${__from}) AND TIMESTAMP_MILLIS(${__to})
ORDER BY ts;

-- Panel 2: Pod restarts by namespace
SELECT ts, namespace, SUM(restarts) AS restarts
FROM `${PROJECT}.${DATASET}.v_pod_restarts_1h`
WHERE ts BETWEEN TIMESTAMP_MILLIS(${__from}) AND TIMESTAMP_MILLIS(${__to})
GROUP BY ts, namespace
ORDER BY ts;

-- Panel 3: Request latency p50/p95/p99
SELECT ts, p50_ms, p95_ms, p99_ms
FROM `${PROJECT}.${DATASET}.v_lb_latency_5m`
WHERE ts BETWEEN TIMESTAMP_MILLIS(${__from}) AND TIMESTAMP_MILLIS(${__to})
ORDER BY ts;

-- Panel 4: CPU + memory by container
SELECT ts, container, avg_cpu_cores, avg_mem_bytes / (1024 * 1024) AS avg_mem_mb
FROM `${PROJECT}.${DATASET}.v_container_resources_5m`
WHERE ts BETWEEN TIMESTAMP_MILLIS(${__from}) AND TIMESTAMP_MILLIS(${__to})
ORDER BY ts;
