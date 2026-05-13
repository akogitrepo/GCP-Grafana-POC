# web-app-a

Minimal stateless Node.js service. Endpoints:

| Path        | Purpose                                |
|-------------|----------------------------------------|
| `/`         | Returns `{service, region, pod}` JSON  |
| `/healthz`  | Liveness probe                         |
| `/readyz`   | Readiness probe (flips on SIGTERM)     |
| `/metrics`  | Prometheus metrics                     |

Run locally:

```sh
npm install
PORT=8080 LOG_LEVEL=debug npm start
curl localhost:8080/healthz
```

Build + push:

```sh
docker build -t us-docker.pkg.dev/$PROJECT/platform-images/web-app-a:$TAG .
docker push  us-docker.pkg.dev/$PROJECT/platform-images/web-app-a:$TAG
```
