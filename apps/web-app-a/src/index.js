// web-app-a — minimal stateless service exposing /, /healthz, /readyz, /metrics
// Structured JSON logs go to stdout (picked up by GKE logging agent → Cloud
// Logging → BigQuery sink for Grafana).
import express from "express";
import pino from "pino";
import pinoHttp from "pino-http";
import { collectDefaultMetrics, register, Histogram, Counter } from "prom-client";

const log = pino({
  level: process.env.LOG_LEVEL || "info",
  base: {
    service: process.env.APP_NAME || "web-app-a",
    region: process.env.REGION || "unknown",
    pod: process.env.POD_NAME,
  },
  // Cloud Logging picks "severity" out of structured JSON. Map pino levels.
  formatters: {
    level(label) {
      return { severity: label.toUpperCase() };
    },
  },
});

const app = express();
app.use(pinoHttp({ logger: log }));

// Prometheus metrics.
collectDefaultMetrics();
const httpRequests = new Counter({
  name: "http_requests_total",
  help: "Total HTTP requests by route+status.",
  labelNames: ["route", "status"],
});
const httpDuration = new Histogram({
  name: "http_request_duration_seconds",
  help: "Request duration histogram.",
  labelNames: ["route", "status"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
});

app.use((req, res, next) => {
  const end = httpDuration.startTimer();
  res.on("finish", () => {
    const route = req.route?.path || req.path;
    end({ route, status: res.statusCode });
    httpRequests.inc({ route, status: res.statusCode });
  });
  next();
});

// Readiness flips false on SIGTERM so the LB stops sending new traffic before
// in-flight requests drain.
let ready = true;

app.get("/", (req, res) => {
  res.json({ service: "web-app-a", region: process.env.REGION, pod: process.env.POD_NAME });
});

app.get("/healthz", (req, res) => res.status(200).send("ok"));
app.get("/readyz", (req, res) => res.status(ready ? 200 : 503).send(ready ? "ok" : "draining"));

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

const port = Number(process.env.PORT || 8080);
const server = app.listen(port, () => log.info({ port }, "web-app-a listening"));

function shutdown() {
  ready = false;
  log.info("draining…");
  // Give the LB time to fail health checks before we close the listener.
  setTimeout(() => server.close(() => process.exit(0)), 10_000);
}
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
