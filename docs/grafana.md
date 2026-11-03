# Grafana

[Grafana](https://grafana.com/docs/grafana/latest/) charts metrics stored in
Prometheus and VictoriaMetrics. It does not receive OTLP and it does not start
the gateway.

UI: http://localhost:3000

Sign in with
`GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` (`admin` / `admin` when unset).

## Start

```bash
./scripts/start.sh grafana
```

That starts only the Grafana container. Both datasources are still provisioned.
A datasource stays unavailable until that store is running on the same Compose
network. Starting Prometheus or VictoriaMetrics afterward leaves Grafana up,
because `up` does not stop services from other profiles. Grafana can also be
passed with any other mode, including `custom`.

## Datasources

| Name | Type | URL inside Compose |
|---|---|---|
| Prometheus | Prometheus | `http://prometheus:9090` |
| VictoriaMetrics | Prometheus | `http://victoriametrics:8428` |

Single-node VictoriaMetrics serves the Prometheus HTTP API on port 8428, so the
same panels work on either source. Sample dashboards in
[`dashboards/grafana/`](../dashboards/grafana/) are provisioned into the
**AI Observability** folder.

## Optional env

| Variable | Default | Purpose |
|---|---|---|
| `GRAFANA_PORT` | `3000` | Host port (container listens on 3000) |
| `GRAFANA_ADMIN_USER` | `admin` | Sign-in user |
| `GRAFANA_ADMIN_PASSWORD` | `admin` | Sign-in password |
| `GRAFANA_DATA_DIR` | named volume | Grafana state |

## Quick verify

Start Prometheus or VictoriaMetrics, seed demo metrics
(`./scripts/seed-demo-data.sh`), then open
http://localhost:3000/d/genai-metrics/genai-metrics and pick the matching
datasource.
