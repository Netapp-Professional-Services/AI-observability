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

## Database config (seeded automatically)

On first start the OpenLIT entrypoint runs `prisma db seed` and creates an
active ClickHouse Database Config named **Default DB** (environment
`production`) from the compose `INIT_DB_*` values:

| Field | Source |
|---|---|
| Host | `INIT_DB_HOST` → `openlit-clickhouse` |
| Port | `INIT_DB_PORT` → `8123` |
| Database | `INIT_DB_DATABASE` ← `OPENLIT_DB_NAME` (default `openlit`) |
| Username | `INIT_DB_USERNAME` ← `OPENLIT_DB_USER` (default `default`) |
| Password | `INIT_DB_PASSWORD` ← `OPENLIT_DB_PASSWORD` (default `OPENLIT`) |

Sign in with the seeded user `user@openlit.io` / `openlituser`. Traces and
dashboards should load without a manual Connectors step.

`INIT_DB_*` is bootstrap-only. Changing host or credentials later must be done
in the UI (**Organisation → Projects → Manage DB Config** or **Connectors →
ClickHouse**), then mark the config active. Do not expect a compose env change
to rewrite an existing SQLite row on the `openlit-data` volume.

## Evaluation judge endpoint

Evaluations → For OpenAI-compatible judge. Set
`OPENAI_BASE_URL` in `.env` (include `/v1`). 

For a private CA or self-signed certificate, build a PEM the same way as a
public-plus-internal bundle: start with the Mozilla CA bundle or the macOS
system roots, then append the endpoint's issuing and root certificates. Do not
use a leaf certificate as the trust anchor.

```bash
curl -fsSL https://curl.se/ca/cacert.pem -o ~/public-ca-bundle.pem
cat ~/public-ca-bundle.pem > ~/openlit-ca-bundle.pem
security find-certificate -a -p -c 'YOUR-ISSUING-CA-NAME' \
  /Library/Keychains/System.keychain >> ~/openlit-ca-bundle.pem
security find-certificate -a -p -c 'YOUR-ROOT-CA-NAME' \
  /Library/Keychains/System.keychain >> ~/openlit-ca-bundle.pem
chmod 644 ~/openlit-ca-bundle.pem
```

On a Mac, the public roots can come from the system keychain instead of curl.se:

```bash
security find-certificate -a -p \
  /System/Library/Keychains/SystemRootCertificates.keychain > ~/public-ca-bundle.pem
```

Set the path in `.env`:

```dotenv
OPENAI_BASE_URL=https://your-gateway.example/v1
OPENLIT_CA_BUNDLE=/Users/your-user/openlit-ca-bundle.pem
```

`./scripts/start.sh openlit` includes `compose.openlit-ca.yaml` only when
`OPENLIT_CA_BUNDLE` is set. That overlay mounts the file read-only at
`/tmp/custom-ca-bundle.pem` and sets `NODE_EXTRA_CA_CERTS`, which appends the
bundle to Node's public trust store. Certificate verification stays enabled.
Recreate the container after changing either variable.

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
