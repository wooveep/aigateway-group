#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Keep a single chart source of truth in higress/helm/higress.
PRIMARY_CHART_DIR="${ROOT_DIR}/higress/helm/higress"
LEGACY_CHART_DIR="${ROOT_DIR}/helm/higress"
if [[ -d "${PRIMARY_CHART_DIR}" ]]; then
  DEFAULT_CHART_DIR="${PRIMARY_CHART_DIR}"
else
  DEFAULT_CHART_DIR="${LEGACY_CHART_DIR}"
fi
DEFAULT_DEV_CONFIG="${ROOT_DIR}/helm/dev-mode.yaml"
DEFAULT_PROD_GRAY_VALUES="${DEFAULT_CHART_DIR}/values-production-gray.yaml"
DEFAULT_PROD_K3D_VALUES="${DEFAULT_CHART_DIR}/values-production-k3d.yaml"
if [[ -f "${DEFAULT_PROD_K3D_VALUES}" ]]; then
  DEFAULT_PROD_VALUES="${DEFAULT_PROD_K3D_VALUES}"
else
  DEFAULT_PROD_VALUES="${DEFAULT_PROD_GRAY_VALUES}"
fi
DEFAULT_LOCAL_VALUES="${DEFAULT_CHART_DIR}/values-local-minikube.yaml"
REDEPLOY_MINIKUBE_SCRIPT="${ROOT_DIR}/higress/helm/redeploy-minikube.sh"
REDEPLOY_K3D_SCRIPT="${ROOT_DIR}/higress/helm/redeploy-k3d.sh"

CHART_DIR="${CHART_DIR:-${DEFAULT_CHART_DIR}}"
CONFIG_FILE="${CONFIG_FILE:-${DEFAULT_DEV_CONFIG}}"
LOCAL_VALUES_FILE="${LOCAL_VALUES_FILE:-${DEFAULT_LOCAL_VALUES}}"
PROD_VALUES_FILE="${PROD_VALUES_FILE:-${DEFAULT_PROD_VALUES}}"
DEV_USE_MINIKUBE_REDEPLOY="${DEV_USE_MINIKUBE_REDEPLOY:-auto}"
DEV_REDEPLOY_SKIP_BUILD="${DEV_REDEPLOY_SKIP_BUILD:-false}"
DEV_REDEPLOY_SKIP_LOAD="${DEV_REDEPLOY_SKIP_LOAD:-false}"
DEV_REDEPLOY_SKIP_DEPLOY="${DEV_REDEPLOY_SKIP_DEPLOY:-false}"
PROD_USE_K3D_REDEPLOY="${PROD_USE_K3D_REDEPLOY:-auto}"
PROD_REDEPLOY_SKIP_BUILD="${PROD_REDEPLOY_SKIP_BUILD:-false}"
PROD_REDEPLOY_SKIP_LOAD="${PROD_REDEPLOY_SKIP_LOAD:-false}"
PROD_REDEPLOY_SKIP_DEPLOY="${PROD_REDEPLOY_SKIP_DEPLOY:-false}"
HELM_DEPENDENCY_BUILD="${HELM_DEPENDENCY_BUILD:-true}"
BUILD_COMPONENTS="${BUILD_COMPONENTS:-aigateway,controller,gateway,pilot,console,portal,plugins,plugin-server}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-}"
K3D_CLUSTER="${K3D_CLUSTER:-}"

if [[ -d "${CHART_DIR}" ]]; then
  CHART_DIR="$(cd "${CHART_DIR}" && pwd -P)"
fi

if [[ -f "${LOCAL_VALUES_FILE}" ]]; then
  LOCAL_VALUES_FILE="$(cd "$(dirname "${LOCAL_VALUES_FILE}")" && pwd -P)/$(basename "${LOCAL_VALUES_FILE}")"
fi

if [[ -f "${PROD_VALUES_FILE}" ]]; then
  PROD_VALUES_FILE="$(cd "$(dirname "${PROD_VALUES_FILE}")" && pwd -P)/$(basename "${PROD_VALUES_FILE}")"
fi

