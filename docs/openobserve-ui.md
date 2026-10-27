# OpenObserve UI

Start the local backend with:

```bash
./scripts/start.sh openobserve
```

Open http://127.0.0.1:5080/web/ and sign in with `ZO_ROOT_USER_EMAIL` and
`ZO_ROOT_USER_PASSWORD` from `.env`.

The DocStream dashboard JSON is
[`dashboards/docstream-ai-effective-metrics.dashboard.json`](../dashboards/docstream-ai-effective-metrics.dashboard.json).
Import steps are in [ai-metrics-dashboard.md](ai-metrics-dashboard.md).

## Traces and logs

The collector forwards OTLP traces and logs to OpenObserve's default
organization. Open **Traces** to explore spans, or open **Logs** and select the
stream created by your client. The generic demo sends a `gateway-demo` service:

```bash
./scripts/seed-demo-data.sh
```

Use a sufficiently broad time range when checking data that was sent before the
last 15 minutes.

## Host metrics

The OpenObserve profile also collects Docker container metrics. In **Metrics**,
search for `container_cpu_utilization`, `container_memory_percent`, or
`container_memory_usage_total`. Filter by the `container_name` label for your
own container names.

Container stdout collection (`filelog`) can be unavailable on Docker Desktop
because its container-log path is not mounted into the collector. OTLP logs
sent by applications continue to work independently.

## API checks

```bash
# Metric names present?
curl -s -u root@example.com:"$ZO_ROOT_USER_PASSWORD" \
  'http://127.0.0.1:5080/api/default/prometheus/api/v1/label/__name__/values'

# Live CPU series?
curl -s -u root@example.com:"$ZO_ROOT_USER_PASSWORD" \
  'http://127.0.0.1:5080/api/default/prometheus/api/v1/query?query=container_cpu_utilization'
```
