# DocStream Observability

Separate deployable stack for **OpenObserve** + **OpenTelemetry Collector**, meant to sit beside [DocStream](../docstream) without owning DocStream’s compose services.

DocStream exposes the OTLP contract; this repo is the backend.

```text
DocStream services  --OTLP-->  otel-collector  -->  OpenObserve (Cloud or local)
```

## Quick start

```bash
cp .env.example .env
```

### OpenObserve Cloud (free tier)

1. Sign up at [cloud.openobserve.ai](https://cloud.openobserve.ai).
2. **Data sources → Custom → OTEL Collector** — copy org endpoint and Basic auth.
3. In `.env`:

```dotenv
OPENOBSERVE_OTLP_ENDPOINT=https://api.openobserve.ai/api/YOUR_ORG
OPENOBSERVE_AUTH_HEADER=Basic YOUR_BASE64_TOKEN
DOCSTREAM_DIR=../docstream
COMPOSE_PROJECT_NAME=docstream
```

4. In DocStream `.env`:

```dotenv
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

5. Start both stacks on one network:

```bash
./scripts/start-with-docstream.sh cloud
```

### Self-hosted OpenObserve

```dotenv
ZO_ROOT_USER_EMAIL=root@example.com
ZO_ROOT_USER_PASSWORD=Complexpass#123
DOCSTREAM_DIR=../docstream
COMPOSE_PROJECT_NAME=docstream
```

```bash
./scripts/start-with-docstream.sh local
```

UI: http://localhost:5080 · Collector health: http://localhost:13133

## Layout

```text
docstream-observability/
├── compose.yaml              # otel-collector + optional openobserve
├── collector/config.yaml     # OTLP → OpenObserve exporter
├── scripts/start-with-docstream.sh
├── docs/join-docstream.md
├── .env.example
└── README.md
```

## Profiles

| Profile | Services |
|---------|----------|
| `cloud` | `otel-collector` → OpenObserve Cloud |
| `local` | `openobserve` + `otel-collector` → local OO |

## Why a separate repo

- DocStream stays ingestion/search-focused.
- Backend swaps (Cloud ↔ self-hosted ↔ another OTLP store) change only this repo’s collector env/config.
- Shared hostname `otel-collector` is the stable DocStream join point.

See [docs/join-docstream.md](docs/join-docstream.md) and DocStream’s `docs/observability.md`.
