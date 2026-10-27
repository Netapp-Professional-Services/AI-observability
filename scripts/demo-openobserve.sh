#!/usr/bin/env bash
# Start local OpenObserve and populate it with generic OTLP telemetry.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NO_OPEN="${NO_OPEN:-0}"

usage() {
  cat <<'EOF'
Usage: ./scripts/demo-openobserve.sh [--no-open]

Starts the standalone OTLP gateway and local OpenObserve, waits for both, then
sends sample traces and logs through the gateway.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-open) NO_OPEN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

for command in curl python3; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Missing required command: ${command}" >&2
    exit 1
  }
done

if [[ ! -f "${ROOT}/.env" ]]; then
  cp "${ROOT}/.env.example" "${ROOT}/.env"
  echo "Created ${ROOT}/.env with local demo defaults."
fi

"${ROOT}/scripts/start.sh" openobserve

wait_for_url() {
  local name="$1" url="$2" attempts="${3:-90}"
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

"${ROOT}/scripts/seed-demo-data.sh"

echo
echo "Demo ready:"
echo "  OpenObserve: http://127.0.0.1:5080/web/"
echo "  Look for service 'gateway-demo' in Traces and Logs."

if [[ "${NO_OPEN}" != "1" ]]; then
  if command -v open >/dev/null 2>&1; then
    open "http://127.0.0.1:5080/web/"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://127.0.0.1:5080/web/" >/dev/null 2>&1 &
  fi
fi
