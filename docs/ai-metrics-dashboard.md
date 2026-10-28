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

Until Langflow emits LLM OTLP (needs **1.12+**; stack is on **1.11.5**) or you use **Langfuse**, OpenObserve does **not** have token/latency/cost series. The gateway forwards OTLP traces, metrics, and logs only. It does not scrape Docker container metrics or container log files.

The imported dashboard still queries `container_*` series. Those panels stay empty. Logs in stream `docstream` still arrive from `./scripts/seed-demo-data.sh` or from an application sending OTLP logs.

## Dashboard layout

### Tab: AI path (PromQL / Metrics)

These panels query `container_*` metrics. The collector no longer produces them, so the tab stays empty.

### Tab: Logs (SQL / stream `docstream`)

| Panel | Notes |
|-------|--------|
| Event / error counts | Heuristic on `message` / `level` |
| Events by service | Volume by `service` |
| Recent logs | Filled by OTLP logs or `./scripts/seed-demo-data.sh` |

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
| Live app logs | Send application logs over OTLP to the gateway |

Recommended split: **Langfuse = LLM quality/cost**, **OpenObserve = OTLP traces, metrics, and logs**.
