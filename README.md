# AI Observability

A standalone OpenTelemetry Protocol (OTLP) gateway with pluggable storage and UI
backends. It accepts OTLP over gRPC (`:4317`) and HTTP (`:4318`), then forwards
telemetry to OpenObserve, OpenLIT, VictoriaMetrics, or any compatible backend.

```text
OTLP clients → otel-collector → OpenObserve / OpenLIT / VictoriaMetrics / custom
              :4317 / :4318
```

## Quick start

```bash
cp .env.example .env
./scripts/start.sh openobserve
```

Open http://localhost:5080/web/ and sign in with the credentials in `.env`.
Point any OTLP client to `http://localhost:4317` for gRPC or
`http://localhost:4318` for HTTP.

### Supported modes

| Mode | Services | UI |
|---|---|---|
| `openobserve` | Gateway + self-hosted OpenObserve | http://localhost:5080 |
| `openlit` | Gateway + OpenLIT + ClickHouse | http://localhost:3000 |
| `victoriametrics` | Gateway + VictoriaMetrics (metrics) | http://localhost:8428/vmui/ |
| `openobserve openlit` | Fan out to both local backends | both UIs above |
| `openobserve victoriametrics` | Fan out (metrics also to VM) | OpenObserve + vmui |
| `custom` | Gateway → `CUSTOM_OTLP_*` endpoint | Backend-specific |

The gateway exports to OpenObserve with OTLP/gRPC at `openobserve:5081`. OpenLIT
receives OTLP/gRPC at `openlit:4317`. VictoriaMetrics receives OTLP/HTTP metrics
at `victoriametrics:8428/opentelemetry/v1/metrics`. Passing multiple local modes
loads each collector config and appends pipeline lists, so one client stream
reaches every selected store.

VictoriaMetrics is **metrics-only**. Combine it with OpenObserve or OpenLIT when
you also need traces or logs.

```bash
./scripts/start.sh openlit
./scripts/start.sh victoriametrics
./scripts/start.sh openobserve openlit
./scripts/start.sh openobserve victoriametrics
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
| VictoriaMetrics (vmui) | http://localhost:8428/vmui/ |
| Gateway health | http://localhost:13133/ |
| OTLP gRPC | localhost:4317 |
| OTLP HTTP | localhost:4318 |

### Custom backend

```dotenv
CUSTOM_OTLP_ENDPOINT=http://my-backend:4317
CUSTOM_OTLP_PROTOCOL=grpc
```

Set `CUSTOM_OTLP_PROTOCOL=http` and `CUSTOM_OTLP_AUTH_HEADER` for an OTLP/HTTP
backend that requires authentication.

### Shutdown

```bash
./scripts/stop.sh
```

Stops the gateway and every backend profile. Named volumes are kept.

An OpenObserve **AI Metrics** dashboard (tokens, latency, LLM spans) is at
[`dashboards/ai-metrics.dashboard.json`](dashboards/ai-metrics.dashboard.json).
See [docs/ai-metrics-dashboard.md](docs/ai-metrics-dashboard.md) to import it.
For Langflow token capture, use the **OpenAI** endpoint — not OpenAI Compatible.

VictoriaMetrics setup notes: [docs/victoriametrics.md](docs/victoriametrics.md).

## Layout

```text
AI-observability/
├── compose.yaml
├── compose.fanout.yaml
├── collector/
├── dashboards/ai-metrics.dashboard.json
├── scripts/start.sh
├── scripts/stop.sh
├── docs/
└── .env.example
```