extract_config_value() {
  local path="$1"
  local fallback="$2"
  python3 - "$CONFIG_FILE" "$path" "$fallback" <<'PY'
import sys

try:
    import yaml
except Exception:
    print(sys.argv[3])
    raise SystemExit(0)

config_path, dotted, fallback = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(config_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
except Exception:
    print(fallback)
    raise SystemExit(0)

cursor = data
for key in dotted.split('.'):
    if isinstance(cursor, dict) and key in cursor:
        cursor = cursor[key]
    else:
        print(fallback)
        raise SystemExit(0)

if cursor is None:
    print(fallback)
else:
    print(cursor)
PY
}

RELEASE_NAME="${RELEASE_NAME:-$(extract_config_value dev.releaseName aigateway)}"
NAMESPACE="${NAMESPACE:-$(extract_config_value dev.namespace aigateway-system)}"

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[ERROR] Missing command: ${cmd}" >&2
    exit 1
  fi
}

current_context() {
  kubectl config current-context 2>/dev/null || true
}

is_minikube_context() {
  local context
  context="$(current_context)"
  [[ "${context}" == minikube* ]]
}

is_k3d_context() {
  local context
  context="$(current_context)"
  [[ "${context}" == k3d-* ]]
}

should_use_minikube_redeploy() {
  case "${DEV_USE_MINIKUBE_REDEPLOY}" in
    true|TRUE|1)
      return 0
      ;;
    false|FALSE|0)
      return 1
      ;;
    auto|AUTO)
      if [[ ! -x "${REDEPLOY_MINIKUBE_SCRIPT}" ]]; then
        return 1
      fi
      if [[ ! -f "${LOCAL_VALUES_FILE}" ]]; then
        return 1
      fi
      is_minikube_context
      return
      ;;
    *)
      echo "[WARN] Unsupported DEV_USE_MINIKUBE_REDEPLOY=${DEV_USE_MINIKUBE_REDEPLOY}, fallback to auto." >&2
      DEV_USE_MINIKUBE_REDEPLOY="auto"
      should_use_minikube_redeploy
      return
      ;;
  esac
}

should_use_k3d_redeploy() {
  case "${PROD_USE_K3D_REDEPLOY}" in
    true|TRUE|1)
      return 0
      ;;
    false|FALSE|0)
      return 1
      ;;
    auto|AUTO)
      if [[ ! -x "${REDEPLOY_K3D_SCRIPT}" ]]; then
        return 1
      fi
      if [[ ! -f "${PROD_VALUES_FILE}" ]]; then
        return 1
      fi
      is_k3d_context
      return
      ;;
    *)
      echo "[WARN] Unsupported PROD_USE_K3D_REDEPLOY=${PROD_USE_K3D_REDEPLOY}, fallback to auto." >&2
      PROD_USE_K3D_REDEPLOY="auto"
      should_use_k3d_redeploy
      return
      ;;
  esac
}

