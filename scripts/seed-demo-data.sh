#!/usr/bin/env bash
# Seed OpenObserve with sample logs + OTLP traces/logs via the collector.
# Also imports the DocStream Enterprise Search Agent into Langflow if missing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Use the same credentials and DocStream path as the launcher.
if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT}/.env"
  set +a
fi

DS="${DOCSTREAM_DIR:-${ROOT}/../docstream}"
DS="$(cd "$DS" && pwd)"

if [[ -S "${HOME}/.docker/run/docker.sock" ]]; then
  export DOCKER_HOST="unix://${HOME}/.docker/run/docker.sock"
fi

OO_USER="${ZO_ROOT_USER_EMAIL:-root@example.com}"
OO_PASS="${ZO_ROOT_USER_PASSWORD:-Complexpass#123}"
NOW_MS="$(python3 -c 'import time; print(int(time.time()*1000))')"
TRACE_ID="$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
SPAN_ID="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
START_NS="$(python3 -c 'import time; print(int(time.time()*1e9))')"
END_NS="$(python3 -c 'import time; print(int(time.time()*1e9)+5_000_000)')"

echo "Seeding OpenObserve JSON logs..."
curl -sf -u "${OO_USER}:${OO_PASS}" \
  -H 'Content-Type: application/json' \
  "http://127.0.0.1:5080/api/default/docstream/_json" \
  -d "[
    {\"level\":\"info\",\"service\":\"docstream-bootstrap\",\"message\":\"OpenObserve ingest path OK\",\"event\":\"bootstrap\",\"_timestamp\":${NOW_MS}},
    {\"level\":\"info\",\"service\":\"ingest-service\",\"message\":\"Demo log: ready to index documents\",\"_timestamp\":${NOW_MS}},
    {\"level\":\"info\",\"service\":\"langflow\",\"message\":\"Demo log: playground idle\",\"_timestamp\":${NOW_MS}}
  ]" >/dev/null
echo "  logs stream=docstream OK"

echo "Sending OTLP trace + log through collector..."
curl -sf -X POST "http://127.0.0.1:4318/v1/traces" \
  -H 'Content-Type: application/json' \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {\"attributes\": [
        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"docstream-demo\"}},
        {\"key\": \"service.namespace\", \"value\": {\"stringValue\": \"docstream\"}}
      ]},
      \"scopeSpans\": [{
        \"spans\": [{
          \"traceId\": \"${TRACE_ID}\",
          \"spanId\": \"${SPAN_ID}\",
          \"name\": \"docstream.demo.span\",
          \"kind\": 1,
          \"startTimeUnixNano\": \"${START_NS}\",
          \"endTimeUnixNano\": \"${END_NS}\",
          \"attributes\": [
            {\"key\": \"demo\", \"value\": {\"boolValue\": true}}
          ]
        }]
      }]
    }]
  }" >/dev/null
echo "  OTLP traces OK"

curl -sf -X POST "http://127.0.0.1:4318/v1/logs" \
  -H 'Content-Type: application/json' \
  -d "{
    \"resourceLogs\": [{
      \"resource\": {\"attributes\": [
        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"docstream-demo\"}}
      ]},
      \"scopeLogs\": [{
        \"logRecords\": [{
          \"timeUnixNano\": \"${START_NS}\",
          \"severityNumber\": 9,
          \"severityText\": \"INFO\",
          \"body\": {\"stringValue\": \"OTLP demo log from seed-demo-data.sh\"},
          \"attributes\": [
            {\"key\": \"demo\", \"value\": {\"boolValue\": true}}
          ]
        }]
      }]
    }]
  }" >/dev/null
echo "  OTLP logs OK"

echo "Ensuring Langflow has Enterprise Search Agent..."
TOKEN="$(curl -sf http://127.0.0.1:7860/api/v1/auto_login | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')"
PROJECT="$(curl -sf -H "Authorization: Bearer ${TOKEN}" http://127.0.0.1:7860/api/v1/projects/ | python3 -c 'import sys,json; print(json.load(sys.stdin)[0]["id"])')"
HAS="$(curl -sf -H "Authorization: Bearer ${TOKEN}" -H 'Accept: application/json' \
  "http://127.0.0.1:7860/api/v1/flows/?folder_id=${PROJECT}" --compressed \
  | python3 -c 'import sys,json; print(any(f.get("name")=="Enterprise Search Agent" for f in json.load(sys.stdin)))')"
if [[ "${HAS}" != "True" ]]; then
  FLOW="${DS}/examples/langflow/flows/Enterprise-Search-Agent.json"
  if [[ -f "${FLOW}" ]]; then
    curl -sf -X POST "http://127.0.0.1:7860/api/v1/flows/upload/?folder_id=${PROJECT}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -F "file=@${FLOW};type=application/json" >/dev/null
    echo "  imported Enterprise Search Agent"
  else
    echo "  flow fixture not found; skipped Langflow import"
  fi
else
  echo "  already present"
fi

echo
echo "OpenObserve:"
echo "  Logs → stream 'docstream' (JSON seed)"
echo "  Traces → look for service 'docstream-demo' (may take ~10s)"
echo "  Metrics → docker_stats after collector restart with socket mount"
echo "Langflow: open project 'Starter Project' → flow 'Enterprise Search Agent'"
echo "  URL: http://127.0.0.1:7860/"
