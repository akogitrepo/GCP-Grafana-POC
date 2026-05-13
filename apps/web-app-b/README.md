# web-app-b

Stateless Node.js service that talks to Memorystore (Redis) and Pub/Sub. Same shape as `web-app-a` but `/readyz` is dependency-aware: if either downstream is unhealthy the pod is taken out of rotation, but `/healthz` (liveness) keeps the process alive so Kubernetes doesn't restart it during a downstream blip.

| Path        | Purpose                                |
|-------------|----------------------------------------|
| `/`         | Returns `{service, region, pod}` JSON  |
| `/healthz`  | Liveness — process alive               |
| `/readyz`   | Readiness — drains on SIGTERM, fails if deps down |
| `/metrics`  | Prometheus metrics                     |
