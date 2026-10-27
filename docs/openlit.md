# OpenLIT backend

[OpenLIT](https://docs.openlit.io/) is an open-source GenAI observability UI
with a built-in OTLP receiver. This repository runs a simplified OpenLIT stack;
the gateway keeps host ports `4317` and `4318`, while OpenLIT's receiver stays
internal.

## Start

```bash
./scripts/start.sh openlit
```

Open http://localhost:3000. Send client telemetry to the gateway at
`localhost:4317` (gRPC) or `localhost:4318` (HTTP).

## Services

| Service | Role |
|---|---|
| `otel-collector` | Receives OTLP and forwards it to OpenLIT |
| `openlit` | UI and internal OTLP receiver |
| `clickhouse` | Storage for `otel_*` tables |

Realtime/NATS is disabled (`NATS_URL=`) to keep this local stack small. For a
full upstream OpenLIT installation, run it separately and point `custom` mode
at its OTLP endpoint:

```dotenv
CUSTOM_OTLP_ENDPOINT=http://openlit:4317
CUSTOM_OTLP_PROTOCOL=grpc
```

```bash
./scripts/start.sh custom
```
