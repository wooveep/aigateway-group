#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/dev-shell-lib.sh"

CONFIG_FILE="${REPO_ROOT}/helm/dev-mode.yaml"
NAMESPACE=""
RELEASE_NAME=""
BIND_ADDRESS=""
LOCAL_PORT_START=""
WAIT_READY_SECONDS=""
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage:
  ./scripts/port-forward-all.sh [options]

Options:
  --config <path>              Dev config file. Default: ./helm/dev-mode.yaml
  --namespace <name>           Override namespace
  --release <name>             Override Helm release name
  --bind-address <address>     Override bind address
  --local-port-start <port>    Override fallback local port start
  --wait-ready-seconds <sec>   Override service readiness timeout
  --dry-run                    Print mappings only
  -h, --help                   Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --release)
      RELEASE_NAME="$2"
      shift 2
      ;;
    --bind-address)
      BIND_ADDRESS="$2"
      shift 2
      ;;
    --local-port-start)
      LOCAL_PORT_START="$2"
      shift 2
      ;;
    --wait-ready-seconds)
      WAIT_READY_SECONDS="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      dev_die "Unknown argument: $1"
      ;;
  esac
done

[[ -f "${CONFIG_FILE}" ]] || dev_die "Config file not found: ${CONFIG_FILE}"

dev_need_cmd kubectl
dev_need_cmd jq
dev_need_cmd ss

NAMESPACE="${NAMESPACE:-$(yaml_get_scalar "${CONFIG_FILE}" "dev.namespace" "aigateway-system")}"
RELEASE_NAME="${RELEASE_NAME:-$(yaml_get_scalar "${CONFIG_FILE}" "dev.releaseName" "aigateway")}"
BIND_ADDRESS="${BIND_ADDRESS:-$(yaml_get_scalar "${CONFIG_FILE}" "dev.portForward.bindAddress" "127.0.0.1")}"
LOCAL_PORT_START="${LOCAL_PORT_START:-$(yaml_get_scalar "${CONFIG_FILE}" "dev.portForward.localPortStart" "20000")}"
WAIT_READY_SECONDS="${WAIT_READY_SECONDS:-$(yaml_get_scalar "${CONFIG_FILE}" "dev.portForward.waitReadySeconds" "180")}"

declare -A INCLUDE_SERVICES=()
declare -A SKIP_SERVICES=()
declare -A USED_PORTS=()
declare -A PORT_OVERRIDES=()
declare -A READY_CACHE=()
declare -a PF_PIDS=()
declare -a PF_LOGS=()

while IFS= read -r service; do
  [[ -z "${service}" ]] && continue
  INCLUDE_SERVICES["${service}"]=1
done < <(yaml_get_list "${CONFIG_FILE}" "dev.portForward.includeServices")

while IFS= read -r service; do
  [[ -z "${service}" ]] && continue
  SKIP_SERVICES["${service}"]=1
done < <(yaml_get_list "${CONFIG_FILE}" "dev.portForward.skipServices")

load_service_overrides() {
  local service="$1"
  local pair key value

  while IFS= read -r pair; do
    [[ -z "${pair}" ]] && continue
    key="${pair%%=*}"
    value="${pair#*=}"
    PORT_OVERRIDES["${service}|${key}"]="${value}"
  done < <(yaml_get_map_pairs "${CONFIG_FILE}" "dev.portForward.servicePorts.${service}")
}

is_port_free() {
  local bind_address="$1"
  local port="$2"

  if ss -ltn "( sport = :${port} )" 2>/dev/null | awk 'NR > 1 { found = 1 } END { exit found ? 1 : 0 }'; then
    return 0
  fi

  return 1
}

choose_local_port() {
  local bind_address="$1"
  local remote_port="$2"
  local preferred_port="${3:-}"

  if [[ -n "${preferred_port}" ]]; then
    [[ -z "${USED_PORTS[${preferred_port}]:-}" ]] || dev_die "Preferred port already reserved: ${preferred_port}"
    is_port_free "${bind_address}" "${preferred_port}" || dev_die "Preferred local port is already occupied: ${preferred_port}"
    USED_PORTS["${preferred_port}"]=1
    printf '%s\n' "${preferred_port}"
    return 0
  fi

  if [[ -z "${USED_PORTS[${remote_port}]:-}" ]] && is_port_free "${bind_address}" "${remote_port}"; then
    USED_PORTS["${remote_port}"]=1
    printf '%s\n' "${remote_port}"
    return 0
  fi

  local candidate="${LOCAL_PORT_START}"
  while [[ -n "${USED_PORTS[${candidate}]:-}" ]] || ! is_port_free "${bind_address}" "${candidate}"; do
    candidate=$((candidate + 1))
  done
  USED_PORTS["${candidate}"]=1
  LOCAL_PORT_START=$((candidate + 1))
  printf '%s\n' "${candidate}"
}