merge_values_files() {
  local base_file="$1"
  local overlay_file="$2"
  local output_file="$3"

  python3 - "${base_file}" "${overlay_file}" "${output_file}" <<'PY'
import copy
import sys
import yaml

base_file, overlay_file, output_file = sys.argv[1:4]

with open(base_file, "r", encoding="utf-8") as f:
    base = yaml.safe_load(f) or {}
with open(overlay_file, "r", encoding="utf-8") as f:
    overlay = yaml.safe_load(f) or {}

def deep_merge(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        merged = copy.deepcopy(a)
        for key, value in b.items():
            merged[key] = deep_merge(merged.get(key), value)
        return merged
    return copy.deepcopy(b)

merged = deep_merge(base, overlay)

with open(output_file, "w", encoding="utf-8") as f:
    yaml.safe_dump(merged, f, sort_keys=False)
PY
}

dev_redeploy_minikube() {
  local merged_values_file
  local args

  if [[ ! -x "${REDEPLOY_MINIKUBE_SCRIPT}" ]]; then
    echo "[ERROR] Redeploy script not found or not executable: ${REDEPLOY_MINIKUBE_SCRIPT}" >&2
    exit 1
  fi

  if [[ ! -f "${LOCAL_VALUES_FILE}" ]]; then
    echo "[ERROR] Local values file not found: ${LOCAL_VALUES_FILE}" >&2
    exit 1
  fi

  require_cmd docker
  require_cmd minikube
  require_cmd python3

  merged_values_file="$(mktemp "${TMPDIR:-/tmp}/aigateway-dev-values.XXXXXX.yaml")"
  trap "rm -f '${merged_values_file}'" RETURN
  merge_values_files "${LOCAL_VALUES_FILE}" "${CONFIG_FILE}" "${merged_values_file}"

  args=(--values "${merged_values_file}" --namespace "${NAMESPACE}" --release "${RELEASE_NAME}" --components "${BUILD_COMPONENTS}")
  if [[ -n "${MINIKUBE_PROFILE}" ]]; then
    args+=(--profile "${MINIKUBE_PROFILE}")
  fi
  if [[ "${DEV_REDEPLOY_SKIP_BUILD}" == "true" ]]; then
    args+=(--skip-build)
  fi
  if [[ "${DEV_REDEPLOY_SKIP_LOAD}" == "true" ]]; then
    args+=(--skip-load)
  fi
  if [[ "${DEV_REDEPLOY_SKIP_DEPLOY}" == "true" ]]; then
    args+=(--skip-deploy)
  fi

  echo "[INFO] minikube context detected, run redeploy flow for local images."
  "${REDEPLOY_MINIKUBE_SCRIPT}" "${args[@]}"
}

prod_redeploy_k3d() {
  local values_file="${1:-${PROD_VALUES_FILE}}"
  local args

  if [[ ! -x "${REDEPLOY_K3D_SCRIPT}" ]]; then
    echo "[ERROR] Redeploy script not found or not executable: ${REDEPLOY_K3D_SCRIPT}" >&2
    exit 1
  fi

  if [[ ! -f "${values_file}" ]]; then
    echo "[ERROR] Production values file not found: ${values_file}" >&2
    exit 1
  fi

  require_cmd docker
  require_cmd k3d
  require_cmd python3

  args=(--values "${values_file}" --namespace "${NAMESPACE}" --release "${RELEASE_NAME}" --components "${BUILD_COMPONENTS}")
  if [[ -n "${K3D_CLUSTER}" ]]; then
    args+=(--cluster "${K3D_CLUSTER}")
  fi
  if [[ "${PROD_REDEPLOY_SKIP_BUILD}" == "true" ]]; then
    args+=(--skip-build)
  fi
  if [[ "${PROD_REDEPLOY_SKIP_LOAD}" == "true" ]]; then
    args+=(--skip-load)
  fi
  if [[ "${PROD_REDEPLOY_SKIP_DEPLOY}" == "true" ]]; then
    args+=(--skip-deploy)
  fi

  echo "[INFO] k3d context detected, run production redeploy flow for local images."
  "${REDEPLOY_K3D_SCRIPT}" "${args[@]}"
}

helm_up() {
  local values_file="$1"
  shift

  if [[ ! -f "${values_file}" ]]; then
    echo "[ERROR] Values file not found: ${values_file}" >&2
    exit 1
  fi

  if [[ ! -d "${CHART_DIR}" ]]; then
    echo "[ERROR] Chart directory not found: ${CHART_DIR}" >&2
    exit 1
  fi

  if [[ "${HELM_DEPENDENCY_BUILD:-false}" == "true" ]]; then
    echo "[INFO] helm dependency build ${CHART_DIR}"
    helm dependency build "${CHART_DIR}"
  fi

  echo "[INFO] helm upgrade --install ${RELEASE_NAME} (${NAMESPACE})"
  helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    -f "${values_file}" \
    "$@"
}

print_help() {
  cat <<EOF_HELP
Usage:
  ./start.sh dev [extra-helm-args...]
  ./start.sh dev-redeploy
  ./start.sh deploy [values-file] [extra-helm-args...]
  ./start.sh deploy-prod [values-file] [extra-helm-args...]
  ./start.sh prod-redeploy [values-file]
  ./start.sh port-forward
  ./start.sh status
  ./start.sh down

Env overrides:
  CHART_DIR, CONFIG_FILE, LOCAL_VALUES_FILE, PROD_VALUES_FILE, RELEASE_NAME, NAMESPACE, HELM_DEPENDENCY_BUILD
  DEV_USE_MINIKUBE_REDEPLOY (auto|true|false), BUILD_COMPONENTS, MINIKUBE_PROFILE
  DEV_REDEPLOY_SKIP_BUILD, DEV_REDEPLOY_SKIP_LOAD, DEV_REDEPLOY_SKIP_DEPLOY
  PROD_USE_K3D_REDEPLOY (auto|true|false), K3D_CLUSTER
  PROD_REDEPLOY_SKIP_BUILD, PROD_REDEPLOY_SKIP_LOAD, PROD_REDEPLOY_SKIP_DEPLOY

Examples:
  ./start.sh dev
  ./start.sh dev-redeploy
  DEV_USE_MINIKUBE_REDEPLOY=false ./start.sh dev
  ./start.sh deploy ./helm/dev-mode.yaml
  ./start.sh deploy-prod
  ./start.sh prod-redeploy
  K3D_CLUSTER=prod ./start.sh prod-redeploy
  RELEASE_NAME=aigateway-dev NAMESPACE=dev-system ./start.sh dev
EOF_HELP
}

main() {
  local cmd="${1:-help}"

  require_cmd helm
  require_cmd kubectl

  case "${cmd}" in
    dev)
      shift
      if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
        print_help
        return 0
      fi
      if [[ $# -eq 0 ]] && should_use_minikube_redeploy; then
        dev_redeploy_minikube
      else
        helm_up "${CONFIG_FILE}" "$@"
      fi
      "${ROOT_DIR}/scripts/port-forward-all.py" \
        --config "${CONFIG_FILE}" \
        --namespace "${NAMESPACE}" \
        --release "${RELEASE_NAME}"
      ;;
    dev-redeploy)
      shift
      if [[ $# -ne 0 ]]; then
        echo "[ERROR] dev-redeploy does not accept extra arguments." >&2
        exit 1
      fi
      dev_redeploy_minikube
      "${ROOT_DIR}/scripts/port-forward-all.py" \
        --config "${CONFIG_FILE}" \
        --namespace "${NAMESPACE}" \
        --release "${RELEASE_NAME}"
      ;;
    deploy)
      shift
      if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
        print_help
        return 0
      fi
      local values_file="${1:-${CONFIG_FILE}}"
      if [[ $# -gt 0 ]]; then
        shift
      fi
      helm_up "${values_file}" "$@"
      ;;
    deploy-prod)
      shift
      if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
        print_help
        return 0
      fi
      local values_file="${1:-${PROD_VALUES_FILE}}"
      if [[ $# -gt 0 ]]; then
        shift
      fi
      if [[ $# -eq 0 ]] && should_use_k3d_redeploy; then
        prod_redeploy_k3d "${values_file}"
      else
        helm_up "${values_file}" "$@"
      fi
      ;;
    prod-redeploy)
      shift
      local values_file="${1:-${PROD_VALUES_FILE}}"
      if [[ $# -gt 0 ]]; then
        shift
      fi
      if [[ $# -ne 0 ]]; then
        echo "[ERROR] prod-redeploy only accepts an optional values-file argument." >&2
        exit 1
      fi
      prod_redeploy_k3d "${values_file}"
      ;;
    port-forward)
      "${ROOT_DIR}/scripts/port-forward-all.py" \
        --config "${CONFIG_FILE}" \
        --namespace "${NAMESPACE}" \
        --release "${RELEASE_NAME}"
      ;;
    status)
      helm -n "${NAMESPACE}" status "${RELEASE_NAME}"
      ;;
    down)
      helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}"
      ;;
    help|-h|--help)
      print_help
      ;;
    *)
      echo "[ERROR] Unsupported command: ${cmd}" >&2
      print_help
      exit 1
      ;;
  esac
}

main "$@"
