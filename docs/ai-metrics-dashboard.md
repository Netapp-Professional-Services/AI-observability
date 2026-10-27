# DocStream AI Effective Metrics (OpenObserve)

Dashboard for the AI path you can see **today** from OpenObserve, plus how to grow into true LLM metrics later.

UI: http://127.0.0.1:5080/web/  
Import JSON: [`dashboards/docstream-ai-effective-metrics.dashboard.json`](../dashboards/docstream-ai-effective-metrics.dashboard.json)

If already imported locally: **Dashboards → DocStream AI Effective Metrics**  
Direct view (folder `default`):  
http://127.0.0.1:5080/web/dashboards/view?dashboard=7513442570895098663&folder=default&org_identifier=default

## What “effective AI metrics” means here

DocStream’s AI loop is:

```text
S3/Confluence → ingest + Tika → OpenSearch (embed/index)
                                      ↑
Langflow playground → NetApp LLM proxy
         ↓
  OpenSearch MCP (tools / RAG)
```

Until Langflow emits LLM OTLP (needs **1.12+**; stack is on **1.11.5**) or you use **Langfuse**, OpenObserve does **not** have token/latency/cost series. What *is* live:

| Signal | Source | Use for AI |
|--------|--------|------------|
| Container CPU / memory / network | `docker_stats` → Metrics | Load on Langflow, MCP, OpenSearch, ingest, Tika |
| Logs stream `docstream` | Seed / OTLP / (later) docker logs | Errors and service chatter |

So this dashboard measures **effective AI health**: whether the AI path is busy, saturated, or failing — not prompt quality.

## Dashboard layout

### Tab: AI path (PromQL / Metrics)

Default time range: **Past 1 hour** (widen to 6h–1d if scrapes paused).

| Panel | PromQL | How to read it |
|-------|--------|----------------|
| Langflow / OpenSearch / MCP CPU % | `container_cpu_utilization{container_name="…"}` | Instant load on agent, index, tools |
| Langflow / OpenSearch memory % | `container_memory_percent{…}` | Saturation / OOM risk |
| Ingest + Tika CPU % | `container_name=~"ingest-service\|tika-server"` | Indexing after `POST /index-s3` |
| AI path CPU % (time series) | `container_name=~"langflow\|opensearch\|opensearch-mcp-server\|ingest-service\|tika-server"` | Correlate playground use with search/ingest |
| AI path memory % / bytes | same filter | Capacity |
| Langflow + MCP network RX/TX | `container_network_io_usage_*_bytes{container_name=~"langflow\|opensearch-mcp-server"}` | Proxy for LLM proxy + tool traffic |
| Ingest path CPU | ingest + tika + opensearch | Post-ingest indexing wave |
| OpenSearch memory pressure | `container_memory_percent{container_name="opensearch"}` | Index/query pressure |

**Demo sequence to light up panels**

1. Run a playground query on Enterprise Search Agent (VPN + NetApp proxy).
2. Watch **Langflow CPU/network**, then **MCP**, then **OpenSearch**.
3. `POST /index-s3` (S3 env alone does not ingest) → **ingest / tika / opensearch** CPU.

### Tab: Logs (SQL / stream `docstream`)

| Panel | Notes |
|-------|--------|
| Event / error counts | Heuristic on `message` / `level` |
| Events by service | Volume by `service` |
| Recent logs | May be empty until docker json-log scrape permissions are fixed; use `./scripts/seed-demo-data.sh` |

## Manual PromQL (Metrics explorer)

Same as [openobserve-ui.md](openobserve-ui.md), scoped to the AI path:

```promql
container_cpu_utilization{container_name=~"langflow|opensearch|opensearch-mcp-server|ingest-service|tika-server"}
```

```promql
container_memory_percent{container_name=~"langflow|opensearch|opensearch-mcp-server"}
```

```promql
container_network_io_usage_rx_bytes{container_name="langflow"}
```

## Import / re-import

```bash
# UI: Dashboards → Import → paste or upload
#   dashboards/docstream-ai-effective-metrics.dashboard.json

# Or API:
source .env
curl -s -u "${ZO_ROOT_USER_EMAIL}:${ZO_ROOT_USER_PASSWORD}" \
  -H 'Content-Type: application/json' \
  -X POST 'http://127.0.0.1:5080/api/default/dashboards' \
  --data-binary @dashboards/docstream-ai-effective-metrics.dashboard.json
```

## Phase 2 — real AI metrics (not in this dashboard yet)

| Goal | How |
|------|-----|
| Tokens, latency, model, cost | Langfuse (`LANGFUSE_*` in DocStream `.env`) — keep as agent truth |
| Spans in OpenObserve Traces | Bump Langflow to **1.12+** so `OTEL_*` is live |
| Structured ingest metrics | Add counters in ingest-service (docs indexed, Tika failures) → OTLP |
| Live app logs | Fix collector `filelog` access on Docker Desktop (see openobserve-ui.md) |

Recommended split: **Langfuse = LLM quality/cost**, **OpenObserve = platform + AI path load** (this dashboard).
