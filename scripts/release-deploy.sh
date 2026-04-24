#!/usr/bin/env bash

set -euo pipefail

BUNDLE_DIR=""
TARGET=""
RELEASE_NAME="aigateway"
NAMESPACE="aigateway-system"
PROFILE="ha"
USER_PROVIDED_PROFILE=false
REGISTRY=""
IMAGE_PULL_SECRET=""
REPLICAS=""
DRY_RUN=false
SKIP_IMPORT=false
SKIP_PUSH=false
SKIP_DEPLOY=false
K3D_CLUSTER=""
INGRESS_BASE_DOMAIN=""
USER_PROVIDED_BASE_DOMAIN=false
CONSOLE_HOST=""
PORTAL_HOST=""
DOMAIN_CONFIG_NAME="aigateway-cluster-domain"
HELM_TIMEOUT="${HELM_TIMEOUT:-15m}"
EXTRA_SET_ARGS=()

usage() {
  cat <<'EOF'
Usage:
  release-deploy.sh --target k3d|k8s --bundle-dir <path> [options]

Options:
  --target k3d|k8s              Deployment target.
  --bundle-dir <path>           Release bundle directory.
  --release <name>              Helm release name.
  --namespace <name>            Kubernetes namespace.
  --profile standard|ha         Bundle profile.
  --registry <host[/prefix]>    Target registry for --target k8s.
  --image-pull-secret <name>    Optional image pull secret for k8s deploy.
  --replicas <csv>              e.g. gateway=3,controller=2,pluginServer=2,console=2,portal=2
  --cluster <name>              k3d cluster name. Default: inferred from current context.
  --base-domain <domain>        Console/Portal base domain. Hosts become console.<domain>/portal.<domain>.
  --console-host <host>         Console ingress host override.
  --portal-host <host>          Portal ingress host override.
  --skip-import                 Skip docker load / k3d import.
  --skip-push                   Skip docker push when target=k8s.
  --skip-deploy                 Skip helm upgrade.
  --set key=value               Additional Helm set values.
  --dry-run                     Print actions only.
  -h, --help                    Show help.
EOF
}

run() {
  echo "+ $*"
  if [[ "${DRY_RUN}" != "true" ]]; then
    "$@"
  fi
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

find_chart_package() {
  find "${BUNDLE_DIR}/charts" -maxdepth 1 -type f -name '*.tgz' | sort | head -n 1
}

sanitize_registry_target() {
  local image="$1"
  local without_registry
  if [[ "${image}" == */* && "${image%%/*}" == *.* ]]; then
    without_registry="${image#*/}"
  elif [[ "${image}" == */* && "${image%%/*}" == *:* ]]; then
    without_registry="${image#*/}"
  else
    without_registry="${image}"
  fi
  printf '%s/%s\n' "${REGISTRY%/}" "${without_registry}"
}

apply_replica_sets() {
  local csv="$1"
  local entry key value
  [[ -n "${csv}" ]] || return 0
  IFS=',' read -r -a entries <<< "${csv}"
  for entry in "${entries[@]}"; do
    key="${entry%%=*}"
    value="${entry#*=}"
    case "${key}" in
      gateway)
        EXTRA_SET_ARGS+=(--set-string "higress-core.gateway.replicas=${value}")
        ;;
      controller)
        EXTRA_SET_ARGS+=(--set-string "higress-core.controller.replicas=${value}")
        ;;
      pluginServer)
        EXTRA_SET_ARGS+=(--set-string "higress-core.pluginServer.replicas=${value}")
        ;;
      console)
        EXTRA_SET_ARGS+=(--set-string "aigateway-console.replicaCount=${value}")
        ;;
      portal)
        EXTRA_SET_ARGS+=(--set-string "aigateway-portal.backend.replicaCount=${value}")
        ;;
      *)
        die "Unsupported replica key: ${key}"
        ;;
    esac
  done
}

read_cluster_base_domain() {
  local base_domain
  base_domain="$(kubectl -n "${NAMESPACE}" get configmap "${DOMAIN_CONFIG_NAME}" -o jsonpath='{.data.baseDomain}' 2>/dev/null || true)"
  if [[ -z "${base_domain}" ]]; then
    base_domain="$(kubectl get namespace "${NAMESPACE}" -o jsonpath='{.metadata.annotations.aigateway\.io/ingress-base-domain}' 2>/dev/null || true)"
  fi
  printf '%s\n' "${base_domain}"
}

