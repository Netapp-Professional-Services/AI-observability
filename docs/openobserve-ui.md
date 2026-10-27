# OpenObserve UI: finding DocStream stats

Data **is ingested**; the default Logs view will not show metrics, and a short time
range can hide older seed logs.

UI: http://127.0.0.1:5080/web/  
Login: `root@example.com` / password from observability `.env`

## AI effective metrics dashboard

Pre-built dashboard for the DocStream AI path (Langflow → MCP → OpenSearch → ingest/Tika):

- Design + PromQL: [ai-metrics-dashboard.md](ai-metrics-dashboard.md)
- Import JSON: `dashboards/docstream-ai-effective-metrics.dashboard.json`
- UI: **Dashboards → DocStream AI Effective Metrics**

That board uses live `docker_stats` as proxies for AI load. Token/latency/cost still belong in Langfuse (or Langflow 1.12+ OTLP).

## Metrics (container CPU / memory)

Do **not** look under **Logs** for `container_cpu_utilization`.

1. Left nav → **Metrics** (or open http://127.0.0.1:5080/web/metrics)
2. Set time range to **Past 6 hours** or **Past 1 day** (not only 15 minutes if scrape paused)
3. PromQL examples:

```promql
container_cpu_utilization
```

```promql
container_cpu_utilization{container_name="langflow"}
```

```promql
container_memory_percent{container_name="opensearch"}
```

```promql
container_memory_usage_total{container_name="ingest-service"}
```

Series are labeled with `container_name` (`langflow`, `opensearch`, `ingest-service`, …).

Stream list under **Streams → Metrics** should include:

- `container_cpu_utilization`
- `container_memory_percent`
- `container_memory_usage_total`
- `container_network_io_usage_rx_bytes` / `_tx_bytes`

## Logs

1. Left nav → **Logs**
2. Stream: **`docstream`** (and/or **`default`**)
3. Stream type: **logs**
4. Time range: **Past 1 day** (seed logs may be older than 15 minutes)
5. Optional SQL:

```sql
SELECT service, message, _timestamp FROM "docstream" ORDER BY _timestamp DESC
```

To add a fresh log line for the “last 15 minutes” window:

```bash
./scripts/seed-demo-data.sh
```

### Why app logs look empty

Container stdout scrape (`filelog` on `/var/lib/docker/containers`) is currently
**permission denied** on Docker Desktop. OpenObserve will not show live
`docker logs` until that is fixed. Metrics via `docker_stats` still work.

## Traces

**Traces → stream `default`**. Full Langflow playground/LLM traces need Langflow
1.12+ OTLP or Langfuse; this stack’s Langflow 1.11.5 does not emit rich chat spans.

## Quick API checks

```bash
# Metric names present?
curl -s -u root@example.com:"$ZO_ROOT_USER_PASSWORD" \
  'http://127.0.0.1:5080/api/default/prometheus/api/v1/label/__name__/values'

# Live CPU series?
curl -s -u root@example.com:"$ZO_ROOT_USER_PASSWORD" \
  'http://127.0.0.1:5080/api/default/prometheus/api/v1/query?query=container_cpu_utilization'
```
