#!/usr/bin/env bash
# Start the standalone OTLP gateway and one or more backend profiles.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/start.sh <mode> [mode ...]

Modes:
  openobserve                         Self-hosted OpenObserve
  openlit                             Self-hosted OpenLIT
  victoriametrics                     Self-hosted VictoriaMetrics (metrics)
  openobserve openlit                 Fan out to both backends
  openobserve victoriametrics         Fan out (metrics also to VM)
  openobserve openlit victoriametrics Fan out to all three
  custom                              Any OTLP-compatible backend

custom cannot be combined with another mode.
VictoriaMetrics stores metrics only; combine with OpenObserve/OpenLIT for traces/logs.
EOF
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

MODES=()
for arg in "$@"; do
  case "${arg}" in
    openobserve|openlit|victoriametrics|custom) MODES+=("${arg}") ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

has_mode() {
  local want="$1"
  local mode
  for mode in "${MODES[@]}"; do
    [[ "${mode}" == "${want}" ]] && return 0
  done
  return 1
}

# Reject duplicates.
seen=""
for mode in "${MODES[@]}"; do
  case " ${seen} " in
    *" ${mode} "*) echo "Duplicate mode: ${mode}" >&2; exit 1 ;;
  esac
  seen="${seen} ${mode}"
done

if has_mode custom && [[ ${#MODES[@]} -ne 1 ]]; then
  echo "custom cannot be combined with another mode" >&2
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

normalize_grpc_endpoint() {
  local value="${1:-}"
  value="${value#https://}"
  value="${value#http://}"
  value="${value%/}"
  printf '%s' "${value}"
}

require_grpc_hostport() {
  local name="$1"
  local value="$2"
  if [[ "${value}" == */* || "${value}" != *:* ]]; then
    echo "${name} must be host:port for gRPC, not an HTTP URL (got: ${value})" >&2
    exit 1
  fi
}

PROFILES=()
BACKENDS=()
CONFIGS=()

setup_openobserve() {
  : "${ZO_ROOT_USER_EMAIL:?Set ZO_ROOT_USER_EMAIL in .env}"
  : "${ZO_ROOT_USER_PASSWORD:?Set ZO_ROOT_USER_PASSWORD in .env}"
  export OPENOBSERVE_OTLP_ENDPOINT="$(normalize_grpc_endpoint "${OPENOBSERVE_OTLP_ENDPOINT:-openobserve:5081}")"
  require_grpc_hostport OPENOBSERVE_OTLP_ENDPOINT "${OPENOBSERVE_OTLP_ENDPOINT}"
  export OPENOBSERVE_ORGANIZATION="${OPENOBSERVE_ORGANIZATION:-default}"
  export OPENOBSERVE_TLS_INSECURE="${OPENOBSERVE_TLS_INSECURE:-true}"
  if [[ -z "${OPENOBSERVE_AUTH_HEADER:-}" ]]; then
    TOKEN="$(printf '%s' "${ZO_ROOT_USER_EMAIL}:${ZO_ROOT_USER_PASSWORD}" | base64 | tr -d '\n')"
    export OPENOBSERVE_AUTH_HEADER="Basic ${TOKEN}"
  fi
  PROFILES+=(openobserve)
  BACKENDS+=("OpenObserve local (${OPENOBSERVE_OTLP_ENDPOINT})")
  CONFIGS+=(config.openobserve.yaml)
}

setup_openlit() {
  export OPENLIT_OTLP_ENDPOINT="$(normalize_grpc_endpoint "${OPENLIT_OTLP_ENDPOINT:-openlit:4317}")"
  require_grpc_hostport OPENLIT_OTLP_ENDPOINT "${OPENLIT_OTLP_ENDPOINT}"
  PROFILES+=(openlit)
  BACKENDS+=("OpenLIT (${OPENLIT_OTLP_ENDPOINT})")
  CONFIGS+=(config.openlit.yaml)
}

setup_victoriametrics() {
  export VICTORIAMETRICS_OTLP_METRICS_ENDPOINT="${VICTORIAMETRICS_OTLP_METRICS_ENDPOINT:-http://victoriametrics:8428/opentelemetry/v1/metrics}"
  export VICTORIAMETRICS_TLS_INSECURE="${VICTORIAMETRICS_TLS_INSECURE:-true}"
  export VICTORIAMETRICS_RETENTION="${VICTORIAMETRICS_RETENTION:-30d}"
  PROFILES+=(victoriametrics)
  BACKENDS+=("VictoriaMetrics (${VICTORIAMETRICS_OTLP_METRICS_ENDPOINT})")
  CONFIGS+=(config.victoriametrics.yaml)
}

setup_custom() {
  : "${CUSTOM_OTLP_ENDPOINT:?Set CUSTOM_OTLP_ENDPOINT in .env for custom mode}"
  PROTOCOL="$(printf '%s' "${CUSTOM_OTLP_PROTOCOL:-grpc}" | tr '[:upper:]' '[:lower:]')"
  case "${PROTOCOL}" in
    grpc|otlp)
      export CUSTOM_OTLP_GRPC_ENDPOINT="$(normalize_grpc_endpoint "${CUSTOM_OTLP_ENDPOINT}")"
      require_grpc_hostport CUSTOM_OTLP_GRPC_ENDPOINT "${CUSTOM_OTLP_GRPC_ENDPOINT}"
      if [[ "${CUSTOM_OTLP_ENDPOINT}" == https://* ]]; then
        export CUSTOM_OTLP_INSECURE="${CUSTOM_OTLP_INSECURE:-false}"
      else
        export CUSTOM_OTLP_INSECURE="${CUSTOM_OTLP_INSECURE:-true}"
      fi
      CONFIGS+=(config.custom-grpc.yaml)
      BACKENDS+=("custom gRPC (${CUSTOM_OTLP_GRPC_ENDPOINT})")
      ;;
    http|otlphttp|http/protobuf)
      export CUSTOM_OTLP_HTTP_ENDPOINT="${CUSTOM_OTLP_ENDPOINT%/}"
      export CUSTOM_OTLP_AUTH_HEADER="${CUSTOM_OTLP_AUTH_HEADER:-}"
      CONFIGS+=(config.custom-http.yaml)
      BACKENDS+=("custom HTTP (${CUSTOM_OTLP_HTTP_ENDPOINT})")
      ;;
    *) echo "CUSTOM_OTLP_PROTOCOL must be grpc or http (got: ${PROTOCOL})" >&2; exit 1 ;;
  esac
  PROFILES+=(custom)
}

if has_mode openobserve; then
  setup_openobserve
fi
if has_mode openlit; then
  setup_openlit
fi
if has_mode victoriametrics; then
  setup_victoriametrics
fi
if has_mode custom; then
  setup_custom
fi

FANOUT=0
if [[ ${#CONFIGS[@]} -gt 1 ]]; then
  FANOUT=1
fi

# Base compose still needs COLLECTOR_CONFIG; fan-out overrides the command.
export COLLECTOR_CONFIG="${CONFIGS[0]}"

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
echo "Mode:      ${MODES[*]}"
echo "Backend:   ${BACKENDS[*]}"
if [[ "${FANOUT}" -eq 1 ]]; then
  echo "Collector: ${CONFIGS[*]} (append pipelines)"
else
  echo "Collector: ${COLLECTOR_CONFIG}"
fi

FANOUT_FILE="${ROOT}/compose.fanout.generated.yaml"
compose_args=(-f "${ROOT}/compose.yaml")
if [[ "${FANOUT}" -eq 1 ]]; then
  {
    echo "# Generated by scripts/start.sh — do not edit."
    echo "services:"
    echo "  otel-collector:"
    echo "    command:"
    echo "      - --feature-gates=confmap.enableMergeAppendOption"
    for cfg in "${CONFIGS[@]}"; do
      echo "      - --config=file:/etc/otelcol-contrib/${cfg}"
    done
  } > "${FANOUT_FILE}"
  compose_args+=(-f "${FANOUT_FILE}")
fi
if [[ -n "${OPENLIT_CA_BUNDLE:-}" ]]; then
  compose_args+=(-f "${ROOT}/compose.openlit-ca.yaml")
fi
for profile in "${PROFILES[@]}"; do
  compose_args+=(--profile "${profile}")
done

"${COMPOSE[@]}" "${compose_args[@]}" up -d --build

echo
echo "Host OTLP gRPC:                  http://localhost:4317"
echo "Host OTLP HTTP:                  http://localhost:4318"
echo "Collector health:                http://localhost:13133"
if has_mode openobserve; then
  echo "OpenObserve UI:                  http://localhost:5080"
fi
if has_mode openlit; then
  echo "OpenLIT UI:                      http://localhost:${OPENLIT_UI_PORT:-3000}"
fi
if has_mode victoriametrics; then
  echo "VictoriaMetrics UI (vmui):       http://localhost:${VICTORIAMETRICS_UI_PORT:-8428}/vmui/"
fi
