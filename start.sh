#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${ROOT_DIR}/scripts/dev-shell-lib.sh"

MANIFEST_FILE="${MANIFEST_FILE:-${ROOT_DIR}/helm/image-versions.yaml}"
REDEPLOY_MINIKUBE_SCRIPT="${ROOT_DIR}/higress/helm/redeploy-minikube.sh"
REDEPLOY_K3D_SCRIPT="${ROOT_DIR}/higress/helm/redeploy-k3d.sh"
BUILD_SCRIPT="${ROOT_DIR}/higress/helm/build-local-images.sh"
PORT_FORWARD_SCRIPT="${ROOT_DIR}/scripts/port-forward-all.sh"
RELEASE_BUILD_SCRIPT="${ROOT_DIR}/scripts/release-build.sh"
RELEASE_DEPLOY_SCRIPT="${ROOT_DIR}/scripts/release-deploy.sh"
RELEASE_K3D_CLUSTER_SCRIPT="${ROOT_DIR}/scripts/release-k3d-cluster.sh"
TEST_SCRIPT="${ROOT_DIR}/scripts/test.sh"

resolve_repo_path() {
  local candidate="$1"
  if [[ "${candidate}" = /* ]]; then
    printf '%s\n' "${candidate}"
  else
    printf '%s\n' "${ROOT_DIR}/${candidate}"
  fi
}

manifest_scalar() {
  yaml_get_scalar "${MANIFEST_FILE}" "$1" "${2:-}"
}

manifest_list_csv() {
  local path="$1"
  local fallback="${2:-}"
  local csv
  csv="$(yaml_get_list "${MANIFEST_FILE}" "${path}" | paste -sd, -)"
  if [[ -n "${csv}" ]]; then
    printf '%s\n' "${csv}"
  else
    printf '%s\n' "${fallback}"
  fi
}

DEFAULT_CHART_DIR="$(resolve_repo_path "$(manifest_scalar defaults.chartDir higress/helm/higress)")"
DEFAULT_DEV_CONFIG="$(resolve_repo_path "$(manifest_scalar defaults.devConfigFile helm/dev-mode.yaml)")"
DEFAULT_LOCAL_VALUES_FILE="$(resolve_repo_path "$(manifest_scalar defaults.localValuesFile higress/helm/higress/values-local-minikube.yaml)")"
DEFAULT_NAMESPACE="$(manifest_scalar defaults.namespace aigateway-system)"
DEFAULT_RELEASE_NAME="$(manifest_scalar defaults.releaseName aigateway)"
DEFAULT_BUILD_COMPONENTS="$(manifest_list_csv defaults.buildComponents "aigateway,controller,gateway,pilot,console,portal,plugins,plugin-server")"
DEFAULT_MINIKUBE_PROFILE="$(manifest_scalar minikube.profile minikube)"
DEFAULT_MINIKUBE_DRIVER="$(manifest_scalar minikube.driver docker)"
DEFAULT_MINIKUBE_CPUS="$(manifest_scalar minikube.cpus 4)"
DEFAULT_MINIKUBE_MEMORY="$(manifest_scalar minikube.memory 8192)"
DEFAULT_MINIKUBE_DISK_SIZE="$(manifest_scalar minikube.diskSize 20g)"
DEFAULT_MINIKUBE_INGRESS_BASE_DOMAIN="$(manifest_scalar minikube.ingressBaseDomain ai.local)"
DEFAULT_RELEASE_OUTPUT_DIR="$(resolve_repo_path "$(manifest_scalar release.outputDir out/release)")"
DEFAULT_RELEASE_BUNDLE_NAME="$(manifest_scalar release.bundleName aigateway-release)"
DEFAULT_RELEASE_BASE_VALUES="$(resolve_repo_path "$(manifest_scalar release.baseValuesFile higress/helm/higress/values-release-base.yaml)")"
DEFAULT_RELEASE_HA_VALUES="$(resolve_repo_path "$(manifest_scalar release.haValuesFile higress/helm/higress/values-release-ha.yaml)")"
DEFAULT_RELEASE_UPSTREAMS_VALUES="$(resolve_repo_path "$(manifest_scalar release.upstreamsValuesFile higress/helm/higress/values-release-upstreams.yaml)")"
DEFAULT_RELEASE_PROFILE="$(manifest_scalar release.profile ha)"

CHART_DIR="${CHART_DIR:-${DEFAULT_CHART_DIR}}"
CONFIG_FILE="${CONFIG_FILE:-${DEFAULT_DEV_CONFIG}}"
LOCAL_VALUES_FILE="${LOCAL_VALUES_FILE:-${DEFAULT_LOCAL_VALUES_FILE}}"
NAMESPACE="${NAMESPACE:-${DEFAULT_NAMESPACE}}"
RELEASE_NAME="${RELEASE_NAME:-${DEFAULT_RELEASE_NAME}}"
BUILD_COMPONENTS="${BUILD_COMPONENTS:-${DEFAULT_BUILD_COMPONENTS}}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-${DEFAULT_MINIKUBE_PROFILE}}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-${DEFAULT_MINIKUBE_DRIVER}}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-${DEFAULT_MINIKUBE_CPUS}}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-${DEFAULT_MINIKUBE_MEMORY}}"
MINIKUBE_DISK_SIZE="${MINIKUBE_DISK_SIZE:-${DEFAULT_MINIKUBE_DISK_SIZE}}"
MINIKUBE_INGRESS_BASE_DOMAIN="${MINIKUBE_INGRESS_BASE_DOMAIN:-${DEFAULT_MINIKUBE_INGRESS_BASE_DOMAIN}}"
RELEASE_OUTPUT_DIR="${RELEASE_OUTPUT_DIR:-${DEFAULT_RELEASE_OUTPUT_DIR}}"
RELEASE_BUNDLE_NAME="${RELEASE_BUNDLE_NAME:-${DEFAULT_RELEASE_BUNDLE_NAME}}"
RELEASE_BASE_VALUES="${RELEASE_BASE_VALUES:-${DEFAULT_RELEASE_BASE_VALUES}}"
RELEASE_HA_VALUES="${RELEASE_HA_VALUES:-${DEFAULT_RELEASE_HA_VALUES}}"
RELEASE_UPSTREAMS_VALUES="${RELEASE_UPSTREAMS_VALUES:-${DEFAULT_RELEASE_UPSTREAMS_VALUES}}"
RELEASE_PROFILE="${RELEASE_PROFILE:-${DEFAULT_RELEASE_PROFILE}}"

if [[ -d "${CHART_DIR}" ]]; then
  CHART_DIR="$(cd -- "${CHART_DIR}" && pwd -P)"
fi
if [[ -f "${CONFIG_FILE}" ]]; then
  CONFIG_FILE="$(cd -- "$(dirname -- "${CONFIG_FILE}")" && pwd -P)/$(basename "${CONFIG_FILE}")"
fi
if [[ -f "${LOCAL_VALUES_FILE}" ]]; then
  LOCAL_VALUES_FILE="$(cd -- "$(dirname -- "${LOCAL_VALUES_FILE}")" && pwd -P)/$(basename "${LOCAL_VALUES_FILE}")"
fi
for release_file_var in RELEASE_BASE_VALUES RELEASE_HA_VALUES RELEASE_UPSTREAMS_VALUES; do
  if [[ -f "${!release_file_var}" ]]; then
    printf -v "${release_file_var}" '%s' "$(cd -- "$(dirname -- "${!release_file_var}")" && pwd -P)/$(basename "${!release_file_var}")"
  fi
done

DEFAULT_PROD_VALUES_FILE="${CHART_DIR}/values-production-k3d.yaml"
if [[ ! -f "${DEFAULT_PROD_VALUES_FILE}" ]]; then
  DEFAULT_PROD_VALUES_FILE="${CHART_DIR}/values-production-gray.yaml"
fi
PROD_VALUES_FILE="${PROD_VALUES_FILE:-${DEFAULT_PROD_VALUES_FILE}}"
if [[ -f "${PROD_VALUES_FILE}" ]]; then
  PROD_VALUES_FILE="$(cd -- "$(dirname -- "${PROD_VALUES_FILE}")" && pwd -P)/$(basename "${PROD_VALUES_FILE}")"
fi

PROD_USE_K3D_REDEPLOY="${PROD_USE_K3D_REDEPLOY:-auto}"
PROD_REDEPLOY_SKIP_BUILD="${PROD_REDEPLOY_SKIP_BUILD:-false}"
PROD_REDEPLOY_SKIP_LOAD="${PROD_REDEPLOY_SKIP_LOAD:-false}"
PROD_REDEPLOY_SKIP_DEPLOY="${PROD_REDEPLOY_SKIP_DEPLOY:-false}"
K3D_CLUSTER="${K3D_CLUSTER:-}"

current_context() {
  kubectl config current-context 2>/dev/null || true
}

is_k3d_context() {
  [[ "$(current_context)" == k3d-* ]]
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
      [[ -x "${REDEPLOY_K3D_SCRIPT}" ]] || return 1
      [[ -f "${PROD_VALUES_FILE}" ]] || return 1
      is_k3d_context
      ;;
    *)
      dev_die "Unsupported PROD_USE_K3D_REDEPLOY=${PROD_USE_K3D_REDEPLOY}"
      ;;
  esac
}

default_components_csv() {
  printf '%s\n' "${BUILD_COMPONENTS}"
}

csv_to_lines() {
  local csv="$1"
  printf '%s\n' "${csv}" | tr ',' '\n' | awk 'NF'
}

manifest_image_repo() {
  manifest_scalar "images.$1.repository"
}

manifest_image_tag() {
  manifest_scalar "images.$1.tag"
}

component_has_manifest_image() {
  local component="$1"
  [[ -n "$(manifest_image_repo "${component}")" && -n "$(manifest_image_tag "${component}")" ]]
}

binding_specs_for_component() {
  case "$1" in
    aigateway)
      cat <<'EOF'
higress/helm/higress/values-production-gray.yaml|aigateway-console.certmanager.image.repository|aigateway-console.certmanager.image.tag
higress/helm/higress/values-production-k3d.yaml|aigateway-console.certmanager.image.repository|aigateway-console.certmanager.image.tag
aigateway-console/helm/values-production-gray.yaml|certmanager.image.repository|certmanager.image.tag
EOF
      ;;
    controller)
      cat <<'EOF'
helm/dev-mode.yaml|higress-core.controller.repository|higress-core.controller.tag
higress/helm/higress/values-local-minikube.yaml|higress-core.controller.repository|higress-core.controller.tag
higress/helm/higress/values-production-k3d.yaml|higress-core.controller.repository|higress-core.controller.tag
higress/helm/higress/values-production-gray.yaml|higress-core.controller.repository|higress-core.controller.tag
higress/helm/core/values-production-gray.yaml|controller.repository|controller.tag
EOF
      ;;
    gateway)
      cat <<'EOF'
helm/dev-mode.yaml|higress-core.gateway.repository|higress-core.gateway.tag
higress/helm/higress/values-local-minikube.yaml|higress-core.gateway.repository|higress-core.gateway.tag
higress/helm/higress/values-production-k3d.yaml|higress-core.gateway.repository|higress-core.gateway.tag
higress/helm/higress/values-production-gray.yaml|higress-core.gateway.repository|higress-core.gateway.tag
higress/helm/core/values-production-gray.yaml|gateway.repository|gateway.tag
EOF
      ;;
    pilot)
      cat <<'EOF'
helm/dev-mode.yaml|higress-core.pilot.repository|higress-core.pilot.tag
higress/helm/higress/values-local-minikube.yaml|higress-core.pilot.repository|higress-core.pilot.tag
higress/helm/higress/values-production-k3d.yaml|higress-core.pilot.repository|higress-core.pilot.tag
higress/helm/higress/values-production-gray.yaml|higress-core.pilot.repository|higress-core.pilot.tag
higress/helm/core/values-production-gray.yaml|pilot.repository|pilot.tag
EOF
      ;;
    plugin-server)
      cat <<'EOF'
helm/dev-mode.yaml|higress-core.pluginServer.repository|higress-core.pluginServer.tag
higress/helm/higress/values-local-minikube.yaml|higress-core.pluginServer.repository|higress-core.pluginServer.tag
higress/helm/higress/values-production-k3d.yaml|higress-core.pluginServer.repository|higress-core.pluginServer.tag
higress/helm/higress/values-production-gray.yaml|higress-core.pluginServer.repository|higress-core.pluginServer.tag
higress/helm/core/values-production-gray.yaml|pluginServer.repository|pluginServer.tag
EOF
      ;;
    console)
      cat <<'EOF'
helm/dev-mode.yaml|aigateway-console.image.repository|aigateway-console.image.tag
higress/helm/higress/values-local-minikube.yaml|aigateway-console.image.repository|aigateway-console.image.tag
higress/helm/higress/values-production-k3d.yaml|aigateway-console.image.repository|aigateway-console.image.tag
higress/helm/higress/values-production-gray.yaml|aigateway-console.image.repository|aigateway-console.image.tag
aigateway-console/helm/values-production-gray.yaml|image.repository|image.tag
EOF
      ;;
    portal)
      cat <<'EOF'
helm/dev-mode.yaml|aigateway-portal.image.repository|aigateway-portal.image.tag
higress/helm/higress/values-local-minikube.yaml|aigateway-portal.image.repository|aigateway-portal.image.tag
higress/helm/higress/values-production-k3d.yaml|aigateway-portal.image.repository|aigateway-portal.image.tag
higress/helm/higress/values-production-gray.yaml|aigateway-portal.image.repository|aigateway-portal.image.tag
aigateway-portal/helm/values.yaml|image.repository|image.tag
aigateway-portal/helm/values.yaml|backend.image.repository|backend.image.tag
EOF
      ;;
    *)
      ;;
  esac
}

refresh_manifest_tags() {
  local components_csv="$1"
  local fresh_tags="$2"
  local stamp="${3:-}"
  local auto_refresh_apps="$4"
  local component current_tag next_tag

  if [[ -z "${stamp}" ]]; then
    stamp="$(default_dev_stamp)"
  fi

  while IFS= read -r component; do
    [[ -z "${component}" ]] && continue

    if [[ "${fresh_tags}" != "true" ]]; then
      if [[ "${auto_refresh_apps}" != "true" ]]; then
        continue
      fi
      if [[ "${component}" != "console" && "${component}" != "portal" ]]; then
        continue
      fi
    fi

    current_tag="$(manifest_image_tag "${component}")"
    [[ -n "$(manifest_image_repo "${component}")" ]] || continue
    [[ -n "${current_tag}" ]] || continue
    next_tag="$(stamp_dev_tag "${current_tag}" "${stamp}")"
    if [[ "${next_tag}" != "${current_tag}" ]]; then
      yaml_set_scalar "${MANIFEST_FILE}" "images.${component}.tag" "${next_tag}"
      echo "[sync] refreshed manifest tag: ${component} ${current_tag} -> ${next_tag}"
    fi
  done < <(csv_to_lines "${components_csv}")
}

sync_manifest_to_values() {
  local components_csv="$1"
  local check_only="$2"
  local drift=0
  local changed=0
  local component repo tag spec rel_path repo_path tag_path file current_repo current_tag

  while IFS= read -r component; do
    [[ -z "${component}" ]] && continue
    if ! component_has_manifest_image "${component}"; then
      continue
    fi
    repo="$(manifest_image_repo "${component}")"
    tag="$(manifest_image_tag "${component}")"
    [[ -n "${repo}" && -n "${tag}" ]] || dev_die "Manifest image missing repository/tag for component: ${component}"

    while IFS= read -r spec; do
      [[ -z "${spec}" ]] && continue
      IFS='|' read -r rel_path repo_path tag_path <<< "${spec}"
      file="${ROOT_DIR}/${rel_path}"
      [[ -f "${file}" ]] || dev_die "Sync target not found: ${file}"

      current_repo="$(yaml_get_scalar "${file}" "${repo_path}")"
      current_tag="$(yaml_get_scalar "${file}" "${tag_path}")"

      if [[ "${current_repo}" != "${repo}" || "${current_tag}" != "${tag}" ]]; then
        if [[ "${check_only}" == "true" ]]; then
          echo "[drift] ${rel_path}: ${repo_path}=${current_repo:-<empty>} ${tag_path}=${current_tag:-<empty>} expected ${repo}:${tag}"
          drift=1
        else
          yaml_set_scalar "${file}" "${repo_path}" "${repo}"
          yaml_set_scalar "${file}" "${tag_path}" "${tag}"
          echo "[sync] ${rel_path}: ${repo}:${tag}"
          changed=1
        fi
      fi
    done < <(binding_specs_for_component "${component}")
  done < <(csv_to_lines "${components_csv}")

  if [[ "${check_only}" == "true" ]]; then
    return "${drift}"
  fi

  return 0
}

helm_up() {
  local values_file="$1"
  shift

  [[ -d "${CHART_DIR}" ]] || dev_die "Chart directory not found: ${CHART_DIR}"
  [[ -f "${values_file}" ]] || dev_die "Values file not found: ${values_file}"

  dev_stage deploy "helm dependency build + helm upgrade --install"
  helm dependency build "${CHART_DIR}"
  helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    -f "${values_file}" \
    "$@"
}

run_port_forward() {
  dev_stage port-forward "Starting local service port-forward."
  "${PORT_FORWARD_SCRIPT}" \
    --config "${CONFIG_FILE}" \
    --namespace "${NAMESPACE}" \
    --release "${RELEASE_NAME}"
}

run_build() {
  local components_csv="$1"
  dev_stage build "Building local images for components: ${components_csv}"
  "${BUILD_SCRIPT}" --components "${components_csv}"
}

run_minikube_start() {
  local profile="$1"
  local addon

  dev_stage cluster-start "Starting minikube profile ${profile}."
  dev_need_cmd minikube
  minikube start \
    -p "${profile}" \
    --driver="${MINIKUBE_DRIVER}" \
    --cpus="${MINIKUBE_CPUS}" \
    --memory="${MINIKUBE_MEMORY}" \
    --disk-size="${MINIKUBE_DISK_SIZE}"

  while IFS= read -r addon; do
    [[ -z "${addon}" ]] && continue
    echo "[cluster-start] enabling addon: ${addon}"
    minikube -p "${profile}" addons enable "${addon}"
  done < <(yaml_get_list "${MANIFEST_FILE}" "minikube.addons")
}

minikube_current_ip() {
  dev_need_cmd minikube
  minikube -p "${MINIKUBE_PROFILE}" ip
}

create_minikube_ingress_override() {
  local base_domain="$1"
  local override_file
  local console_host="console.${base_domain}"
  local portal_host="portal.${base_domain}"

  override_file="$(mktemp "${ROOT_DIR}/.tmp-minikube-ingress.XXXXXX.yaml")"
  cat > "${override_file}" <<EOF
aigateway-console:
  ingress:
    enabled: true
    domain: ${console_host}
    paths:
      - path: /
        pathType: Prefix

aigateway-portal:
  ingress:
    enabled: true
    className: aigateway
    host: ${portal_host}
    path: /
    pathType: Prefix
EOF
  printf '%s\n' "${override_file}"
}

list_minikube_gateway_domains() {
  if ! command -v kubectl >/dev/null 2>&1; then
    return 0
  fi

  kubectl get configmap \
    --namespace "${NAMESPACE}" \
    -l "higress.io/config-map-type=domain,higress.io/resource-definer=higress" \
    -o jsonpath='{range .items[*]}{.data.domain}{"\t"}{.data.enableHttps}{"\n"}{end}' 2>/dev/null \
    | awk -F '\t' '
      {
        domain = $1
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", domain)
        if (domain != "") {
          print domain "\t" $2
        }
      }
    ' \
    | sort -u
}

sync_minikube_ingress_hosts() {
  local minikube_ip="$1"
  local base_domain="$2"
  local console_host="console.${base_domain}"
  local portal_host="portal.${base_domain}"
  local marker_begin="# >>> aigateway minikube ingress >>>"
  local marker_end="# <<< aigateway minikube ingress <<<"
  local managed_block
  local tmp_hosts
  local gateway_hosts=()
  local domain
  local gateway_count

  while IFS=$'\t' read -r domain _; do
    [[ -z "${domain}" || "${domain}" == \** ]] && continue
    gateway_hosts+=("${domain}")
  done < <(list_minikube_gateway_domains)

  managed_block="${marker_begin}"$'\n'"${minikube_ip} ${console_host} ${portal_host}"
  if ((${#gateway_hosts[@]} > 0)); then
    managed_block+=$'\n'"${minikube_ip} ${gateway_hosts[*]}"
  fi
  managed_block+=$'\n'"${marker_end}"
  gateway_count="${#gateway_hosts[@]}"

  if [[ -w /etc/hosts ]]; then
    tmp_hosts="$(mktemp)"
    awk -v begin="${marker_begin}" -v end="${marker_end}" '
      $0 == begin { skip = 1; next }
      $0 == end { skip = 0; next }
      !skip { print }
    ' /etc/hosts > "${tmp_hosts}"
    printf '\n%s\n' "${managed_block}" >> "${tmp_hosts}"
    cat "${tmp_hosts}" > /etc/hosts
    rm -f "${tmp_hosts}"
    if ((gateway_count > 0)); then
      echo "[ingress] Updated /etc/hosts for ${console_host}, ${portal_host}, and ${gateway_count} gateway domain(s)"
    else
      echo "[ingress] Updated /etc/hosts for ${console_host} and ${portal_host}"
    fi
    return 0
  fi

  echo "[WARN] /etc/hosts is not writable. Add this entry manually:"
  printf '       %s\n' "${minikube_ip} ${console_host} ${portal_host}"
  if ((${#gateway_hosts[@]} > 0)); then
    printf '       %s\n' "${minikube_ip} ${gateway_hosts[*]}"
  fi
}

show_minikube_ingress_access() {
  local minikube_ip="$1"
  local base_domain="$2"
  local console_host="console.${base_domain}"
  local portal_host="portal.${base_domain}"
  local domain
  local enable_https
  local scheme

  echo "[ingress] Console: http://${console_host}"
  echo "[ingress] Portal : http://${portal_host}"
  while IFS=$'\t' read -r domain enable_https; do
    [[ -z "${domain}" ]] && continue
    scheme="http"
    if [[ -n "${enable_https}" && "${enable_https}" != "off" ]]; then
      scheme="https"
    fi
    echo "[ingress] Gateway: ${scheme}://${domain}"
  done < <(list_minikube_gateway_domains)
  echo "[ingress] Gateway IP: http://${minikube_ip}"
  echo "[port-forward] Console: http://127.0.0.1:8080"
  echo "[port-forward] Portal : http://127.0.0.1:8081"
}

run_minikube_dev() {
  local components_csv="$1"
  local skip_start="$2"
  local minikube_ip
  local ingress_override
  local args

  dev_stage deploy "Redeploying dev profile via minikube shell flow."
  minikube_ip="$(minikube_current_ip)"
  ingress_override="$(create_minikube_ingress_override "${MINIKUBE_INGRESS_BASE_DOMAIN}")"
  args=(
    --values "${LOCAL_VALUES_FILE}"
    --extra-values "${CONFIG_FILE}"
    --extra-values "${ingress_override}"
    --namespace "${NAMESPACE}"
    --release "${RELEASE_NAME}"
    --components "${components_csv}"
  )
  if [[ -n "${MINIKUBE_PROFILE}" ]]; then
    args+=(--profile "${MINIKUBE_PROFILE}")
  fi
  "${REDEPLOY_MINIKUBE_SCRIPT}" "${args[@]}"
  rm -f "${ingress_override}"

  sync_minikube_ingress_hosts "${minikube_ip}" "${MINIKUBE_INGRESS_BASE_DOMAIN}"
  show_minikube_ingress_access "${minikube_ip}" "${MINIKUBE_INGRESS_BASE_DOMAIN}"
  run_port_forward
}

run_minikube_tunnel_flow() {
  local components_csv="$1"
  local skip_start="$2"
  local start_tunnel="$3"

  dev_stage deploy "Redeploying local LoadBalancer profile for minikube."
  args=(
    --values "${LOCAL_VALUES_FILE}"
    --namespace "${NAMESPACE}"
    --release "${RELEASE_NAME}"
    --components "${components_csv}"
  )
  if [[ -n "${MINIKUBE_PROFILE}" ]]; then
    args+=(--profile "${MINIKUBE_PROFILE}")
  fi
  "${REDEPLOY_MINIKUBE_SCRIPT}" "${args[@]}"

  if [[ "${start_tunnel}" == "true" ]]; then
    dev_stage port-forward "Starting minikube tunnel."
    minikube -p "${MINIKUBE_PROFILE}" tunnel
  else
    echo "[INFO] Local LoadBalancer profile is ready. Run: minikube -p ${MINIKUBE_PROFILE} tunnel"
  fi
}

run_prod_redeploy() {
  local values_file="$1"
  local args=(--values "${values_file}" --namespace "${NAMESPACE}" --release "${RELEASE_NAME}" --components "${BUILD_COMPONENTS}")
  [[ -n "${K3D_CLUSTER}" ]] && args+=(--cluster "${K3D_CLUSTER}")
  [[ "${PROD_REDEPLOY_SKIP_BUILD}" == "true" ]] && args+=(--skip-build)
  [[ "${PROD_REDEPLOY_SKIP_LOAD}" == "true" ]] && args+=(--skip-load)
  [[ "${PROD_REDEPLOY_SKIP_DEPLOY}" == "true" ]] && args+=(--skip-deploy)
  "${REDEPLOY_K3D_SCRIPT}" "${args[@]}"
}

show_port_forward_config() {
  local service pair key value

  echo "Port Forward"
  echo "  config      : ${CONFIG_FILE}"
  echo "  namespace   : $(yaml_get_scalar "${CONFIG_FILE}" "dev.namespace" "${NAMESPACE}")"
  echo "  release     : $(yaml_get_scalar "${CONFIG_FILE}" "dev.releaseName" "${RELEASE_NAME}")"
  echo "  bindAddress : $(yaml_get_scalar "${CONFIG_FILE}" "dev.portForward.bindAddress" "127.0.0.1")"
  echo "  localStart  : $(yaml_get_scalar "${CONFIG_FILE}" "dev.portForward.localPortStart" "20000")"
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    while IFS= read -r pair; do
      [[ -z "${pair}" ]] && continue
      key="${pair%%=*}"
      value="${pair#*=}"
      echo "  ${service}  : ${value} -> ${key}"
    done < <(yaml_get_map_pairs "${CONFIG_FILE}" "dev.portForward.servicePorts.${service}")
  done < <(yaml_get_list "${CONFIG_FILE}" "dev.portForward.includeServices")
}

show_release_config() {
  echo "Release"
  echo "  outputDir    : ${RELEASE_OUTPUT_DIR}"
  echo "  bundleName   : ${RELEASE_BUNDLE_NAME}"
  echo "  profile      : ${RELEASE_PROFILE}"
  echo "  baseValues   : ${RELEASE_BASE_VALUES}"
  echo "  haValues     : ${RELEASE_HA_VALUES}"
  echo "  upstreams    : ${RELEASE_UPSTREAMS_VALUES}"
}

cmd_show() {
  local component

  echo "Manifest"
  echo "  file         : ${MANIFEST_FILE}"
  echo "  chartDir     : ${CHART_DIR}"
  echo "  devConfig    : ${CONFIG_FILE}"
  echo "  localValues  : ${LOCAL_VALUES_FILE}"
  echo "  namespace    : ${NAMESPACE}"
  echo "  releaseName  : ${RELEASE_NAME}"
  echo "  components   : ${BUILD_COMPONENTS}"
  echo "Minikube"
  echo "  profile      : ${MINIKUBE_PROFILE}"
  echo "  driver       : ${MINIKUBE_DRIVER}"
  echo "  cpus         : ${MINIKUBE_CPUS}"
  echo "  memory       : ${MINIKUBE_MEMORY}"
  echo "  diskSize     : ${MINIKUBE_DISK_SIZE}"
  show_release_config
  echo "Images"
  while IFS= read -r component; do
    [[ -z "${component}" ]] && continue
    if component_has_manifest_image "${component}"; then
      echo "  ${component}: $(manifest_image_repo "${component}"):$(manifest_image_tag "${component}")"
    else
      echo "  ${component}: local-only artifacts"
    fi
  done < <(csv_to_lines "${BUILD_COMPONENTS}")
  show_port_forward_config
}

cmd_release_build() {
  dev_stage check "Verifying release bundle build dependencies."
  dev_need_cmd docker
  dev_need_cmd helm
  "${RELEASE_BUILD_SCRIPT}" \
    --bundle-name "${RELEASE_BUNDLE_NAME}" \
    --output-dir "${RELEASE_OUTPUT_DIR}" \
    --profile "${RELEASE_PROFILE}" \
    --chart-dir "${CHART_DIR}" \
    --namespace "${NAMESPACE}" \
    --release "${RELEASE_NAME}" \
    --base-values "${RELEASE_BASE_VALUES}" \
    --ha-values "${RELEASE_HA_VALUES}" \
    --upstreams-values "${RELEASE_UPSTREAMS_VALUES}" \
    --components "${BUILD_COMPONENTS}" \
    "$@"
}

cmd_release_deploy() {
  dev_stage check "Verifying release deploy dependencies."
  dev_need_cmd docker
  dev_need_cmd helm
  "${RELEASE_DEPLOY_SCRIPT}" \
    --bundle-dir "${RELEASE_OUTPUT_DIR}/${RELEASE_BUNDLE_NAME}" \
    --release "${RELEASE_NAME}" \
    --namespace "${NAMESPACE}" \
    --profile "${RELEASE_PROFILE}" \
    "$@"
}

cmd_release_k3d_cluster() {
  dev_stage check "Verifying release k3d cluster dependencies."
  dev_need_cmd kubectl
  "${RELEASE_K3D_CLUSTER_SCRIPT}" \
    --namespace "${NAMESPACE}" \
    "$@"
}

cmd_test() {
  "${TEST_SCRIPT}" "$@"
}

cmd_sync() {
  local check_only=false
  local components_csv="${BUILD_COMPONENTS}"
  local fresh_tags=false
  local stamp=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)
        check_only=true
        shift
        ;;
      --components)
        components_csv="$2"
        shift 2
        ;;
      --fresh-tags)
        fresh_tags=true
        shift
        ;;
      --stamp)
        stamp="$2"
        shift 2
        ;;
      *)
        dev_die "Unknown sync argument: $1"
        ;;
    esac
  done

  dev_stage check "Verifying manifest-driven Helm sync."
  if [[ "${fresh_tags}" == "true" ]]; then
    refresh_manifest_tags "${components_csv}" true "${stamp}" false
  fi

  dev_stage sync "Synchronizing image versions into Helm values."
  if sync_manifest_to_values "${components_csv}" "${check_only}"; then
    if [[ "${check_only}" == "true" ]]; then
      echo "[sync] no drift detected."
    fi
    return 0
  fi

  if [[ "${check_only}" == "true" ]]; then
    echo "[sync] drift detected."
    return 1
  fi
}

cmd_build() {
  local components_csv="${BUILD_COMPONENTS}"
  local skip_sync=false
  local fresh_tags=false
  local stamp=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --components)
        components_csv="$2"
        shift 2
        ;;
      --skip-sync)
        skip_sync=true
        shift
        ;;
      --fresh-tags)
        fresh_tags=true
        shift
        ;;
      --stamp)
        stamp="$2"
        shift 2
        ;;
      *)
        dev_die "Unknown build argument: $1"
        ;;
    esac
  done

  dev_stage check "Verifying build dependencies."
  dev_need_cmd docker

  refresh_manifest_tags "${components_csv}" "${fresh_tags}" "${stamp}" true

  if [[ "${skip_sync}" != "true" ]]; then
    cmd_sync --components "${components_csv}"
  fi

  run_build "${components_csv}"
}

cmd_minikube_start() {
  local profile="${MINIKUBE_PROFILE}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        profile="$2"
        shift 2
        ;;
      *)
        dev_die "Unknown minikube-start argument: $1"
        ;;
    esac
  done

  dev_stage check "Verifying minikube startup dependencies."
  dev_need_cmd kubectl
  dev_need_cmd minikube
  MINIKUBE_PROFILE="${profile}"
  run_minikube_start "${profile}"
}

cmd_minikube_dev() {
  local components_csv="${BUILD_COMPONENTS}"
  local skip_sync=false
  local skip_start=false
  local fresh_tags=false
  local stamp=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --components)
        components_csv="$2"
        shift 2
        ;;
      --skip-sync)
        skip_sync=true
        shift
        ;;
      --skip-start)
        skip_start=true
        shift
        ;;
      --fresh-tags)
        fresh_tags=true
        shift
        ;;
      --stamp)
        stamp="$2"
        shift 2
        ;;
      --profile)
        MINIKUBE_PROFILE="$2"
        shift 2
        ;;
      *)
        dev_die "Unknown minikube-dev argument: $1"
        ;;
    esac
  done

  dev_stage check "Verifying minikube dev dependencies."
  dev_need_cmd helm
  dev_need_cmd kubectl
  dev_need_cmd docker
  dev_need_cmd minikube
  dev_need_cmd jq

  refresh_manifest_tags "${components_csv}" "${fresh_tags}" "${stamp}" true

  if [[ "${skip_sync}" != "true" ]]; then
    cmd_sync --components "${components_csv}"
  fi

  if [[ "${skip_start}" != "true" ]]; then
    run_minikube_start "${MINIKUBE_PROFILE}"
  fi

  run_minikube_dev "${components_csv}" "${skip_start}"
}

cmd_minikube_tunnel() {
  local components_csv="${BUILD_COMPONENTS}"
  local skip_sync=false
  local skip_start=false
  local fresh_tags=false
  local stamp=""
  local start_tunnel=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --components)
        components_csv="$2"
        shift 2
        ;;
      --skip-sync)
        skip_sync=true
        shift
        ;;
      --skip-start)
        skip_start=true
        shift
        ;;
      --start-tunnel)
        start_tunnel=true
        shift
        ;;
      --fresh-tags)
        fresh_tags=true
        shift
        ;;
      --stamp)
        stamp="$2"
        shift 2
        ;;
      --profile)
        MINIKUBE_PROFILE="$2"
        shift 2
        ;;
      *)
        dev_die "Unknown minikube-tunnel argument: $1"
        ;;
    esac
  done

  dev_stage check "Verifying minikube tunnel dependencies."
  dev_need_cmd helm
  dev_need_cmd kubectl
  dev_need_cmd docker
  dev_need_cmd minikube

  refresh_manifest_tags "${components_csv}" "${fresh_tags}" "${stamp}" true

  if [[ "${skip_sync}" != "true" ]]; then
    cmd_sync --components "${components_csv}"
  fi

  if [[ "${skip_start}" != "true" ]]; then
    run_minikube_start "${MINIKUBE_PROFILE}"
  fi

  run_minikube_tunnel_flow "${components_csv}" "${skip_start}" "${start_tunnel}"
}

print_help() {
  cat <<EOF
Usage:
  ./start.sh show
  ./start.sh sync [--check] [--components a,b] [--fresh-tags] [--stamp YYYYMMDDHHMMSS]
  ./start.sh build [--components a,b] [--skip-sync] [--fresh-tags] [--stamp YYYYMMDDHHMMSS]
  ./start.sh test --stage unit|integration|e2e|acceptance|release|all
  ./start.sh release-build [release-build args...]
  ./start.sh release-deploy [release-deploy args...]
  ./start.sh release-k3d-cluster --cluster name --base-domain example.com
  ./start.sh minikube-start [--profile name]
  ./start.sh minikube-dev [--components a,b] [--skip-sync] [--skip-start] [--fresh-tags] [--stamp YYYYMMDDHHMMSS]
  ./start.sh minikube-tunnel [--components a,b] [--skip-sync] [--skip-start] [--start-tunnel] [--fresh-tags] [--stamp YYYYMMDDHHMMSS]

Compatibility commands:
  ./start.sh dev [extra-helm-args...]
  ./start.sh dev-redeploy
  ./start.sh deploy [values-file] [extra-helm-args...]
  ./start.sh deploy-prod [values-file] [extra-helm-args...]
  ./start.sh prod-redeploy [values-file]
  ./start.sh port-forward
  ./start.sh status
  ./start.sh down

Notes:
  - Preferred local dev entrypoint: ./start.sh
  - helm/image-versions.yaml is the single source of truth for local image tags and defaults.
  - console and portal refresh dev tags automatically for build/minikube flows.
  - Release entrypoints are pure shell: ./start.sh release-build / ./start.sh release-deploy
  - New k3d release clusters can be initialized with ./start.sh release-k3d-cluster --base-domain <domain>
  - Repo-level quality gate entrypoint: ./start.sh test --stage <stage>
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true

  case "${cmd}" in
    show)
      cmd_show "$@"
      ;;
    sync)
      cmd_sync "$@"
      ;;
    build)
      cmd_build "$@"
      ;;
    test)
      cmd_test "$@"
      ;;
    release-build)
      cmd_release_build "$@"
      ;;
    release-deploy)
      cmd_release_deploy "$@"
      ;;
    release-k3d-cluster)
      cmd_release_k3d_cluster "$@"
      ;;
    minikube-start)
      cmd_minikube_start "$@"
      ;;
    minikube-dev)
      cmd_minikube_dev "$@"
      ;;
    minikube-tunnel)
      cmd_minikube_tunnel "$@"
      ;;
    dev)
      if [[ $# -eq 0 ]]; then
        cmd_minikube_dev
      else
        helm_up "${CONFIG_FILE}" "$@"
        run_port_forward
      fi
      ;;
    dev-redeploy)
      [[ $# -eq 0 ]] || dev_die "dev-redeploy does not accept extra arguments."
      cmd_minikube_dev --skip-start
      ;;
    deploy)
      local values_file="${1:-${CONFIG_FILE}}"
      if [[ $# -gt 0 ]]; then
        shift
      fi
      helm_up "${values_file}" "$@"
      ;;
    deploy-prod)
      local values_file="${1:-${PROD_VALUES_FILE}}"
      if [[ $# -gt 0 ]]; then
        shift
      fi
      if [[ $# -eq 0 ]] && should_use_k3d_redeploy; then
        run_prod_redeploy "${values_file}"
      else
        helm_up "${values_file}" "$@"
      fi
      ;;
    prod-redeploy)
      local values_file="${1:-${PROD_VALUES_FILE}}"
      if [[ $# -gt 0 ]]; then
        shift
      fi
      [[ $# -eq 0 ]] || dev_die "prod-redeploy only accepts an optional values file."
      run_prod_redeploy "${values_file}"
      ;;
    port-forward)
      run_port_forward
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
      dev_die "Unsupported command: ${cmd}"
      ;;
  esac
}

main "$@"
