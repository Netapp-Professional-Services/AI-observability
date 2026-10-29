#!/usr/bin/env bash
# Send generic OTLP traces, logs, and sample GenAI metrics to a local gateway.
set -euo pipefail

for command in curl python3; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Missing required command: ${command}" >&2
    exit 1
  }
done

TRACE_ID="$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
SPAN_ID="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
AI_TRACE_ID="$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
AI_SPAN_ID="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
START_NS="$(python3 -c 'import time; print(int(time.time()*1e9))')"
END_NS="$(python3 -c 'import time; print(int(time.time()*1e9)+5_000_000)')"
AI_END_NS="$(python3 -c 'import time; print(int(time.time()*1e9)+250_000_000)')"

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

echo "Sending GenAI chat span (token usage attributes)..."
curl -sf -X POST "http://127.0.0.1:4318/v1/traces" \
  -H 'Content-Type: application/json' \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {\"attributes\": [
        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"langflow\"}},
        {\"key\": \"service.namespace\", \"value\": {\"stringValue\": \"ai\"}}
      ]},
      \"scopeSpans\": [{
        \"scope\": {\"name\": \"demo.gen_ai\"},
        \"spans\": [{
          \"traceId\": \"${AI_TRACE_ID}\",
          \"spanId\": \"${AI_SPAN_ID}\",
          \"name\": \"chat gpt-4o-mini\",
          \"kind\": 3,
          \"startTimeUnixNano\": \"${START_NS}\",
          \"endTimeUnixNano\": \"${AI_END_NS}\",
          \"attributes\": [
            {\"key\": \"gen_ai.operation.name\", \"value\": {\"stringValue\": \"chat\"}},
            {\"key\": \"gen_ai.system\", \"value\": {\"stringValue\": \"openai\"}},
            {\"key\": \"gen_ai.provider.name\", \"value\": {\"stringValue\": \"openai\"}},
            {\"key\": \"gen_ai.request.model\", \"value\": {\"stringValue\": \"gpt-4o-mini\"}},
            {\"key\": \"gen_ai.response.model\", \"value\": {\"stringValue\": \"gpt-4o-mini\"}},
            {\"key\": \"gen_ai.usage.input_tokens\", \"value\": {\"intValue\": \"128\"}},
            {\"key\": \"gen_ai.usage.output_tokens\", \"value\": {\"intValue\": \"64\"}}
          ],
          \"status\": {\"code\": 1}
        }]
      }]
    }]
  }" >/dev/null
echo "  gen_ai span sent"

echo "Sending GenAI token + duration metrics..."
curl -sf -X POST "http://127.0.0.1:4318/v1/metrics" \
  -H 'Content-Type: application/json' \
  -d "{
    \"resourceMetrics\": [{
      \"resource\": {\"attributes\": [
        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"langflow\"}}
      ]},
      \"scopeMetrics\": [{
        \"scope\": {\"name\": \"demo.gen_ai\"},
        \"metrics\": [
          {
            \"name\": \"gen_ai.client.token.usage\",
            \"description\": \"Number of tokens used\",
            \"unit\": \"{token}\",
            \"histogram\": {
              \"dataPoints\": [
                {
                  \"attributes\": [
                    {\"key\": \"gen_ai.operation.name\", \"value\": {\"stringValue\": \"chat\"}},
                    {\"key\": \"gen_ai.provider.name\", \"value\": {\"stringValue\": \"openai\"}},
                    {\"key\": \"gen_ai.request.model\", \"value\": {\"stringValue\": \"gpt-4o-mini\"}},
                    {\"key\": \"gen_ai.token.type\", \"value\": {\"stringValue\": \"input\"}}
                  ],
                  \"startTimeUnixNano\": \"${START_NS}\",
                  \"timeUnixNano\": \"${AI_END_NS}\",
                  \"count\": \"1\",
                  \"sum\": 128,
                  \"bucketCounts\": [\"0\", \"1\", \"0\"],
                  \"explicitBounds\": [100.0, 1000.0]
                },
                {
                  \"attributes\": [
                    {\"key\": \"gen_ai.operation.name\", \"value\": {\"stringValue\": \"chat\"}},
                    {\"key\": \"gen_ai.provider.name\", \"value\": {\"stringValue\": \"openai\"}},
                    {\"key\": \"gen_ai.request.model\", \"value\": {\"stringValue\": \"gpt-4o-mini\"}},
                    {\"key\": \"gen_ai.token.type\", \"value\": {\"stringValue\": \"output\"}}
                  ],
                  \"startTimeUnixNano\": \"${START_NS}\",
                  \"timeUnixNano\": \"${AI_END_NS}\",
                  \"count\": \"1\",
                  \"sum\": 64,
                  \"bucketCounts\": [\"1\", \"0\", \"0\"],
                  \"explicitBounds\": [100.0, 1000.0]
                }
              ],
              \"aggregationTemporality\": 2
            }
          },
          {
            \"name\": \"gen_ai.client.operation.duration\",
            \"description\": \"GenAI operation duration\",
            \"unit\": \"s\",
            \"histogram\": {
              \"dataPoints\": [{
                \"attributes\": [
                  {\"key\": \"gen_ai.operation.name\", \"value\": {\"stringValue\": \"chat\"}},
                  {\"key\": \"gen_ai.provider.name\", \"value\": {\"stringValue\": \"openai\"}},
                  {\"key\": \"gen_ai.request.model\", \"value\": {\"stringValue\": \"gpt-4o-mini\"}}
                ],
                \"startTimeUnixNano\": \"${START_NS}\",
                \"timeUnixNano\": \"${AI_END_NS}\",
                \"count\": \"1\",
                \"sum\": 0.25,
                \"bucketCounts\": [\"0\", \"1\", \"0\"],
                \"explicitBounds\": [0.1, 1.0]
              }],
              \"aggregationTemporality\": 2
            }
          }
        ]
      }]
    }]
  }" >/dev/null
echo "  gen_ai metrics sent"

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
