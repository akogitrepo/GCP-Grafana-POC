// web-app-b — stateless service with downstream dependencies (Pub/Sub topic +
// Memorystore Redis). Health checks are dependency-aware: /healthz is process
// liveness, /readyz returns 503 if downstreams are unhealthy.
import express from "express";
import pino from "pino";
import pinoHttp from "pino-http";
import { collectDefaultMetrics, register, Histogram, Counter, Gauge } from "prom-client";

const log = pino({
  level: process.env.LOG_LEVEL || "info",
  base: {
    service: process.env.APP_NAME || "web-app-b",
    region: process.env.REGION || "unknown",
    pod: process.env.POD_NAME,
  },
  formatters: { level: (l) => ({ severity: l.toUpperCase() }) },
});

const app = express();
app.use(pinoHttp({ logger: log }));

collectDefaultMetrics();
const reqs = new Counter({ name: "http_requests_total", help: "total reqs", labelNames: ["route", "status"] });
const dur = new Histogram({
  name: "http_request_duration_seconds",
  help: "request duration",
  labelNames: ["route", "status"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
});
const depHealth = new Gauge({ name: "downstream_up", help: "1 if downstream healthy", labelNames: ["dep"] });

app.use((req, res, next) => {
  const end = dur.startTimer();
  res.on("finish", () => {
    const route = req.route?.path || req.path;
    end({ route, status: res.statusCode });
    reqs.inc({ route, status: res.statusCode });
  });
  next();
});

// Stubs: in real life these would ping Memorystore + Pub/Sub.
async function checkRedis()  { depHealth.set({ dep: "redis"  }, 1); return true; }
async function checkPubSub() { depHealth.set({ dep: "pubsub" }, 1); return true; }

let ready = true;

app.get("/", (req, res) => {
  res.json({ service: "web-app-b", region: process.env.REGION, pod: process.env.POD_NAME });
});

app.get("/healthz", (_req, res) => res.status(200).send("ok"));
app.get("/readyz", async (_req, res) => {
  if (!ready) return res.status(503).send("draining");
  try {
    const [r, p] = await Promise.all([checkRedis(), checkPubSub()]);
    if (r && p) return res.status(200).send("ok");
    return res.status(503).send("deps unhealthy");
  } catch (err) {
    log.error({ err }, "readyz check failed");
    return res.status(503).send("deps unhealthy");
  }
});

app.get("/metrics", async (_req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

const port = Number(process.env.PORT || 8080);
const server = app.listen(port, () => log.info({ port }, "web-app-b listening"));

function shutdown() {
  ready = false;
  log.info("draining…");
  setTimeout(() => server.close(() => process.exit(0)), 10_000);
}
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
