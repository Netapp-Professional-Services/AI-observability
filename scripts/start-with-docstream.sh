#!/usr/bin/env bash
# Start DocStream + this observability stack on one Compose project/network.
#
# Usage:
#   ./scripts/start-with-docstream.sh cloud   # OpenObserve Cloud
#   ./scripts/start-with-docstream.sh local   # self-hosted OpenObserve
#
# Prerequisites:
#   - .env in this repo (from .env.example)
#   - ../docstream/.env configured; set OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
set -euo pipefail

MODE="${1:-}"
if [[ "${MODE}" != "cloud" && "${MODE}" != "local" ]]; then
  echo "Usage: $0 cloud|local" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT}/.env"
  set +a
fi

DOCSTREAM_DIR="${DOCSTREAM_DIR:-${ROOT}/../docstream}"
DOCSTREAM_DIR="$(cd "${DOCSTREAM_DIR}" && pwd)"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-docstream}"

if [[ ! -f "${DOCSTREAM_DIR}/compose.yaml" ]]; then
  echo "DocStream compose not found at ${DOCSTREAM_DIR}/compose.yaml" >&2
  echo "Set DOCSTREAM_DIR in .env" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/.env" ]]; then
  echo "Missing ${ROOT}/.env — copy .env.example and fill values" >&2
  exit 1
fi

if [[ "${MODE}" == "local" ]]; then
  : "${ZO_ROOT_USER_EMAIL:?Set ZO_ROOT_USER_EMAIL in .env}"
  : "${ZO_ROOT_USER_PASSWORD:?Set ZO_ROOT_USER_PASSWORD in .env}"
  export OPENOBSERVE_OTLP_ENDPOINT="${OPENOBSERVE_OTLP_ENDPOINT:-http://openobserve:5080/api/default}"
  if [[ -z "${OPENOBSERVE_AUTH_HEADER:-}" ]]; then
    TOKEN="$(printf '%s' "${ZO_ROOT_USER_EMAIL}:${ZO_ROOT_USER_PASSWORD}" | base64 | tr -d '\n')"
    export OPENOBSERVE_AUTH_HEADER="Basic ${TOKEN}"
  fi
else
  : "${OPENOBSERVE_OTLP_ENDPOINT:?Set OPENOBSERVE_OTLP_ENDPOINT in .env for cloud mode}"
  : "${OPENOBSERVE_AUTH_HEADER:?Set OPENOBSERVE_AUTH_HEADER in .env for cloud mode}"
fi

COMPOSE=(compose)
if command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
  COMPOSE=(podman compose)
elif command -v docker >/dev/null 2>&1; then
  COMPOSE=(docker compose)
else
  echo "Need podman compose or docker compose" >&2
  exit 1
fi

echo "Project: ${COMPOSE_PROJECT_NAME}"
echo "DocStream: ${DOCSTREAM_DIR}"
echo "Mode: ${MODE}"
echo "Collector → ${OPENOBSERVE_OTLP_ENDPOINT}"

"${COMPOSE[@]}" \
  -f "${DOCSTREAM_DIR}/compose.yaml" \
  -f "${DOCSTREAM_DIR}/compose.observability.yaml" \
  -f "${ROOT}/compose.yaml" \
  --profile pipeline \
  --profile langflow \
  --profile "${MODE}" \
  up -d --build

echo
echo "otel-collector OTLP HTTP: http://otel-collector:4318 (in-network)"
echo "Host OTLP HTTP:           http://localhost:4318"
if [[ "${MODE}" == "local" ]]; then
  echo "OpenObserve UI:           http://localhost:5080"
fi
echo
echo "In DocStream .env ensure:"
echo "  OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318"
echo "  OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf"
