# VictoriaMetrics backend

[VictoriaMetrics](https://docs.victoriametrics.com/) stores **metrics** from the
gateway (OTLP/HTTP). Traces and logs are still accepted on the gateway ports but
dropped unless you also select OpenObserve or OpenLIT.

UI (vmui): http://localhost:8428/vmui/

## Start

```bash
./scripts/start.sh victoriametrics
```

Fan out metrics (and other signals to the other backends):

```bash
./scripts/start.sh openobserve victoriametrics
./scripts/start.sh openlit victoriametrics
./scripts/start.sh openobserve openlit victoriametrics
```

Send client telemetry to the gateway at `localhost:4317` (gRPC) or
`localhost:4318` (HTTP). The collector exports metrics to
`http://victoriametrics:8428/opentelemetry/v1/metrics`.

## Optional env

| Variable | Default | Purpose |
|---|---|---|
| `VICTORIAMETRICS_UI_PORT` | `8428` | Host port for vmui / HTTP API |
| `VICTORIAMETRICS_DATA_DIR` | named volume | Persistent TSDB path |
| `VICTORIAMETRICS_OTLP_METRICS_ENDPOINT` | `http://victoriametrics:8428/opentelemetry/v1/metrics` | Collector export URL |
| `VICTORIAMETRICS_TLS_INSECURE` | `true` | Skip TLS verify to the local container |
| `VICTORIAMETRICS_RETENTION` | `30d` | `-retentionPeriod` |

Prometheus-compatible naming is enabled (`-opentelemetry.usePrometheusNaming`)
so GenAI metrics such as `gen_ai_client_token_usage_sum` query cleanly in vmui.

## Quick verify

After seeding demo metrics (`./scripts/seed-demo-data.sh`):

```bash
curl -sG 'http://127.0.0.1:8428/api/v1/query' \
  --data-urlencode 'query={__name__=~"gen_ai_client_token_usage.*"}'
```

Or open vmui and query `gen_ai_client_token_usage_sum` / `gen_ai_client_operation_duration_seconds_sum`.
