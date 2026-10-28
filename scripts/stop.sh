#!/usr/bin/env bash
# Stop the OTLP gateway and every backend profile.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/stop.sh

Stops the gateway and every backend profile (openobserve, openlit, custom).
Named volumes are kept.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if [[ $# -ne 0 ]]; then
  usage >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -f "${ROOT}/.env" ]]; then
  echo "Missing ${ROOT}/.env — copy .env.example and fill values" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1090
source "${ROOT}/.env"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ai-observability}"
export OBSERVABILITY_DIR="${ROOT}"

if command -v docker >/dev/null 2>&1 \
   && docker info >/dev/null 2>&1 \
   && docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1 \
    && docker info >/dev/null 2>&1 \
    && docker-compose version >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
elif command -v podman >/dev/null 2>&1 \
    && podman info >/dev/null 2>&1 \
    && podman compose version >/dev/null 2>&1; then
  COMPOSE=(podman compose)
else
  echo "Need a running Docker or Podman engine with Compose" >&2
  exit 1
fi

echo "Project: ${COMPOSE_PROJECT_NAME}"
echo "Stopping all profiles"

"${COMPOSE[@]}" \
  -f "${ROOT}/compose.yaml" \
  --profile openobserve \
  --profile openlit \
  --profile custom \
  down --remove-orphans
