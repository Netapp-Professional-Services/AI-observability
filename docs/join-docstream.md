# Join DocStream

This repo implements the contract in DocStream `docs/observability.md`.

## Stable join points

| Item | Value |
|------|--------|
| Collector hostname | `otel-collector` |
| OTLP HTTP | `http://otel-collector:4318` |
| OTLP gRPC | `otel-collector:4317` |
| Compose project | `COMPOSE_PROJECT_NAME=docstream` (default) |
| DocStream overlay | `compose.observability.yaml` |

DocStream services receive `OTEL_*` from that overlay and should point at the collector hostname above — never at OpenObserve Cloud URLs from DocStream `.env` when using this repo. Switching Cloud vs self-hosted is only a change here.

## DocStream `.env` (minimal)

```dotenv
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

Do not set `OTEL_EXPORTER_OTLP_HEADERS` in DocStream when using the collector; auth lives in this repo’s `.env` as `OPENOBSERVE_AUTH_HEADER`.

## Start together

```bash
cd /path/to/docstream-observability
cp .env.example .env
# edit .env for cloud or local
./scripts/start-with-docstream.sh cloud   # or: local
```

## What emits today

- **Langflow OTLP**: needs Langflow 1.12+; DocStream currently pins 1.11.5, so service OTLP from Langflow is inert until that bump.
- **Langfuse**: still configured only in DocStream (`LANGFUSE_*`) for LLM traces — independent of this stack.
- **ingest / Tika / MCP / OpenSearch**: no OTEL SDK yet; scrape container stdout in a later iteration (Docker log receiver or Fluent Bit). Labels `docstream.observability=otlp` are already on those containers when the DocStream overlay is used.

## Standalone collector (no DocStream)

```bash
podman compose --profile cloud up -d
# or
podman compose --profile local up -d
```

Point any OTLP client at `localhost:4318`.
