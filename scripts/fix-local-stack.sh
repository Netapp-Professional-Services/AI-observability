#!/usr/bin/env bash
# Bring DocStream + local OpenObserve up on Docker Desktop (preferred).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DS="${DOCSTREAM_DIR:-${ROOT}/../docstream}"
DS="$(cd "$DS" && pwd)"

if [[ -S "${HOME}/.docker/run/docker.sock" ]]; then
  export DOCKER_HOST="unix://${HOME}/.docker/run/docker.sock"
fi
if ! docker info >/dev/null 2>&1; then
  echo "Starting Docker Desktop..."
  open -a Docker || true
  for i in $(seq 1 90); do
    docker info >/dev/null 2>&1 && break
    sleep 2
  done
fi
if ! docker info >/dev/null 2>&1; then
  echo "Docker engine is not reachable. Start Docker Desktop and re-run." >&2
  exit 1
fi

podman machine stop 2>/dev/null || true

# shellcheck disable=SC1091
set -a
source "${DS}/.env"
source "${ROOT}/.env"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-docstream}"
export OBSERVABILITY_DIR="${ROOT}"
export COLLECTOR_CONFIG="config.openobserve.yaml"
export ZO_ROOT_USER_EMAIL="${ZO_ROOT_USER_EMAIL:-root@example.com}"
export ZO_ROOT_USER_PASSWORD="${ZO_ROOT_USER_PASSWORD:-Complexpass#123}"
export OPENOBSERVE_OTLP_ENDPOINT="${OPENOBSERVE_OTLP_ENDPOINT:-http://openobserve:5080/api/default}"
TOKEN="$(printf '%s' "${ZO_ROOT_USER_EMAIL}:${ZO_ROOT_USER_PASSWORD}" | base64 | tr -d '\n')"
export OPENOBSERVE_AUTH_HEADER="Basic ${TOKEN}"

# Align DocStream agent upstream with this gateway (gRPC).
export OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://otel-collector:4317}"

if [[ "${RESET_OPENOBSERVE:-1}" == "1" ]]; then
  echo "Resetting OpenObserve volume so root password from .env applies..."
  docker rm -f openobserve 2>/dev/null || true
  docker volume rm -f docstream_openobserve-data 2>/dev/null || true
fi

COMPOSE_FILES=(
  -f "${DS}/compose.yaml"
  -f "${ROOT}/compose.yaml"
)
if [[ -n "${LANGFLOW_CA_BUNDLE:-}" && -f "${LANGFLOW_CA_BUNDLE}" && -f "${DS}/compose.langflow-ca.yaml" ]]; then
  COMPOSE_FILES+=(-f "${DS}/compose.langflow-ca.yaml")
fi
if [[ -n "${LLM_PROXY_HOST_IP:-}" && -f "${DS}/compose.langflow-netapp.yaml" ]]; then
  COMPOSE_FILES+=(-f "${DS}/compose.langflow-netapp.yaml")
fi

cd "$ROOT"
docker compose \
  "${COMPOSE_FILES[@]}" \
  --profile pipeline --profile langflow --profile openobserve \
  up -d --build

echo "Waiting for login APIs..."
for i in $(seq 1 60); do
  oo=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 -X POST http://127.0.0.1:5080/auth/login \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"${ZO_ROOT_USER_EMAIL}\",\"password\":\"${ZO_ROOT_USER_PASSWORD}\"}" || echo 000)
  lf=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 http://127.0.0.1:7860/api/v1/auto_login || echo 000)
  echo "  t=${i} openobserve_login=${oo} langflow_api=${lf}"
  if [[ "${oo}" == "200" && "${lf}" == "200" ]]; then
    break
  fi
  sleep 5
done

docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo
echo "OpenObserve: http://127.0.0.1:5080/web/"
echo "  email:    ${ZO_ROOT_USER_EMAIL}"
echo "  password: ${ZO_ROOT_USER_PASSWORD}"
echo "Langflow:    http://127.0.0.1:7860/  (AUTO_LOGIN=true)"
echo "DocStream agent upstream should be: http://otel-collector:4317"
open 'http://127.0.0.1:5080/web/' 'http://127.0.0.1:7860/' 2>/dev/null || true
