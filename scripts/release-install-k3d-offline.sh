#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BUNDLE_DIR="${SCRIPT_DIR}"
DEFAULT_INSTALL_ROOT="/opt/aigateway-install/1.1.0"

BUNDLE_DIR="${BUNDLE_DIR:-${DEFAULT_BUNDLE_DIR}}"
RUNTIME_PACKAGE="${RUNTIME_PACKAGE:-}"
INSTALL_ROOT="${INSTALL_ROOT:-${DEFAULT_INSTALL_ROOT}}"
CLUSTER="${CLUSTER:-aigateway-110}"
NAMESPACE="${NAMESPACE:-aigateway-system}"
BASE_DOMAIN="${BASE_DOMAIN:-aigateway.io}"
PROFILE="${PROFILE:-standard}"
SERVERS="${SERVERS:-1}"
AGENTS="${AGENTS:-0}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
HELM_TIMEOUT="${HELM_TIMEOUT:-20m}"
RECREATE_CLUSTER=false
SKIP_RUNTIME=false
SKIP_DEPLOY=false

usage() {
  cat <<'EOF'
Usage:
  install-k3d-offline.sh [options]

Options:
  --runtime-package <tar.gz>  Runtime package with Docker/k3d/kubectl/Helm/k3s images.
  --bundle-dir <path>         Release bundle directory. Default: script directory.
  --install-root <path>       Working install directory. Default: /opt/aigateway-install/1.1.0.
  --cluster <name>            k3d cluster name. Default: aigateway-110.
  --namespace <name>          Kubernetes namespace. Default: aigateway-system.
  --base-domain <domain>      Console/Portal base domain. Default: aigateway.io.
  --profile standard|ha       Helm profile. Default: standard.
  --servers <n>               k3d server count. Default: 1.
  --agents <n>                k3d agent count. Default: 0.
  --http-port <port>          Host HTTP port for k3d loadbalancer. Default: 80.
  --https-port <port>         Host HTTPS port for k3d loadbalancer. Default: 443.
  --recreate-cluster          Delete existing k3d cluster before creating it.
  --skip-runtime              Skip runtime package install.
  --skip-deploy               Stop after runtime install, cluster creation, and image import.
  -h, --help                  Show help.

Examples:
  ./install-k3d-offline.sh \
    --runtime-package /opt/aigateway-install/1.1.0/offline-packages/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-20260424.tar.gz \
    --base-domain aigateway.io
EOF
}

