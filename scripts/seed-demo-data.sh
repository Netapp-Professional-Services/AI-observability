#!/usr/bin/env bash
# Send generic OTLP traces and logs to a gateway running on the local host.
set -euo pipefail

for command in curl python3; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Missing required command: ${command}" >&2
    exit 1
  }
done

TRACE_ID="$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
SPAN_ID="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
START_NS="$(python3 -c 'import time; print(int(time.time()*1e9))')"
END_NS="$(python3 -c 'import time; print(int(time.time()*1e9)+5_000_000)')"

echo "Sending OTLP trace through collector..."
curl -sf -X POST "http://127.0.0.1:4318/v1/traces" \
  -H 'Content-Type: application/json' \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {\"attributes\": [
        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"gateway-demo\"}},
        {\"key\": \"service.namespace\", \"value\": {\"stringValue\": \"demo\"}}
      ]},
      \"scopeSpans\": [{
        \"spans\": [{
          \"traceId\": \"${TRACE_ID}\",
          \"spanId\": \"${SPAN_ID}\",
          \"name\": \"gateway.demo.span\",
          \"kind\": 1,
          \"startTimeUnixNano\": \"${START_NS}\",
          \"endTimeUnixNano\": \"${END_NS}\",
          \"attributes\": [{\"key\": \"demo\", \"value\": {\"boolValue\": true}}]
        }]
      }]
    }]
  }" >/dev/null
echo "  trace sent"

echo "Sending OTLP log through collector..."
curl -sf -X POST "http://127.0.0.1:4318/v1/logs" \
  -H 'Content-Type: application/json' \
  -d "{
    \"resourceLogs\": [{
      \"resource\": {\"attributes\": [
        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"gateway-demo\"}},
        {\"key\": \"service.namespace\", \"value\": {\"stringValue\": \"demo\"}}
      ]},
      \"scopeLogs\": [{
        \"logRecords\": [{
          \"timeUnixNano\": \"${START_NS}\",
          \"severityNumber\": 9,
          \"severityText\": \"INFO\",
          \"body\": {\"stringValue\": \"OTLP demo log from seed-demo-data.sh\"},
          \"attributes\": [{\"key\": \"demo\", \"value\": {\"boolValue\": true}}]
        }]
      }]
    }]
  }" >/dev/null
echo "  log sent"
