# AI Observability

A standalone OpenTelemetry Protocol (OTLP) gateway with pluggable storage and UI
backends. It accepts OTLP over gRPC (`:4317`) and HTTP (`:4318`), then forwards
traces, metrics, and logs to OpenObserve, OpenLIT, or any compatible backend.

```text
OTLP clients → otel-collector → selected backend
              :4317 / :4318    OpenObserve / OpenLIT / custom OTLP
```

## Quick start

```bash
cp .env.example .env
./scripts/start.sh openobserve
```

Open http://localhost:5080/web/ and sign in with the credentials in `.env`.
Point any OTLP client to `http://localhost:4317` for gRPC or
`http://localhost:4318` for HTTP.

Aliases: `local` → `openobserve`, `cloud` → `openobserve-cloud`.

### Supported modes

| Mode | Services | UI |
|---|---|---|
| `openobserve` | Gateway + self-hosted OpenObserve | http://localhost:5080 |
| `openobserve-cloud` | Gateway → OpenObserve Cloud | OpenObserve Cloud |
| `openlit` | Gateway + OpenLIT + ClickHouse | http://localhost:3000 |
| `custom` | Gateway → `CUSTOM_OTLP_*` endpoint | Backend-specific |

```bash
./scripts/start.sh openlit
./scripts/start.sh openobserve-cloud
./scripts/start.sh custom
```

For a sample OpenObserve installation and generic telemetry:

```bash
./scripts/demo-openobserve.sh --no-open
```

### Useful URLs

| Service | URL |
|---------|-----|
| OpenObserve | http://localhost:5080/web/ |
| OpenLIT | http://localhost:3000/ |
| Gateway health | http://localhost:13133/ |
| OTLP gRPC | localhost:4317 |
| OTLP HTTP | http://localhost:4318 |

### Custom backend

```dotenv
CUSTOM_OTLP_ENDPOINT=http://my-backend:4317
CUSTOM_OTLP_PROTOCOL=grpc
```

Set `CUSTOM_OTLP_PROTOCOL=http` and `CUSTOM_OTLP_AUTH_HEADER` for an OTLP/HTTP
backend that requires authentication.

### Shutdown

```bash
docker compose --profile openobserve down
```

Use the profile you started (`openlit`, `openobserve-cloud`, or `custom`).

An OpenObserve dashboard for the DocStream AI path is included at
[`dashboards/docstream-ai-effective-metrics.dashboard.json`](dashboards/docstream-ai-effective-metrics.dashboard.json).
See [docs/ai-metrics-dashboard.md](docs/ai-metrics-dashboard.md) to import it.

## Layout

```text
AI-observability/
├── compose.yaml
├── collector/
├── dashboards/docstream-ai-effective-metrics.dashboard.json
├── scripts/start.sh
├── docs/
└── .env.example
```