log() {
  printf '[install] %s\n' "$*"
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

abs_path() {
  local path="$1"
  if [[ -d "${path}" ]]; then
    (cd "${path}" && pwd -P)
  else
    local dir base
    dir="$(dirname "${path}")"
    base="$(basename "${path}")"
    (cd "${dir}" && printf '%s/%s\n' "$(pwd -P)" "${base}")
  fi
}

find_runtime_package() {
  local candidate
  for candidate in \
    "${SCRIPT_DIR}"/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-*.tar.gz \
    "${SCRIPT_DIR}"/../offline-packages/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-*.tar.gz \
    "${INSTALL_ROOT}"/offline-packages/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-*.tar.gz \
    /opt/aigateway-install/1.1.0/offline-packages/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-*.tar.gz; do
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

install_runtime() {
  [[ "${SKIP_RUNTIME}" == "true" ]] && return 0

  if [[ -z "${RUNTIME_PACKAGE}" ]]; then
    RUNTIME_PACKAGE="$(find_runtime_package || true)"
  fi
  [[ -n "${RUNTIME_PACKAGE}" && -f "${RUNTIME_PACKAGE}" ]] || die "Runtime package not found. Pass --runtime-package <tar.gz>."

  RUNTIME_PACKAGE="$(abs_path "${RUNTIME_PACKAGE}")"
  mkdir -p "${INSTALL_ROOT}/runtime"
  log "Extracting runtime package: ${RUNTIME_PACKAGE}"
  tar -C "${INSTALL_ROOT}/runtime" -xzf "${RUNTIME_PACKAGE}"
  log "Installing Docker/k3d/kubectl/Helm and loading k3d system images"
  bash "${INSTALL_ROOT}/runtime/offline-packages/install-runtime-offline.sh"
}

cluster_exists() {
  k3d cluster list -o json 2>/dev/null | grep -q "\"name\":\"${CLUSTER}\""
}

create_cluster() {
  need_cmd k3d
  need_cmd kubectl

  if [[ "${RECREATE_CLUSTER}" == "true" ]] && cluster_exists; then
    log "Deleting existing k3d cluster: ${CLUSTER}"
    k3d cluster delete "${CLUSTER}"
  fi

  if ! cluster_exists; then
    log "Creating k3d cluster ${CLUSTER} (${SERVERS} server, ${AGENTS} agents)"
    k3d cluster create "${CLUSTER}" \
      --servers "${SERVERS}" \
      --agents "${AGENTS}" \
      --k3s-arg "--disable=traefik@server:*" \
      --port "${HTTP_PORT}:80@loadbalancer" \
      --port "${HTTPS_PORT}:443@loadbalancer" \
      --wait
  else
    log "Using existing k3d cluster: ${CLUSTER}"
    k3d kubeconfig merge "${CLUSTER}" --kubeconfig-switch-context >/dev/null
  fi

  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${NAMESPACE}" create configmap aigateway-cluster-domain \
    --from-literal="baseDomain=${BASE_DOMAIN}" \
    --from-literal="consoleHost=console.${BASE_DOMAIN}" \
    --from-literal="portalHost=portal.${BASE_DOMAIN}" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl annotate namespace "${NAMESPACE}" "aigateway.io/ingress-base-domain=${BASE_DOMAIN}" --overwrite
}

k3d_node_containers() {
  docker ps --format '{{.Names}}' |
    grep -E "^k3d-${CLUSTER}-(server|agent)-[0-9]+$" |
    sort
}

import_release_images() {
  need_cmd docker
  [[ -d "${BUNDLE_DIR}/images" ]] || die "Bundle images directory not found: ${BUNDLE_DIR}/images"

  local image_tar node tmp_path
  log "Loading release images into Docker"
  while IFS= read -r image_tar; do
    [[ -n "${image_tar}" ]] || continue
    docker load -i "${image_tar}"
  done < <(find "${BUNDLE_DIR}/images" -maxdepth 1 -type f -name '*.tar' | sort)

  mapfile -t nodes < <(k3d_node_containers)
  [[ "${#nodes[@]}" -gt 0 ]] || die "No k3d node containers found for cluster: ${CLUSTER}"

  log "Importing release image archives into k3d node containerd"
  while IFS= read -r image_tar; do
    [[ -n "${image_tar}" ]] || continue
    for node in "${nodes[@]}"; do
      tmp_path="/tmp/$(basename "${image_tar}")"
      docker cp "${image_tar}" "${node}:${tmp_path}"
      docker exec "${node}" ctr -n k8s.io images import "${tmp_path}"
      docker exec "${node}" rm -f "${tmp_path}"
    done
  done < <(find "${BUNDLE_DIR}/images" -maxdepth 1 -type f -name '*.tar' | sort)
}

import_k3d_system_images() {
  local system_image_dir="${INSTALL_ROOT}/runtime/k3d-images"
  local image_tar node tmp_path

  [[ -d "${system_image_dir}" ]] || {
    log "No extracted k3d system image directory found at ${system_image_dir}; skipping node import."
    return 0
  }

  mapfile -t nodes < <(k3d_node_containers)
  [[ "${#nodes[@]}" -gt 0 ]] || die "No k3d node containers found for cluster: ${CLUSTER}"

  log "Importing k3d/k3s system image archives into k3d node containerd"
  while IFS= read -r image_tar; do
    [[ -n "${image_tar}" ]] || continue
    for node in "${nodes[@]}"; do
      tmp_path="/tmp/$(basename "${image_tar}")"
      docker cp "${image_tar}" "${node}:${tmp_path}"
      docker exec "${node}" ctr -n k8s.io images import "${tmp_path}"
      docker exec "${node}" rm -f "${tmp_path}"
    done
  done < <(find "${system_image_dir}" -maxdepth 1 -type f -name '*.tar' | sort)
}

deploy_release() {
  [[ "${SKIP_DEPLOY}" == "true" ]] && return 0
  need_cmd helm
  HELM_TIMEOUT="${HELM_TIMEOUT}" bash "${BUNDLE_DIR}/deploy.sh" \
    --target k3d \
    --bundle-dir "${BUNDLE_DIR}" \
    --cluster "${CLUSTER}" \
    --namespace "${NAMESPACE}" \
    --profile "${PROFILE}" \
    --base-domain "${BASE_DOMAIN}" \
    --skip-import
}

verify_release() {
  kubectl -n "${NAMESPACE}" get deploy,sts,pod
  helm status aigateway -n "${NAMESPACE}" | sed -n '1,12p'
  log "Console: http://console.${BASE_DOMAIN}/"
  log "Portal : http://portal.${BASE_DOMAIN}/"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-package)
      RUNTIME_PACKAGE="$2"
      shift 2
      ;;
    --bundle-dir)
      BUNDLE_DIR="$2"
      shift 2
      ;;
    --install-root)
      INSTALL_ROOT="$2"
      shift 2
      ;;
    --cluster)
      CLUSTER="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --base-domain)
      BASE_DOMAIN="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --servers)
      SERVERS="$2"
      shift 2
      ;;
    --agents)
      AGENTS="$2"
      shift 2
      ;;
    --http-port)
      HTTP_PORT="$2"
      shift 2
      ;;
    --https-port)
      HTTPS_PORT="$2"
      shift 2
      ;;
    --recreate-cluster)
      RECREATE_CLUSTER=true
      shift
      ;;
    --skip-runtime)
      SKIP_RUNTIME=true
      shift
      ;;
    --skip-deploy)
      SKIP_DEPLOY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

BUNDLE_DIR="$(abs_path "${BUNDLE_DIR}")"
[[ -d "${BUNDLE_DIR}" ]] || die "Bundle directory not found: ${BUNDLE_DIR}"
[[ -f "${BUNDLE_DIR}/deploy.sh" ]] || die "Missing deploy.sh in bundle: ${BUNDLE_DIR}"
[[ -f "${BUNDLE_DIR}/metadata/SHA256SUMS" ]] || die "Missing metadata/SHA256SUMS in bundle: ${BUNDLE_DIR}"

mkdir -p "${INSTALL_ROOT}/logs"
LOG_FILE="${INSTALL_ROOT}/logs/install-k3d-offline-$(date +%Y%m%d%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

log "Install log: ${LOG_FILE}"
log "Bundle: ${BUNDLE_DIR}"
log "Cluster: ${CLUSTER}"
log "Namespace: ${NAMESPACE}"
log "Base domain: ${BASE_DOMAIN}"
log "Profile: ${PROFILE}"

install_runtime
need_cmd docker
need_cmd kubectl
need_cmd helm

log "Verifying bundle checksum"
(cd "${BUNDLE_DIR}" && sha256sum -c metadata/SHA256SUMS)

create_cluster
import_k3d_system_images
import_release_images
deploy_release
verify_release

log "AIGateway offline k3d install finished."
