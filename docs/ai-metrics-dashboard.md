# AI Metrics (OpenObserve)

Dashboard for GenAI token usage, LLM latency, and chat spans forwarded through
this gateway.

UI: http://127.0.0.1:5080/web/  
Import JSON: [`dashboards/ai-metrics.dashboard.json`](../dashboards/ai-metrics.dashboard.json)

If already imported locally: **Dashboards → AI Metrics**  
Direct view (folder `default`):  
http://127.0.0.1:5080/web/dashboards/view?dashboard=7521576713868805516&folder=default&org_identifier=default

The older container-proxy dashboard
([`dashboards/docstream-ai-effective-metrics.dashboard.json`](../dashboards/docstream-ai-effective-metrics.dashboard.json))
is kept for reference; prefer **AI Metrics** for token/latency views.

## Langflow: OpenAI vs OpenAI Compatible

To capture token metrics from Langflow, configure the model with the **OpenAI**
endpoint / component — **not** **OpenAI Compatible**.

The OpenAI Compatible path often omits usage fields on the response, so OTEL
never sees `gen_ai.usage.input_tokens` / `gen_ai.usage.output_tokens` or the
`gen_ai.client.token.usage` metric. With the OpenAI endpoint, usage is present
and the **AI Metrics** dashboard can chart tokens and duration.

Point Langflow’s OTLP exporter at this gateway:

| Protocol | Endpoint |
|----------|----------|
| gRPC | `http://localhost:4317` |
| HTTP | `http://localhost:4318` |

## What the dashboard shows

### Tab: Tokens & latency (PromQL)

| Panel | Query focus |
|-------|-------------|
| Input / output / total tokens | `gen_ai_client_token_usage_sum` (`gen_ai_token_type`) |
| Avg LLM duration | `gen_ai_client_operation_duration_sum` / `_count` |
| Tokens by type / model / provider | Same metric, grouped by label |
| Duration by model | Duration histogram sum/count by `gen_ai_request_model` |

OpenObserve stores OTEL metric names with `.` → `_`
(`gen_ai.client.token.usage` → `gen_ai_client_token_usage_*`).

PromQL panel legends use **single** braces for label values
(`{gen_ai_request_model}`). Double braces (`{{...}}`) are dashboard variables
and will show literally in the UI.

### Tab: LLM spans (SQL / traces stream `default`)

| Panel | Notes |
|-------|--------|
| Span counts / errors | Rows with `gen_ai_operation_name` |
| Input / output tokens | `CAST(gen_ai_usage_*_tokens AS BIGINT)` |
| Tokens over time / by model | Span attributes from chat calls |
| Recent LLM spans | Model, provider, tokens, `trace_id` |

## Seed sample GenAI data

With the OpenObserve profile running:

```bash
./scripts/seed-demo-data.sh
```

This sends a generic demo span/log plus a `langflow` chat span and
`gen_ai.client.*` histograms so the dashboard is not empty before a real flow
runs.

## Import / re-import

```bash
# UI: Dashboards → Import → upload
#   dashboards/ai-metrics.dashboard.json

# Or API:
source .env
curl -s -u "${ZO_ROOT_USER_EMAIL}:${ZO_ROOT_USER_PASSWORD}" \
  -H 'Content-Type: application/json' \
  -X POST 'http://127.0.0.1:5080/api/default/dashboards' \
  --data-binary @dashboards/ai-metrics.dashboard.json
```

Also useful: OpenObserve **AI → Monitor → Insights** if your edition exposes
built-in LLM monitoring on the same GenAI spans.

## Empty panels checklist

1. Gateway + OpenObserve are up (`./scripts/start.sh openobserve`).
2. Langflow (or another client) exports OTLP to `:4317` / `:4318`.
3. Langflow uses the **OpenAI** endpoint, not OpenAI Compatible.
4. Time range on the dashboard covers when the chat ran (default **1h**).
5. Or run `./scripts/seed-demo-data.sh` to inject demo GenAI telemetry.
