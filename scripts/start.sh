#!/usr/bin/env bash
# Start the standalone OTLP gateway and one backend profile.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/start.sh <mode>

Modes:
  openobserve | local       Self-hosted OpenObserve
  openobserve-cloud | cloud OpenObserve Cloud
  openlit                    Self-hosted OpenLIT
  custom                     Any OTLP-compatible backend
EOF
}

MODE_RAW="${1:-}"
case "${MODE_RAW}" in
  local|openobserve) MODE="openobserve" ;;
  cloud|openobserve-cloud) MODE="openobserve-cloud" ;;
  openlit|custom) MODE="${MODE_RAW}" ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 1 ;;
esac

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

normalize_grpc_endpoint() {
  local value="${1:-}"
  value="${value#https://}"
  value="${value#http://}"
  value="${value%/}"
  printf '%s' "${value}"
}

case "${MODE}" in
  openobserve)
    : "${ZO_ROOT_USER_EMAIL:?Set ZO_ROOT_USER_EMAIL in .env}"
    : "${ZO_ROOT_USER_PASSWORD:?Set ZO_ROOT_USER_PASSWORD in .env}"
    export OPENOBSERVE_OTLP_ENDPOINT="${OPENOBSERVE_OTLP_ENDPOINT:-http://openobserve:5080/api/default}"
    if [[ -z "${OPENOBSERVE_AUTH_HEADER:-}" ]]; then
      TOKEN="$(printf '%s' "${ZO_ROOT_USER_EMAIL}:${ZO_ROOT_USER_PASSWORD}" | base64 | tr -d '\n')"
      export OPENOBSERVE_AUTH_HEADER="Basic ${TOKEN}"
    fi
    export COLLECTOR_CONFIG="config.openobserve.yaml"
    PROFILE="openobserve"
    BACKEND_DESC="OpenObserve local (${OPENOBSERVE_OTLP_ENDPOINT})"
    ;;
  openobserve-cloud)
    : "${OPENOBSERVE_OTLP_ENDPOINT:?Set OPENOBSERVE_OTLP_ENDPOINT in .env for cloud mode}"
    : "${OPENOBSERVE_AUTH_HEADER:?Set OPENOBSERVE_AUTH_HEADER in .env for cloud mode}"
    export COLLECTOR_CONFIG="config.openobserve.yaml"
    PROFILE="openobserve-cloud"
    BACKEND_DESC="OpenObserve Cloud (${OPENOBSERVE_OTLP_ENDPOINT})"
    ;;
  openlit)
    export OPENLIT_OTLP_ENDPOINT="$(normalize_grpc_endpoint "${OPENLIT_OTLP_ENDPOINT:-openlit:4317}")"
    export COLLECTOR_CONFIG="config.openlit.yaml"
    PROFILE="openlit"
    BACKEND_DESC="OpenLIT (${OPENLIT_OTLP_ENDPOINT})"
    ;;
  custom)
    : "${CUSTOM_OTLP_ENDPOINT:?Set CUSTOM_OTLP_ENDPOINT in .env for custom mode}"
    PROTOCOL="$(printf '%s' "${CUSTOM_OTLP_PROTOCOL:-grpc}" | tr '[:upper:]' '[:lower:]')"
    case "${PROTOCOL}" in
      grpc|otlp)
        export CUSTOM_OTLP_GRPC_ENDPOINT="$(normalize_grpc_endpoint "${CUSTOM_OTLP_ENDPOINT}")"
        if [[ "${CUSTOM_OTLP_ENDPOINT}" == https://* ]]; then
          export CUSTOM_OTLP_INSECURE="${CUSTOM_OTLP_INSECURE:-false}"
        else
          export CUSTOM_OTLP_INSECURE="${CUSTOM_OTLP_INSECURE:-true}"
        fi
        export COLLECTOR_CONFIG="config.custom-grpc.yaml"
        BACKEND_DESC="custom gRPC (${CUSTOM_OTLP_GRPC_ENDPOINT})"
        ;;
      http|otlphttp|http/protobuf)
        export CUSTOM_OTLP_HTTP_ENDPOINT="${CUSTOM_OTLP_ENDPOINT%/}"
        export CUSTOM_OTLP_AUTH_HEADER="${CUSTOM_OTLP_AUTH_HEADER:-}"
        export COLLECTOR_CONFIG="config.custom-http.yaml"
        BACKEND_DESC="custom HTTP (${CUSTOM_OTLP_HTTP_ENDPOINT})"
        ;;
      *) echo "CUSTOM_OTLP_PROTOCOL must be grpc or http (got: ${PROTOCOL})" >&2; exit 1 ;;
    esac
    PROFILE="custom"
    ;;
esac

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

echo "Project:   ${COMPOSE_PROJECT_NAME}"
echo "Mode:      ${MODE}"
echo "Backend:   ${BACKEND_DESC}"
echo "Collector: ${COLLECTOR_CONFIG}"

"${COMPOSE[@]}" \
  -f "${ROOT}/compose.yaml" \
  --profile "${PROFILE}" \
  up -d --build

echo
echo "Host OTLP gRPC:                  http://localhost:4317"
echo "Host OTLP HTTP:                  http://localhost:4318"
echo "Collector health:                http://localhost:13133"
case "${MODE}" in
  openobserve) echo "OpenObserve UI:                  http://localhost:5080" ;;
  openlit) echo "OpenLIT UI:                      http://localhost:${OPENLIT_UI_PORT:-3000}" ;;
esac
