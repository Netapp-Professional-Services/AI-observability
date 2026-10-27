# Join DocStream

This repo is the **OTLP gateway + backend UI** next to DocStream’s in-stack
`otel-collector-agent` (branch `otel_instrumentation` and later).

```text
DocStream apps  →  otel-collector-agent:4317  →  otel-collector:4317  →  backend UI
                   (inside DocStream)            (this repo)              OpenObserve / OpenLIT / custom
```

## Stable join points

| Item | Value |
|------|--------|
| Gateway hostname | `otel-collector` |
| Upstream for DocStream agent | `http://otel-collector:4317` (gRPC) |
| Host OTLP HTTP (debug/seed) | `http://localhost:4318` |
| Compose project | `COMPOSE_PROJECT_NAME=docstream` (default) |

There is **no** `compose.observability.yaml` in current DocStream. OTEL env vars
live in DocStream’s main `compose.yaml`; this repo only adds the gateway and UI.

## DocStream `.env` (required)

```dotenv
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
# Optional; unset → same as traces/metrics endpoint
# OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://otel-collector:4317
```

Do **not** point DocStream at OpenObserve/OpenLIT URLs directly when using this
repo — the agent speaks **gRPC** to this gateway. Backend auth stays in this
repo’s `.env`.

Wrong (old HTTP contract): `http://otel-collector:4318`

## Start together

```bash
cd /path/to/AI-observability
cp .env.example .env
./scripts/start-with-docstream.sh openobserve        # or openlit / custom / openobserve-cloud
```

## Pluggable backends

| Mode | Profile | UI |
|------|---------|-----|
| `openobserve` | self-hosted OpenObserve | http://localhost:5080 |
| `openobserve-cloud` | gateway only | OpenObserve Cloud |
| `openlit` | OpenLIT + ClickHouse | http://localhost:3000 |
| `custom` | gateway only | whatever `CUSTOM_OTLP_*` targets |

`custom` is how other users plug in their own UI (full OpenLIT install, Grafana,
Tempo, etc.) without changing DocStream:

```dotenv
CUSTOM_OTLP_ENDPOINT=http://my-otel-backend:4317
CUSTOM_OTLP_PROTOCOL=grpc
```

```bash
./scripts/start-with-docstream.sh custom
```

## What emits today (DocStream agent)

- **ingest-service**, **opensearch-mcp-server**, **langflow** — OTLP to the agent when the endpoint is set
- **OpenSearch** — Prometheus scrape + JSON log tail via the agent
- **Langfuse** — still independent (`LANGFUSE_*` in DocStream)

## Standalone gateway (no DocStream)

```bash
export OBSERVABILITY_DIR="$PWD"
export COLLECTOR_CONFIG=config.openobserve.yaml
# plus OPENOBSERVE_* / ZO_* as needed
docker compose --profile openobserve up -d
```

Point any OTLP client at `localhost:4317` (gRPC) or `localhost:4318` (HTTP).
