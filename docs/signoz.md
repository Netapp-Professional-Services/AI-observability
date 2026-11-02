# SigNoz backend

[SigNoz](https://signoz.io/docs/install/docker/) stores traces, metrics, and logs
from the gateway. The stack is a Foundry v0.4.0 Docker Compose install vendored
under [`signoz/`](../signoz/) and started with profile `signoz`.

The gateway keeps host ports `4317` and `4318`. SigNoz's collector
(`signoz-ingester`) stays on the compose network. ClickHouse `8123` and `9000`
are not published, so this profile can run next to OpenLIT.

UI: http://localhost:8080

SigNoz needs about 4 GB of memory allocated to Docker, and more when OpenLIT's
ClickHouse is running as well.

## Start

```bash
./scripts/start.sh signoz
```

Fan out with the other local backends (any mix; `custom` stays alone):

```bash
./scripts/start.sh openobserve signoz
./scripts/start.sh openlit signoz
./scripts/start.sh openobserve openlit signoz
./scripts/start.sh signoz victoriametrics
```

Send client telemetry to the gateway at `localhost:4317` (gRPC) or
`localhost:4318` (HTTP). The gateway forwards a copy to `signoz-ingester:4317`.
Self-hosted SigNoz does not use an ingestion key.

The first visit to the UI creates the admin user. There is no seeded login.

Self-hosted SigNoz starts with no LLM model prices. Create an Admin
[service account](https://signoz.io/docs/manage/administrator-guide/iam/service-accounts/)
in the UI, set its API key as `SIGNOZ_API_KEY`, then run
[`scripts/signoz-sync-llm-prices.py`](../scripts/signoz-sync-llm-prices.py) to
populate them. See [Model pricing](#model-pricing).

The first start downloads the ClickHouse `histogram-quantile` helper, so the
Docker engine needs outbound HTTPS that one time.

## Services

| Service | Role |
|---|---|
| `otel-collector` | Receives OTLP and forwards it to `signoz-ingester:4317` |
| `signoz-ingester` | SigNoz collector (`signoz/signoz-otel-collector:v0.144.15`); OTLP stays internal |
| `signoz-signoz-0` | UI and API (`signoz/signoz:v0.148.1`) on host port `8080` |
| `signoz-telemetrystore-migrator` | One-shot ClickHouse schema migration |
| `signoz-telemetrystore-clickhouse-0-0` | Telemetry store (ClickHouse 25.12.5) |
| `signoz-telemetrykeeper-clickhousekeeper-0` | ClickHouse Keeper |
| `signoz-metastore-postgres-0` | Metadata (Postgres 16) |

Foundry v0.4.0 emits `signoz/signoz:latest` and
`signoz/signoz-otel-collector:latest`. Those tags are pinned here to the
digests `latest` resolved to when this stack was vendored: SigNoz `v0.148.1`
and the collector `v0.144.15`. ClickHouse is `25.12.5`, which is the version
Foundry wrote into the lock file.

## Optional env

| Variable | Default | Purpose |
|---|---|---|
| `SIGNOZ_UI_PORT` | `8080` | Host port for the SigNoz UI |
| `SIGNOZ_OTLP_ENDPOINT` | `signoz-ingester:4317` | Gateway export target (`host:port`) |
| `SIGNOZ_POSTGRES_USER` | `signoz` | Postgres role |
| `SIGNOZ_POSTGRES_PASSWORD` | `signoz` | Postgres password; must be URL-safe |
| `SIGNOZ_POSTGRES_DB` | `signoz` | Postgres database |
| `SIGNOZ_CLICKHOUSE_DATA_DIR` | named volume | ClickHouse data directory |
| `SIGNOZ_KEEPER_DATA_DIR` | named volume | ClickHouse Keeper data directory |
| `SIGNOZ_POSTGRES_DATA_DIR` | named volume | Postgres data directory |
| `SIGNOZ_CLICKHOUSE_USER_SCRIPTS_DIR` | named volume | ClickHouse `histogram-quantile` helper |
| `SIGNOZ_API_KEY` | unset | Admin service-account key for `scripts/signoz-sync-llm-prices.py` |
| `SIGNOZ_URL` | `http://localhost:$SIGNOZ_UI_PORT` | SigNoz base URL for the price sync |
| `SIGNOZ_LLM_PROVIDERS` | OpenRouter default set | Comma-separated provider prefixes to price |

Changing the Postgres user, password, or database after the volume already
exists does not rewrite the initialized cluster. The password is embedded in
`SIGNOZ_SQLSTORE_POSTGRES_DSN`, so keep it URL-safe (`signoz` is the default).

## Model pricing

Self-hosted SigNoz does not ship default LLM prices. An Admin service account
has to be created before
[`scripts/signoz-sync-llm-prices.py`](../scripts/signoz-sync-llm-prices.py)
can run. Cost stays empty until that script populates the prices.
That script reads current prices from the [OpenRouter models API](https://openrouter.ai/docs/api-reference/list-available-models)
and writes one **Auto** pricing rule per model. It is the
[SigNoz self-host sync](https://signoz.io/docs/ai-observability-model-pricing/#sync-prices-from-openrouter-in-self-hosted-signoz),
pointed at this stack. Run it once after install, and again whenever you want
the prices refreshed.

1. In the SigNoz UI, create a [service account](https://signoz.io/docs/manage/administrator-guide/iam/service-accounts/)
   with the Admin role and copy its API key.
2. Set `SIGNOZ_API_KEY` in `.env`. Leave `SIGNOZ_URL` unset to use
   `http://localhost:8080` (or `SIGNOZ_UI_PORT` when that is set).
3. Run:

```bash
python3 scripts/signoz-sync-llm-prices.py
```

The script prints how many rules it synced and disabled, then `Done`. Filter
the **Model Costs** tab by **Auto** to see them. A price applies to spans
SigNoz receives after the sync. Run it again when you want current OpenRouter
prices; enabled **User override** rules are left in place.

Set `SIGNOZ_LLM_PROVIDERS` to a comma-separated list of OpenRouter prefixes
(for example `openai,anthropic`) to limit which providers are synced.

## Dashboards

Sample SigNoz dashboards are JSON files in
[`dashboards/signoz/`](../dashboards/signoz/). Import the ones you need.
How to import, for SigNoz and the other backends, is in the
[README](../README.md#dashboards).

## Regenerate from Foundry

`./scripts/start.sh` does not call Foundry. To refresh the vendored files,
install [`foundryctl`](https://signoz.io/docs/install/docker/) and forge the
casting somewhere temporary:

```bash
foundryctl forge -f signoz/casting.yaml -p /tmp/signoz-pours
```

Copy the generated configs over `signoz/ingester/`, `signoz/telemetrykeeper/`,
and `signoz/telemetrystore/`. Then re-apply these edits to the generated
`compose.yaml` before replacing [`signoz/compose.yaml`](../signoz/compose.yaml):

- Drop `name` and the `signoz-network` so services share this project's network.
- Name the ingester service `signoz-ingester` (Foundry calls it `ingester` and
  only aliases that name on its own network).
- Add `profiles: [signoz]` on every service.
- Publish only `${SIGNOZ_UI_PORT:-8080}:8080`. Do not publish `4317`, `4318`,
  `8123`, or `9000`.
- Keep Foundry's service names for ClickHouse, Keeper, and Postgres so the
  generated DSNs still resolve.
- Substitute `SIGNOZ_POSTGRES_*` into Postgres and the SigNoz SQL DSN, and
  `SIGNOZ_*_DATA_DIR` plus `SIGNOZ_CLICKHOUSE_USER_SCRIPTS_DIR` for the data
  volumes. Leave volume names unpinned so they take this Compose project's prefix.
- Pin `signoz/signoz` and `signoz/signoz-otel-collector` if Foundry still emits
  `:latest`. Record the tags in `signoz/casting.yaml` and re-forge so
  `signoz/casting.yaml.lock` matches.
