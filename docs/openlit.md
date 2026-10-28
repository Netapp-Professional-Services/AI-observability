# OpenLIT backend

[OpenLIT](https://docs.openlit.io/) 2.1.0 is the GenAI observability UI for this
profile. The gateway keeps host ports `4317` and `4318`. OpenLIT's embedded
collector stays on the compose network and writes ClickHouse itself.

## Start

```bash
./scripts/start.sh openlit
```

To send the same gateway stream to OpenObserve as well:

```bash
./scripts/start.sh openobserve openlit
```

Open http://localhost:3000 (override with `OPENLIT_UI_PORT`). Send client telemetry to the
gateway at `localhost:4317` (gRPC) or `localhost:4318` (HTTP). The gateway forwards a
copy to OpenLIT at `openlit:4317`. With both modes, it also forwards to OpenObserve.

## Initial database config

Traces and dashboards stay empty until the current project has a ClickHouse
database config. Sign in (seeded installs use `user@openlit.io` /
`openlituser`), select the project in the header, then open **Organisation →
Projects → Manage DB Config** (or **Connectors → ClickHouse**) and add:

| Field | Value |
|---|---|
| Config Name | `db-config` |
| Environment | `production` |
| Username | `default` |
| Password | `OPENLIT` |
| Host | `openlit-clickhouse` |
| Port | `8123` |
| Database | `openlit` |
| Query params | leave blank |

Save, then mark the config active with the list checkbox or the header
Databases switcher. OpenLIT checks the connection when the config becomes
active.

`openlit-clickhouse` is the Compose service name, so it resolves on the Docker
network. If `.env` overrides `OPENLIT_DB_USER`, `OPENLIT_DB_PASSWORD`, or
`OPENLIT_DB_NAME`, use those values for username, password, and database.

## Services

| Service | Role |
|---|---|
| `otel-collector` | Receives OTLP and forwards it to `openlit:4317` |
| `openlit` | UI (`ghcr.io/openlit/openlit:2.1.0`) and embedded collector |
| `openlit-clickhouse` | Storage for `otel_*` tables |

ClickHouse is initialized from
[`openlit/assets/clickhouse-init.sh`](../openlit/assets/clickhouse-init.sh) and
[`openlit/assets/clickhouse-config.xml`](../openlit/assets/clickhouse-config.xml).
The embedded collector config is
[`openlit/assets/otel-collector-config.yaml`](../openlit/assets/otel-collector-config.yaml),
mounted at `/etc/otel/otel-collector-config.yaml`. Log-detail patches under
`openlit/assets/openlit-patches/` match image `2.1.0` only.

ClickHouse and the OpenLIT UI database use named volumes
(`openlit-clickhouse-data` and `openlit-data`). Set
`OPENLIT_CLICKHOUSE_DATA_DIR` and `OPENLIT_DATA_DIR` in `.env` to mount host
directories instead.

There is no NATS sidecar. For a full upstream OpenLIT installation, run it
separately and point `custom` mode at its OTLP endpoint:

```dotenv
CUSTOM_OTLP_ENDPOINT=http://openlit:4317
CUSTOM_OTLP_PROTOCOL=grpc
```

```bash
./scripts/start.sh custom
```