save_cluster_domain_config() {
  local base_domain="$1"
  [[ -n "${base_domain}" ]] || return 0

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "+ kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
    echo "+ kubectl -n ${NAMESPACE} create configmap ${DOMAIN_CONFIG_NAME} --from-literal=baseDomain=${base_domain} --from-literal=consoleHost=console.${base_domain} --from-literal=portalHost=portal.${base_domain} --dry-run=client -o yaml | kubectl apply -f -"
    echo "+ kubectl annotate namespace ${NAMESPACE} aigateway.io/ingress-base-domain=${base_domain} --overwrite"
    return 0
  fi

  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${NAMESPACE}" create configmap "${DOMAIN_CONFIG_NAME}" \
    --from-literal="baseDomain=${base_domain}" \
    --from-literal="consoleHost=console.${base_domain}" \
    --from-literal="portalHost=portal.${base_domain}" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl annotate namespace "${NAMESPACE}" "aigateway.io/ingress-base-domain=${base_domain}" --overwrite
}

apply_ingress_host_overrides() {
  local cluster_base_domain

  if [[ -z "${INGRESS_BASE_DOMAIN}" ]]; then
    cluster_base_domain="$(read_cluster_base_domain)"
    INGRESS_BASE_DOMAIN="${cluster_base_domain}"
  fi

  if [[ -n "${INGRESS_BASE_DOMAIN}" ]]; then
    [[ -n "${CONSOLE_HOST}" ]] || CONSOLE_HOST="console.${INGRESS_BASE_DOMAIN}"
    [[ -n "${PORTAL_HOST}" ]] || PORTAL_HOST="portal.${INGRESS_BASE_DOMAIN}"
  fi

  if [[ -n "${CONSOLE_HOST}" ]]; then
    EXTRA_SET_ARGS+=(--set "aigateway-console.ingress.enabled=true")
    EXTRA_SET_ARGS+=(--set-string "aigateway-console.ingress.domain=${CONSOLE_HOST}")
  fi

  if [[ -n "${PORTAL_HOST}" ]]; then
    EXTRA_SET_ARGS+=(--set "aigateway-portal.ingress.enabled=true")
    EXTRA_SET_ARGS+=(--set-string "aigateway-portal.ingress.className=aigateway")
    EXTRA_SET_ARGS+=(--set-string "aigateway-portal.ingress.host=${PORTAL_HOST}")
  fi
}

import_bundle_images() {
  local image_tar image_ref
  while IFS= read -r image_tar; do
    [[ -n "${image_tar}" ]] || continue
    run docker load -i "${image_tar}"
  done < <(find "${BUNDLE_DIR}/images" -maxdepth 1 -type f -name '*.tar' | sort)
}

current_k3d_cluster() {
  local context
  context="$(kubectl config current-context 2>/dev/null || true)"
  if [[ "${context}" == k3d-* ]]; then
    printf '%s\n' "${context#k3d-}"
  fi
}

import_k3d_images() {
  local cluster="$1"
  local image_tar archive base
  while IFS='|' read -r logical source_image archive bindings; do
    [[ "${logical}" == "logical" ]] && continue
    [[ -n "${source_image}" ]] || continue
    run k3d image import "${source_image}" -c "${cluster}"
  done < "${BUNDLE_DIR}/metadata/images.lock"
}

push_registry_images() {
  local logical source_image archive bindings target_image repo tag repo_path tag_path binding
  while IFS='|' read -r logical source_image archive bindings; do
    [[ "${logical}" == "logical" ]] && continue
    [[ -n "${source_image}" ]] || continue
    target_image="$(sanitize_registry_target "${source_image}")"
    run docker tag "${source_image}" "${target_image}"
    if [[ "${SKIP_PUSH}" != "true" ]]; then
      run docker push "${target_image}"
    fi

    if [[ -n "${bindings}" ]]; then
      repo="${target_image%:*}"
      tag="${target_image##*:}"
      IFS=';' read -r -a binding_list <<< "${bindings}"
      for binding in "${binding_list[@]}"; do
        [[ -n "${binding}" ]] || continue
        repo_path="${binding%%,*}"
        tag_path="${binding#*,}"
        EXTRA_SET_ARGS+=(--set-string "${repo_path}=${repo}")
        EXTRA_SET_ARGS+=(--set-string "${tag_path}=${tag}")
      done
    fi
  done < "${BUNDLE_DIR}/metadata/images.lock"

  EXTRA_SET_ARGS+=(--set-string "higress-core.redis.global.imageRegistry=${REGISTRY}")
  EXTRA_SET_ARGS+=(--set-string "higress-core.postgresql.global.imageRegistry=${REGISTRY}")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --bundle-dir)
      BUNDLE_DIR="$2"
      shift 2
      ;;
    --release)
      RELEASE_NAME="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      USER_PROVIDED_PROFILE=true
      shift 2
      ;;
    --registry)
      REGISTRY="$2"
      shift 2
      ;;
    --image-pull-secret)
      IMAGE_PULL_SECRET="$2"
      shift 2
      ;;
    --replicas)
      REPLICAS="$2"
      shift 2
      ;;
    --cluster)
      K3D_CLUSTER="$2"
      shift 2
      ;;
    --base-domain)
      INGRESS_BASE_DOMAIN="$2"
      USER_PROVIDED_BASE_DOMAIN=true
      shift 2
      ;;
    --console-host)
      CONSOLE_HOST="$2"
      shift 2
      ;;
    --portal-host)
      PORTAL_HOST="$2"
      shift 2
      ;;
    --skip-import)
      SKIP_IMPORT=true
      shift
      ;;
    --skip-push)
      SKIP_PUSH=true
      shift
      ;;
    --skip-deploy)
      SKIP_DEPLOY=true
      shift
      ;;
    --set)
      EXTRA_SET_ARGS+=(--set "$2")
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
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${TARGET}" ]] || die "--target is required"
[[ -d "${BUNDLE_DIR}" ]] || die "Bundle directory not found: ${BUNDLE_DIR}"
[[ -f "${BUNDLE_DIR}/metadata/images.lock" ]] || die "Missing images.lock in bundle."

