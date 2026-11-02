# AI Observability

A standalone OpenTelemetry Protocol (OTLP) gateway with pluggable storage and UI
backends. It accepts OTLP over gRPC (`:4317`) and HTTP (`:4318`), then forwards
telemetry to OpenObserve, OpenLIT, VictoriaMetrics, SigNoz, or any compatible backend.

```text
OTLP clients → otel-collector → OpenObserve / OpenLIT / VictoriaMetrics / SigNoz / custom
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
| `signoz` | Gateway + self-hosted SigNoz | http://localhost:8080 |
| `openobserve openlit` | Fan out to both local backends | both UIs above |
| `openobserve signoz` | Fan out to OpenObserve and SigNoz | both UIs above |
| `openobserve victoriametrics` | Fan out (metrics also to VM) | OpenObserve + vmui |
| `custom` | Gateway → `CUSTOM_OTLP_*` endpoint | Backend-specific |

The gateway exports to OpenObserve with OTLP/gRPC at `openobserve:5081`. OpenLIT
receives OTLP/gRPC at `openlit:4317`. VictoriaMetrics receives OTLP/HTTP metrics
at `victoriametrics:8428/opentelemetry/v1/metrics`. SigNoz receives OTLP/gRPC at
`signoz-ingester:4317` (not published on the host). Passing multiple local modes
loads each collector config and appends pipeline lists, so one client stream
reaches every selected store.

SigNoz stores traces, metrics, and logs. VictoriaMetrics is **metrics-only**.
Combine VictoriaMetrics with OpenObserve, OpenLIT, or SigNoz when you also need
traces or logs. SigNoz needs about 4 GB of Docker memory.

```bash
./scripts/start.sh openlit
./scripts/start.sh victoriametrics
./scripts/start.sh signoz
./scripts/start.sh openobserve openlit
./scripts/start.sh openobserve signoz
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
| SigNoz | http://localhost:8080/ |
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

## Dashboards

Sample dashboards live under [`dashboards/`](dashboards/). Import the JSON in
the folder for each backend you start. OpenObserve files are in
[`dashboards/openobserve/`](dashboards/openobserve/); SigNoz files are in
[`dashboards/signoz/`](dashboards/signoz/). A new sample is another JSON file
in the matching folder. Import it the same way.

OpenObserve: **Dashboards → Import**, then upload the file. Or:

```bash
source .env
curl -s -u "${ZO_ROOT_USER_EMAIL}:${ZO_ROOT_USER_PASSWORD}" \
  -H 'Content-Type: application/json' \
  -X POST 'http://127.0.0.1:5080/api/default/dashboards' \
  --data-binary @dashboards/openobserve/<file>.json
```

SigNoz: **Dashboards → New dashboard → Import JSON**. Or:

```bash
source .env
curl -s -H "SIGNOZ-API-KEY: ${SIGNOZ_API_KEY}" \
  -H 'Content-Type: application/json' \
  -X POST "${SIGNOZ_URL:-http://localhost:8080}/api/v2/dashboards" \
  --data-binary @dashboards/signoz/<file>.json
```

For Langflow token capture, use the **OpenAI** endpoint — not OpenAI Compatible.
See [docs/ai-metrics-dashboard.md](docs/ai-metrics-dashboard.md).

VictoriaMetrics setup notes: [docs/victoriametrics.md](docs/victoriametrics.md).
SigNoz setup notes: [docs/signoz.md](docs/signoz.md).

## Layout

```text
AI-observability/
├── compose.yaml
├── compose.fanout.yaml
├── collector/
├── signoz/
├── dashboards/
│   ├── openobserve/
│   └── signoz/
├── scripts/start.sh
├── scripts/stop.sh
├── scripts/signoz-sync-llm-prices.py
├── docs/
└── .env.example
```
