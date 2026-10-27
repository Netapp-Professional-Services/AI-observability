# AI Observability

OTLP **gateway + pluggable backend UI** for AI stacks such as [DocStream](../docstream).

DocStream owns instrumentation and an in-stack `otel-collector-agent`. This repo
owns the upstream collector hostname `otel-collector` and the UI/store you want
to look at (OpenObserve, OpenLIT, or any custom OTLP backend).

```text
DocStream services
        │ OTLP
        ▼
otel-collector-agent          (inside DocStream)
        │ gRPC forward
        ▼
otel-collector                (this repo — stable join :4317)
        │
        ├── OpenObserve (local or Cloud)
        ├── OpenLIT
        └── custom OTLP endpoint
```

## Quick start

```bash
cp .env.example .env
```

In **DocStream** `.env` (required for current DocStream):

```dotenv
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
```

With DocStream checked out at `../docstream` (or `DOCSTREAM_DIR` set):

```bash
./scripts/start-with-docstream.sh openobserve   # OpenObserve UI :5080
# ./scripts/start-with-docstream.sh openlit     # OpenLIT UI :3000
# ./scripts/start-with-docstream.sh openobserve-cloud
# ./scripts/start-with-docstream.sh custom      # CUSTOM_OTLP_* in .env
```

Aliases: `local` → `openobserve`, `cloud` → `openobserve-cloud`.

### One-command OpenObserve demo

```bash
./scripts/demo-openobserve.sh --no-open
```

### Useful URLs

| Service | URL |
|---------|-----|
| OpenObserve | http://localhost:5080/web/ |
| OpenLIT | http://localhost:3000/ |
| Langflow | http://localhost:7860/ |
| Ingest API health | http://localhost:8004/health |
| Gateway health | http://localhost:13133/ |
| Host OTLP HTTP | http://localhost:4318 |

### Custom / third-party UI

Any OTLP-compatible backend can plug in without changing DocStream:

```dotenv
CUSTOM_OTLP_ENDPOINT=http://my-backend:4317
CUSTOM_OTLP_PROTOCOL=grpc
```

```bash
./scripts/start-with-docstream.sh custom
```

See [docs/join-docstream.md](docs/join-docstream.md) and [docs/openlit.md](docs/openlit.md).

### Shutdown

```bash
set -a && source .env && set +a
DOCSTREAM_DIR="$(cd "${DOCSTREAM_DIR:-../docstream}" && pwd)"

docker compose \
  -f "${DOCSTREAM_DIR}/compose.yaml" \
  -f compose.yaml \
  --profile pipeline \
  --profile langflow \
  --profile openobserve \
  down
```

Use the profile you started (`openlit`, `openobserve-cloud`, `custom`, …).
Shortcut: `docker compose -p docstream down`.

## Layout

```text
AI-observability/
├── compose.yaml
├── collector/
│   ├── config.openobserve.yaml
│   ├── config.openlit.yaml
│   ├── config.custom-grpc.yaml
│   └── config.custom-http.yaml
├── dashboards/
├── scripts/start-with-docstream.sh
├── docs/join-docstream.md
├── docs/openlit.md
└── .env.example
```

## Profiles

| Profile | Services |
|---------|----------|
| `openobserve` | `openobserve` + `otel-collector` |
| `openobserve-cloud` | `otel-collector` → Cloud |
| `openlit` | `clickhouse` + `openlit` + `otel-collector` |
| `custom` | `otel-collector` → `CUSTOM_OTLP_*` |

## Why a separate repo

- DocStream stays ingestion/search-focused; agent export target stays one hostname.
- Swapping OpenObserve ↔ OpenLIT ↔ another OTLP UI is a profile change here only.
- Shared hostname `otel-collector:4317` is the stable DocStream join point.
