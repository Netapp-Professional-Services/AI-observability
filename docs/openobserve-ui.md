# OpenObserve UI

Start the local backend with:

```bash
./scripts/start.sh openobserve
```

Open http://127.0.0.1:5080/web/ and sign in with `ZO_ROOT_USER_EMAIL` and
`ZO_ROOT_USER_PASSWORD` from `.env`.

The DocStream dashboard JSON is
[`dashboards/docstream-ai-effective-metrics.dashboard.json`](../dashboards/docstream-ai-effective-metrics.dashboard.json).
Import steps are in [ai-metrics-dashboard.md](ai-metrics-dashboard.md).

## Traces and logs

The collector forwards OTLP traces, metrics, and logs to OpenObserve over gRPC
at `openobserve:5081` for the `default` organization. Open **Traces** to explore
spans, or open **Logs** and select the stream created by your client. The
generic demo sends a `gateway-demo` service:

```bash
./scripts/seed-demo-data.sh
```

Use a sufficiently broad time range when checking data that was sent before the
last 15 minutes.

The gateway does not scrape Docker container metrics or container log files.
Metrics and logs appear when a client sends them over OTLP.

To run OpenLIT at the same time, start both modes. The gateway appends both
collector configs and delivers one stream to each store:

```bash
./scripts/start.sh openobserve openlit
```
