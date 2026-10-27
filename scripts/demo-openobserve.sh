#!/usr/bin/env bash
# Start DocStream with local OpenObserve and populate it with demo telemetry.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NO_OPEN="${NO_OPEN:-0}"

usage() {
  cat <<'EOF'
Usage: ./scripts/demo-openobserve.sh [--no-open]

Starts DocStream, the OTLP gateway, and local OpenObserve; waits for the UIs
and collector; then sends sample logs and a trace.

Requires DocStream .env:
  OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-open)
      NO_OPEN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

for command in curl python3; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Missing required command: ${command}" >&2
    exit 1
  fi
done

if [[ ! -f "${ROOT}/.env" ]]; then
  cp "${ROOT}/.env.example" "${ROOT}/.env"
  echo "Created ${ROOT}/.env with local demo defaults."
fi

echo "Starting DocStream + local OpenObserve..."
"${ROOT}/scripts/start-with-docstream.sh" openobserve

wait_for_url() {
  local name="$1"
  local url="$2"
  local attempts="${3:-90}"

  printf 'Waiting for %s' "${name}"
  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS --connect-timeout 2 "${url}" >/dev/null 2>&1; then
      echo " ready"
      return 0
    fi
    printf '.'
    sleep 2
  done
  echo
  echo "Timed out waiting for ${name} at ${url}" >&2
  return 1
}

wait_for_url "OpenObserve" "http://127.0.0.1:5080/healthz"
wait_for_url "OpenTelemetry Collector" "http://127.0.0.1:13133/"
wait_for_url "Langflow" "http://127.0.0.1:7860/api/v1/auto_login"

echo "Loading demo logs and traces..."
"${ROOT}/scripts/seed-demo-data.sh"

sleep 6

echo
echo "Demo ready:"
echo "  OpenObserve: http://127.0.0.1:5080/web/"
echo "  Langflow:    http://127.0.0.1:7860/"
echo "  In OpenObserve, use Logs → stream 'docstream' and Traces → stream 'default'."

if [[ "${NO_OPEN}" != "1" ]]; then
  if command -v open >/dev/null 2>&1; then
    open "http://127.0.0.1:5080/web/"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://127.0.0.1:5080/web/" >/dev/null 2>&1 &
  fi
fi