service_has_ready_endpoints() {
  local service="$1"
  local ready

  ready="$(
    kubectl -n "${NAMESPACE}" get endpointslices.discovery.k8s.io \
      -l "kubernetes.io/service-name=${service}" \
      -o json 2>/dev/null | jq -r '
        any(.items[]?; any(.endpoints[]?; (.addresses | length > 0) and ((.conditions.ready // true) != false)))
      ' 2>/dev/null || true
  )"

  if [[ "${ready}" == "true" ]]; then
    return 0
  fi

  ready="$(
    kubectl -n "${NAMESPACE}" get endpoints "${service}" -o json 2>/dev/null | jq -r '
      any(.subsets[]?; (.addresses // []) | length > 0)
    ' 2>/dev/null || true
  )"
  [[ "${ready}" == "true" ]]
}

wait_for_service() {
  local service="$1"
  local deadline=$((SECONDS + WAIT_READY_SECONDS))

  while (( SECONDS < deadline )); do
    if service_has_ready_endpoints "${service}"; then
      return 0
    fi
    sleep 1
  done

  return 1
}

cleanup() {
  local pid

  for pid in "${PF_PIDS[@]:-}"; do
    kill "${pid}" >/dev/null 2>&1 || true
  done
  wait >/dev/null 2>&1 || true
}

trap cleanup INT TERM EXIT

QUERY_ARGS=(-n "${NAMESPACE}" get svc -o json)
if [[ ${#INCLUDE_SERVICES[@]} -eq 0 ]]; then
  QUERY_ARGS=(-n "${NAMESPACE}" get svc -l "app.kubernetes.io/instance=${RELEASE_NAME}" -o json)
fi

SERVICE_LINES="$(
  kubectl "${QUERY_ARGS[@]}" | jq -r '
    .items
    | sort_by(.metadata.name)
    | .[]
    | .metadata.name as $name
    | (.spec.ports // [])[]
    | [$name, (.port | tostring), (.name // "")]
    | @tsv
  '
)"

[[ -n "${SERVICE_LINES}" ]] || dev_die "No services found for release=${RELEASE_NAME} in namespace=${NAMESPACE}"

declare -a MAPPINGS=()

while IFS=$'\t' read -r service remote_port port_name; do
  [[ -z "${service}" ]] && continue
  [[ -z "${SKIP_SERVICES[${service}]:-}" ]] || continue
  if [[ ${#INCLUDE_SERVICES[@]} -gt 0 && -z "${INCLUDE_SERVICES[${service}]:-}" ]]; then
    continue
  fi

  load_service_overrides "${service}"

  preferred_port=""
  if [[ -n "${port_name}" && -n "${PORT_OVERRIDES[${service}|${port_name}]:-}" ]]; then
    preferred_port="${PORT_OVERRIDES[${service}|${port_name}]}"
  elif [[ -n "${PORT_OVERRIDES[${service}|${remote_port}]:-}" ]]; then
    preferred_port="${PORT_OVERRIDES[${service}|${remote_port}]}"
  fi

  local_port="$(choose_local_port "${BIND_ADDRESS}" "${remote_port}" "${preferred_port}")"
  MAPPINGS+=("${service}|${remote_port}|${local_port}")
done <<< "${SERVICE_LINES}"

[[ ${#MAPPINGS[@]} -gt 0 ]] || dev_die "No service ports selected for port-forward"

echo "[INFO] service port mapping:"
for mapping in "${MAPPINGS[@]}"; do
  IFS='|' read -r service remote_port local_port <<< "${mapping}"
  echo "  - ${service}: ${BIND_ADDRESS}:${local_port} -> ${remote_port}"
done

if [[ "${DRY_RUN}" == "true" ]]; then
  exit 0
fi

LOG_DIR="${REPO_ROOT}/.logs/port-forward"
mkdir -p "${LOG_DIR}"

for mapping in "${MAPPINGS[@]}"; do
  IFS='|' read -r service remote_port local_port <<< "${mapping}"

  if [[ -z "${READY_CACHE[${service}]:-}" ]]; then
    echo "[INFO] waiting service ready endpoints: ${service} (timeout=${WAIT_READY_SECONDS}s)"
    if wait_for_service "${service}"; then
      READY_CACHE["${service}"]=ready
    else
      READY_CACHE["${service}"]=skip
      dev_warn "Service has no ready endpoints after timeout, skip: ${service}"
    fi
  fi

  [[ "${READY_CACHE[${service}]}" == "ready" ]] || continue

  log_file="${LOG_DIR}/${service}-${local_port}-${remote_port}.log"
  kubectl -n "${NAMESPACE}" port-forward "svc/${service}" "${local_port}:${remote_port}" --address "${BIND_ADDRESS}" \
    >> "${log_file}" 2>&1 &
  PF_PIDS+=("$!")
  PF_LOGS+=("${service}|${local_port}|${remote_port}|${log_file}")
done

[[ ${#PF_PIDS[@]} -gt 0 ]] || dev_die "No running port-forward process started"

echo "[READY] port-forward started. Press Ctrl+C to stop all forwards."

while true; do
  for idx in "${!PF_PIDS[@]}"; do
    pid="${PF_PIDS[${idx}]}"
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      IFS='|' read -r service local_port remote_port log_file <<< "${PF_LOGS[${idx}]}"
      dev_die "port-forward exited: svc/${service} ${local_port}:${remote_port}, log=${log_file}"
    fi
  done
  sleep 1
done
