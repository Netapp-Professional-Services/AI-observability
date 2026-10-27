# OpenLIT backend

[OpenLIT](https://docs.openlit.io/) is an open-source GenAI observability UI with
a built-in OTLP receiver. This repo runs a **simplified** OpenLIT stack behind
the DocStream gateway so host ports `:4317` / `:4318` stay on `otel-collector`.

## Start

```bash
# DocStream .env
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317

# This repo
./scripts/start-with-docstream.sh openlit
```

UI: http://localhost:3000

## Layout

| Service | Role |
|---------|------|
| `otel-collector` | Gateway DocStream’s agent talks to |
| `openlit` | UI + OTLP receiver (internal `:4317`/`:4318` only) |
| `clickhouse` | Storage for `otel_*` tables |

Realtime / NATS is disabled (`NATS_URL=`) to keep the demo stack small. For a
full OpenLIT install (NATS + alerts), run upstream OpenLIT yourself and use
**custom** mode:

```dotenv
CUSTOM_OTLP_ENDPOINT=http://openlit:4317
CUSTOM_OTLP_PROTOCOL=grpc
```

```bash
./scripts/start-with-docstream.sh custom
```
