# Prometheus backend

[Prometheus](https://prometheus.io/docs/prometheus/latest/getting_started/) stores
**metrics** from the gateway (OTLP/HTTP). Traces and logs are still accepted on
the gateway ports but dropped unless you also select OpenObserve, OpenLIT, or
SigNoz.

UI: http://localhost:9090

Prometheus documents the OTLP receiver as a low-volume push path. That matches
this gateway (GenAI client metrics). The receiver is enabled with
`--web.enable-otlp-receiver`. Nothing is scraped.

## Start

```bash
./scripts/start.sh prometheus
```

Pass it with any other local mode to fan out. `custom` stays alone.
Grafana charts these metrics; see [grafana.md](grafana.md).

Send client telemetry to the gateway at `localhost:4317` (gRPC) or
`localhost:4318` (HTTP). The collector exports metrics to
`http://prometheus:9090/api/v1/otlp/v1/metrics`.

`otlp.translation_strategy` is `UnderscoreEscapingWithSuffixes`, the same
Prometheus-style names VictoriaMetrics produces with
`-opentelemetry.usePrometheusNaming`.

## Optional env

| Variable | Default | Purpose |
|---|---|---|
| `PROMETHEUS_UI_PORT` | `9090` | Host port for the UI / HTTP API |
| `PROMETHEUS_DATA_DIR` | named volume | Persistent TSDB path |
| `PROMETHEUS_OTLP_METRICS_ENDPOINT` | `http://prometheus:9090/api/v1/otlp/v1/metrics` | Collector export URL |
| `PROMETHEUS_TLS_INSECURE` | `true` | Skip TLS verify to the local container |
| `PROMETHEUS_RETENTION` | `30d` | `--storage.tsdb.retention.time` |

## Quick verify

After seeding demo metrics (`./scripts/seed-demo-data.sh`):

```bash
curl -sG 'http://127.0.0.1:9090/api/v1/query' \
  --data-urlencode 'query={__name__=~"gen_ai_client_token_usage.*"}'
```

Or open the Prometheus UI and query `gen_ai_client_token_usage_sum` /
`gen_ai_client_operation_duration_seconds_sum`.
