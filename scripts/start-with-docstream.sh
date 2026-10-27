#!/usr/bin/env bash
# Start DocStream + the AI Observability gateway on one Compose project/network.
#
# Usage:
#   ./scripts/start-with-docstream.sh openobserve         # self-hosted OpenObserve
#   ./scripts/start-with-docstream.sh openobserve-cloud   # OpenObserve Cloud
#   ./scripts/start-with-docstream.sh openlit             # self-hosted OpenLIT
#   ./scripts/start-with-docstream.sh custom              # CUSTOM_OTLP_* backend
#
# Aliases: local → openobserve, cloud → openobserve-cloud
#
# DocStream (otel_instrumentation+) must set:
#   OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
# Apps send to DocStream's otel-collector-agent; the agent forwards here over gRPC.
set -euo pipefail

MODE_RAW="${1:-}"
case "${MODE_RAW}" in
  local|openobserve) MODE="openobserve" ;;
  cloud|openobserve-cloud) MODE="openobserve-cloud" ;;
  openlit) MODE="openlit" ;;
  custom) MODE="custom" ;;
  *)
    echo "Usage: $0 openobserve|openobserve-cloud|openlit|custom" >&2
    echo "  aliases: local → openobserve, cloud → openobserve-cloud" >&2
    exit 1
    ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT}/.env"
  set +a
fi

DOCSTREAM_DIR="${DOCSTREAM_DIR:-${ROOT}/../docstream}"
DOCSTREAM_DIR="$(cd "${DOCSTREAM_DIR}" && pwd)"

if [[ ! -f "${DOCSTREAM_DIR}/compose.yaml" ]]; then
  echo "DocStream compose not found at ${DOCSTREAM_DIR}/compose.yaml" >&2
  echo "Set DOCSTREAM_DIR in .env" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/.env" ]]; then
  echo "Missing ${ROOT}/.env — copy .env.example and fill values" >&2
  exit 1
fi

if [[ -f "${DOCSTREAM_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${DOCSTREAM_DIR}/.env"
  # shellcheck disable=SC1090
  source "${ROOT}/.env"
  set +a
else
  echo "Missing ${DOCSTREAM_DIR}/.env — configure DocStream first" >&2
  exit 1
fi

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-docstream}"
export OBSERVABILITY_DIR="${ROOT}"

normalize_grpc_endpoint() {
  # Strip scheme and trailing slash → host:port for otlp exporter.
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
        # https:// → verify TLS; http:// or bare host → insecure
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
        # Empty is fine when the backend needs no auth.
        export CUSTOM_OTLP_AUTH_HEADER="${CUSTOM_OTLP_AUTH_HEADER:-}"
        export COLLECTOR_CONFIG="config.custom-http.yaml"
        BACKEND_DESC="custom HTTP (${CUSTOM_OTLP_HTTP_ENDPOINT})"
        ;;
      *)
        echo "CUSTOM_OTLP_PROTOCOL must be grpc or http (got: ${PROTOCOL})" >&2
        exit 1
        ;;
    esac
    PROFILE="custom"
    ;;
esac

COMPOSE=()
if command -v docker >/dev/null 2>&1 \
    && docker info >/dev/null 2>&1 \
    && docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v podman >/dev/null 2>&1 \
    && podman info >/dev/null 2>&1 \
    && podman compose version >/dev/null 2>&1; then
  COMPOSE=(podman compose)
else
  echo "Need a running Docker or Podman engine with Compose" >&2
  echo "Start Docker Desktop (or podman machine start), then re-run this script." >&2
  exit 1
fi

COMPOSE_FILES=(
  -f "${DOCSTREAM_DIR}/compose.yaml"
  -f "${ROOT}/compose.yaml"
)

# Optional DocStream overlays (only when the file exists).
if [[ -n "${LANGFLOW_CA_BUNDLE:-}" ]]; then
  if [[ ! -f "${LANGFLOW_CA_BUNDLE}" ]]; then
    echo "LANGFLOW_CA_BUNDLE is set but the file is missing: ${LANGFLOW_CA_BUNDLE}" >&2
    exit 1
  fi
  if [[ -f "${DOCSTREAM_DIR}/compose.langflow-ca.yaml" ]]; then
    COMPOSE_FILES+=(-f "${DOCSTREAM_DIR}/compose.langflow-ca.yaml")
  fi
fi
if [[ -n "${LLM_PROXY_HOST_IP:-}" && -f "${DOCSTREAM_DIR}/compose.langflow-netapp.yaml" ]]; then
  COMPOSE_FILES+=(-f "${DOCSTREAM_DIR}/compose.langflow-netapp.yaml")
fi

# Warn when DocStream still points at the old HTTP join or is unset.
DS_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-}"
EXPECTED="http://otel-collector:4317"
if [[ -z "${DS_ENDPOINT}" ]]; then
  echo "WARNING: DocStream OTEL_EXPORTER_OTLP_ENDPOINT is unset — agent export is disabled." >&2
  echo "         Set it to ${EXPECTED} in ${DOCSTREAM_DIR}/.env" >&2
elif [[ "${DS_ENDPOINT}" == *"otel-collector:4318"* ]]; then
  echo "WARNING: DocStream OTEL_EXPORTER_OTLP_ENDPOINT=${DS_ENDPOINT}" >&2
  echo "         DocStream's agent forwards over gRPC. Use ${EXPECTED}" >&2
elif [[ "${DS_ENDPOINT}" != *"otel-collector:4317"* ]]; then
  echo "NOTE: DocStream OTEL_EXPORTER_OTLP_ENDPOINT=${DS_ENDPOINT}" >&2
  echo "      For this gateway on the shared network, expected: ${EXPECTED}" >&2
fi

echo "Project:   ${COMPOSE_PROJECT_NAME}"
echo "DocStream: ${DOCSTREAM_DIR}"
echo "Mode:      ${MODE}"
echo "Backend:   ${BACKEND_DESC}"
echo "Collector: ${COLLECTOR_CONFIG}"
if [[ -n "${LANGFLOW_CA_BUNDLE:-}" && -f "${DOCSTREAM_DIR}/compose.langflow-ca.yaml" ]]; then
  echo "Langflow CA bundle: ${LANGFLOW_CA_BUNDLE}"
fi

"${COMPOSE[@]}" \
  "${COMPOSE_FILES[@]}" \
  --profile pipeline \
  --profile langflow \
  --profile "${PROFILE}" \
  up -d --build

echo
echo "DocStream agent → gateway gRPC:  http://otel-collector:4317 (in-network)"
echo "Host OTLP HTTP (seed/debug):     http://localhost:4318"
echo "Collector health:                http://localhost:13133"
case "${MODE}" in
  openobserve)
    echo "OpenObserve UI:                  http://localhost:5080"
    ;;
  openlit)
    echo "OpenLIT UI:                      http://localhost:${OPENLIT_UI_PORT:-3000}"
    ;;
esac
echo
echo "In DocStream .env ensure:"
echo "  OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317"
echo "  # optional: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://otel-collector:4317"
echo "Do not set OTEL_EXPORTER_OTLP_HEADERS in DocStream when auth lives in this repo."