if [[ "${USER_PROVIDED_PROFILE}" != "true" && -f "${BUNDLE_DIR}/metadata/release.env" ]]; then
  BUNDLE_PROFILE="$(grep -E '^PROFILE=' "${BUNDLE_DIR}/metadata/release.env" | tail -n 1 | cut -d= -f2- || true)"
  if [[ -n "${BUNDLE_PROFILE}" ]]; then
    PROFILE="${BUNDLE_PROFILE}"
  fi
fi

need_cmd docker
need_cmd helm
need_cmd kubectl

CHART_PACKAGE="$(find_chart_package)"
[[ -n "${CHART_PACKAGE}" ]] || die "No packaged chart found in ${BUNDLE_DIR}/charts"

VALUES_ARGS=(-f "${BUNDLE_DIR}/values/release-base.yaml" -f "${BUNDLE_DIR}/values/release-upstreams.yaml")
if [[ "${PROFILE}" == "ha" && -f "${BUNDLE_DIR}/values/release-ha.yaml" ]]; then
  VALUES_ARGS+=(-f "${BUNDLE_DIR}/values/release-ha.yaml")
fi

apply_replica_sets "${REPLICAS}"
if [[ -n "${IMAGE_PULL_SECRET}" ]]; then
  EXTRA_SET_ARGS+=(--set-string "higress-core.global.imagePullSecrets[0].name=${IMAGE_PULL_SECRET}")
  EXTRA_SET_ARGS+=(--set-string "aigateway-console.imagePullSecrets[0].name=${IMAGE_PULL_SECRET}")
  EXTRA_SET_ARGS+=(--set-string "aigateway-portal.imagePullSecrets[0].name=${IMAGE_PULL_SECRET}")
fi

apply_ingress_host_overrides
if [[ "${USER_PROVIDED_BASE_DOMAIN}" == "true" ]]; then
  save_cluster_domain_config "${INGRESS_BASE_DOMAIN}"
fi

if [[ "${SKIP_IMPORT}" != "true" ]]; then
  import_bundle_images
fi

case "${TARGET}" in
  k3d)
    need_cmd k3d
    if [[ -z "${K3D_CLUSTER}" ]]; then
      K3D_CLUSTER="$(current_k3d_cluster)"
    fi
    [[ -n "${K3D_CLUSTER}" ]] || die "Unable to infer k3d cluster. Pass --cluster <name>."
    if [[ "${SKIP_IMPORT}" != "true" ]]; then
      import_k3d_images "${K3D_CLUSTER}"
    fi
    ;;
  k8s)
    [[ -n "${REGISTRY}" ]] || die "--registry is required for target=k8s"
    push_registry_images
    ;;
  *)
    die "Unsupported target: ${TARGET}"
    ;;
esac

if [[ "${SKIP_DEPLOY}" != "true" ]]; then
  run helm upgrade --install "${RELEASE_NAME}" "${CHART_PACKAGE}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    "${VALUES_ARGS[@]}" \
    "${EXTRA_SET_ARGS[@]}" \
    --wait \
    --timeout "${HELM_TIMEOUT}"
fi

echo "Release deploy finished."
echo "  target    : ${TARGET}"
echo "  bundle    : ${BUNDLE_DIR}"
echo "  release   : ${RELEASE_NAME}"
echo "  namespace : ${NAMESPACE}"
if [[ -n "${CONSOLE_HOST}" || -n "${PORTAL_HOST}" ]]; then
  echo "  console   : ${CONSOLE_HOST:-<values-default>}"
  echo "  portal    : ${PORTAL_HOST:-<values-default>}"
fi
