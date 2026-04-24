#!/usr/bin/env bash

set -euo pipefail

CLUSTER=""
NAMESPACE="aigateway-system"
BASE_DOMAIN=""
SERVERS="1"
AGENTS="2"
HTTP_PORT="80"
HTTPS_PORT="443"
SKIP_CREATE=false
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage:
  release-k3d-cluster.sh --cluster <name> --base-domain <domain> [options]

Options:
  --cluster <name>        k3d cluster name.
  --base-domain <domain>  Console/Portal base domain. Hosts become console.<domain>/portal.<domain>.
  --namespace <name>      Namespace used to store the cluster domain config. Default: aigateway-system.
  --servers <n>           k3d server count. Default: 1.
  --agents <n>            k3d agent count. Default: 2.
  --http-port <port>      Host HTTP port mapped to k3d loadbalancer. Default: 80.
  --https-port <port>     Host HTTPS port mapped to k3d loadbalancer. Default: 443.
  --skip-create           Do not create the cluster; only write the domain config.
  --dry-run               Print actions only.
  -h, --help              Show help.
EOF
}

run() {
  echo "+ $*"
  if [[ "${DRY_RUN}" != "true" ]]; then
    "$@"
  fi
}

apply_domain_config() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "+ kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
    echo "+ kubectl -n ${NAMESPACE} create configmap aigateway-cluster-domain --from-literal=baseDomain=${BASE_DOMAIN} --from-literal=consoleHost=console.${BASE_DOMAIN} --from-literal=portalHost=portal.${BASE_DOMAIN} --dry-run=client -o yaml | kubectl apply -f -"
    echo "+ kubectl annotate namespace ${NAMESPACE} aigateway.io/ingress-base-domain=${BASE_DOMAIN} --overwrite"
    return 0
  fi

  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${NAMESPACE}" create configmap aigateway-cluster-domain \
    --from-literal="baseDomain=${BASE_DOMAIN}" \
    --from-literal="consoleHost=console.${BASE_DOMAIN}" \
    --from-literal="portalHost=portal.${BASE_DOMAIN}" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl annotate namespace "${NAMESPACE}" "aigateway.io/ingress-base-domain=${BASE_DOMAIN}" --overwrite
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      CLUSTER="$2"
      shift 2
      ;;
    --base-domain)
      BASE_DOMAIN="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
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
    --skip-create)
      SKIP_CREATE=true
      shift
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
      echo "[ERROR] Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

[[ -n "${CLUSTER}" ]] || { echo "[ERROR] --cluster is required" >&2; exit 1; }
[[ -n "${BASE_DOMAIN}" ]] || { echo "[ERROR] --base-domain is required" >&2; exit 1; }

command -v kubectl >/dev/null 2>&1 || { echo "[ERROR] Missing required command: kubectl" >&2; exit 1; }
if [[ "${SKIP_CREATE}" != "true" ]]; then
  if [[ "${DRY_RUN}" != "true" ]]; then
    command -v k3d >/dev/null 2>&1 || { echo "[ERROR] Missing required command: k3d" >&2; exit 1; }
  fi
  run k3d cluster create "${CLUSTER}" \
    --servers "${SERVERS}" \
    --agents "${AGENTS}" \
    --k3s-arg "--disable=traefik@server:*" \
    --port "${HTTP_PORT}:80@loadbalancer" \
    --port "${HTTPS_PORT}:443@loadbalancer" \
    --wait
fi

apply_domain_config

echo "k3d cluster domain configured."
echo "  cluster   : ${CLUSTER}"
echo "  namespace : ${NAMESPACE}"
echo "  console   : console.${BASE_DOMAIN}"
echo "  portal    : portal.${BASE_DOMAIN}"
