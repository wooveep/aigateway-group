#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
source "${ROOT_DIR}/scripts/dev-shell-lib.sh"

MANIFEST_FILE="${MANIFEST_FILE:-${ROOT_DIR}/helm/image-versions.yaml}"
BUILD_SCRIPT="${ROOT_DIR}/higress/helm/build-local-images.sh"
DEPLOY_SCRIPT="${ROOT_DIR}/scripts/release-deploy.sh"

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

CHART_DIR="${CHART_DIR:-$(resolve_repo_path "$(manifest_scalar defaults.chartDir higress/helm/higress)")}"
NAMESPACE="${NAMESPACE:-$(manifest_scalar defaults.namespace aigateway-system)}"
RELEASE_NAME="${RELEASE_NAME:-$(manifest_scalar defaults.releaseName aigateway)}"
COMPONENTS="${COMPONENTS:-$(manifest_list_csv defaults.buildComponents "aigateway,controller,gateway,pilot,console,portal,plugins,plugin-server")}"
OUTPUT_DIR="${OUTPUT_DIR:-$(resolve_repo_path "$(manifest_scalar release.outputDir out/release)")}"
BUNDLE_NAME="${BUNDLE_NAME:-$(manifest_scalar release.bundleName aigateway-release)}"
PROFILE="${PROFILE:-$(manifest_scalar release.profile ha)}"
BASE_VALUES_FILE="${BASE_VALUES_FILE:-$(resolve_repo_path "$(manifest_scalar release.baseValuesFile higress/helm/higress/values-release-base.yaml)")}"
HA_VALUES_FILE="${HA_VALUES_FILE:-$(resolve_repo_path "$(manifest_scalar release.haValuesFile higress/helm/higress/values-release-ha.yaml)")}"
UPSTREAMS_VALUES_FILE="${UPSTREAMS_VALUES_FILE:-$(resolve_repo_path "$(manifest_scalar release.upstreamsValuesFile higress/helm/higress/values-release-upstreams.yaml)")}"

DRY_RUN=false
SKIP_BUILD=false
EXTRA_HELM_SET_ARGS=()

usage() {
  cat <<'EOF'
Usage:
  release-build.sh [options]

Options:
  --bundle-name <name>       Bundle directory name under output-dir.
  --output-dir <path>        Release output root.
  --profile standard|ha      Bundle profile. Default: manifest release.profile
  --chart-dir <path>         Parent chart directory.
  --namespace <name>         Helm namespace used for templating.
  --release <name>           Helm release name used for templating/package metadata.
  --base-values <path>       Base release values file.
  --ha-values <path>         HA release values file.
  --upstreams-values <path>  Upstream load-balance values file.
  --components <csv>         Components passed to build-local-images.sh.
  --skip-build               Skip local image build step.
  --set key=value            Extra Helm set argument applied during template/render.
  --dry-run                  Print actions without writing bundle content.
  -h, --help                 Show help.
EOF
}

run() {
  echo "+ $*"
  if [[ "${DRY_RUN}" != "true" ]]; then
    "$@"
  fi
}

run_capture() {
  echo "+ $*"
  if [[ "${DRY_RUN}" != "true" ]]; then
    "$@"
  fi
}

sanitize_image_archive_name() {
  local image="$1"
  local sanitized
  sanitized="$(printf '%s' "${image}" | tr '/:@' '---' | tr -c 'A-Za-z0-9._-' '-')"
  printf '%s.tar\n' "${sanitized}"
}

ensure_local_image() {
  local image="$1"
  if docker image inspect "${image}" >/dev/null 2>&1; then
    return 0
  fi
  run docker pull "${image}"
}

append_known_binding() {
  local logical="$1"
  local repo_path="$2"
  local tag_path="$3"
  local repo
  local tag
  repo="$(yaml_get_scalar_from_files "${repo_path}" "${VALUES_FILES[@]}")"
  tag="$(yaml_get_scalar_from_files "${tag_path}" "${VALUES_FILES[@]}")"
  if [[ -n "${repo}" && -n "${tag}" ]]; then
    printf '%s|%s|%s|%s,%s\n' "${logical}" "${repo}:${tag}" "$(sanitize_image_archive_name "${repo}:${tag}")" "${repo_path}" "${tag_path}"
  fi
}

build_images_lock() {
  {
    append_known_binding "gateway" "higress-core.gateway.repository" "higress-core.gateway.tag"
    append_known_binding "controller" "higress-core.controller.repository" "higress-core.controller.tag"
    append_known_binding "pilot" "higress-core.pilot.repository" "higress-core.pilot.tag"
    append_known_binding "plugin-server" "higress-core.pluginServer.repository" "higress-core.pluginServer.tag"
    append_known_binding "console" "aigateway-console.image.repository" "aigateway-console.image.tag"
    append_known_binding "console-certmanager" "aigateway-console.certmanager.image.repository" "aigateway-console.certmanager.image.tag"
    append_known_binding "portal" "aigateway-portal.image.repository" "aigateway-portal.image.tag"
    append_known_binding "grafana" "global.o11y.grafana.image.repository" "global.o11y.grafana.image.tag"
    append_known_binding "prometheus" "global.o11y.prometheus.image.repository" "global.o11y.prometheus.image.tag"
    append_known_binding "loki" "global.o11y.loki.image.repository" "global.o11y.loki.image.tag"
    append_known_binding "promtail" "global.o11y.promtail.image.repository" "global.o11y.promtail.image.tag"
  } | awk -F'|' '!seen[$2]++'
}

extract_rendered_images() {
  helm dependency build "${CHART_DIR}" >/dev/null
  helm template "${RELEASE_NAME}" "${CHART_DIR}" \
    --namespace "${NAMESPACE}" \
    "${HELM_VALUES_ARGS[@]}" \
    "${EXTRA_HELM_SET_ARGS[@]}" |
    awk '
      $1 == "image:" {
        image = $2
        gsub(/"/, "", image)
        print image
      }
    ' | awk 'NF { seen[$0] = 1 } END { for (image in seen) print image }' | sort
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-name)
      BUNDLE_NAME="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$(resolve_repo_path "$2")"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --chart-dir)
      CHART_DIR="$(resolve_repo_path "$2")"
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
    --base-values)
      BASE_VALUES_FILE="$(resolve_repo_path "$2")"
      shift 2
      ;;
    --ha-values)
      HA_VALUES_FILE="$(resolve_repo_path "$2")"
      shift 2
      ;;
    --upstreams-values)
      UPSTREAMS_VALUES_FILE="$(resolve_repo_path "$2")"
      shift 2
      ;;
    --components)
      COMPONENTS="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --set)
      EXTRA_HELM_SET_ARGS+=(--set "$2")
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

dev_need_cmd docker
dev_need_cmd helm
dev_need_cmd sha256sum

[[ -d "${CHART_DIR}" ]] || dev_die "Chart directory not found: ${CHART_DIR}"
[[ -f "${BASE_VALUES_FILE}" ]] || dev_die "Base values file not found: ${BASE_VALUES_FILE}"
[[ -f "${UPSTREAMS_VALUES_FILE}" ]] || dev_die "Upstreams values file not found: ${UPSTREAMS_VALUES_FILE}"
if [[ "${PROFILE}" == "ha" ]]; then
  [[ -f "${HA_VALUES_FILE}" ]] || dev_die "HA values file not found: ${HA_VALUES_FILE}"
fi

BUNDLE_DIR="${OUTPUT_DIR}/${BUNDLE_NAME}"
CHART_OUTPUT_DIR="${BUNDLE_DIR}/charts"
IMAGE_OUTPUT_DIR="${BUNDLE_DIR}/images"
VALUES_OUTPUT_DIR="${BUNDLE_DIR}/values"
META_OUTPUT_DIR="${BUNDLE_DIR}/metadata"

VALUES_FILES=("${BASE_VALUES_FILE}" "${UPSTREAMS_VALUES_FILE}")
if [[ "${PROFILE}" == "ha" ]]; then
  VALUES_FILES+=("${HA_VALUES_FILE}")
fi

HELM_VALUES_ARGS=()
for file in "${VALUES_FILES[@]}"; do
  HELM_VALUES_ARGS+=(-f "${file}")
done

echo "Bundle output : ${BUNDLE_DIR}"
echo "Chart dir     : ${CHART_DIR}"
echo "Profile       : ${PROFILE}"
echo "Components    : ${COMPONENTS}"

if [[ "${SKIP_BUILD}" != "true" ]]; then
  dev_stage build "Building release images for components: ${COMPONENTS}"
  run env WRAPPER_VALUES_FILE="${BASE_VALUES_FILE}" "${BUILD_SCRIPT}" --components "${COMPONENTS}"
fi

dev_stage deploy "Rendering release manifests to resolve bundle image set."
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "+ helm template ${RELEASE_NAME} ${CHART_DIR} ${HELM_VALUES_ARGS[*]} ${EXTRA_HELM_SET_ARGS[*]}"
  mapfile -t RENDERED_IMAGES < <(build_images_lock | awk -F'|' '{print $2}')
else
  mapfile -t RENDERED_IMAGES < <(extract_rendered_images)
fi

[[ ${#RENDERED_IMAGES[@]} -gt 0 ]] || dev_die "No images rendered for release bundle."

LOCK_CONTENT="$(build_images_lock)"
LOCK_FILE_CONTENT="logical|source_image|archive_name|bindings"$'\n'"${LOCK_CONTENT}"

if [[ "${DRY_RUN}" != "true" ]]; then
  run rm -rf "${BUNDLE_DIR}"
  run mkdir -p "${CHART_OUTPUT_DIR}" "${IMAGE_OUTPUT_DIR}" "${VALUES_OUTPUT_DIR}" "${META_OUTPUT_DIR}"
  run cp "${BASE_VALUES_FILE}" "${VALUES_OUTPUT_DIR}/release-base.yaml"
  run cp "${UPSTREAMS_VALUES_FILE}" "${VALUES_OUTPUT_DIR}/release-upstreams.yaml"
  if [[ "${PROFILE}" == "ha" ]]; then
    run cp "${HA_VALUES_FILE}" "${VALUES_OUTPUT_DIR}/release-ha.yaml"
  fi
  printf '%s\n' "${LOCK_FILE_CONTENT}" > "${META_OUTPUT_DIR}/images.lock"
  cat > "${META_OUTPUT_DIR}/release.env" <<EOF
BUNDLE_NAME=${BUNDLE_NAME}
PROFILE=${PROFILE}
RELEASE_NAME=${RELEASE_NAME}
NAMESPACE=${NAMESPACE}
CHART_DIR=$(basename "${CHART_DIR}")
EOF
fi

dev_stage deploy "Packaging chart."
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "+ helm package ${CHART_DIR} --destination ${CHART_OUTPUT_DIR}"
else
  run helm dependency build "${CHART_DIR}"
  run helm package "${CHART_DIR}" --destination "${CHART_OUTPUT_DIR}"
  run cp "${DEPLOY_SCRIPT}" "${BUNDLE_DIR}/deploy.sh"
  run chmod +x "${BUNDLE_DIR}/deploy.sh"
fi

dev_stage build "Saving rendered images into bundle."
for image in "${RENDERED_IMAGES[@]}"; do
  archive_name="$(sanitize_image_archive_name "${image}")"
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "+ docker save -o ${IMAGE_OUTPUT_DIR}/${archive_name} ${image}"
    continue
  fi
  ensure_local_image "${image}"
  run docker save -o "${IMAGE_OUTPUT_DIR}/${archive_name}" "${image}"
done

if [[ "${DRY_RUN}" != "true" ]]; then
  (
    cd "${BUNDLE_DIR}"
    run_capture sh -c 'find charts images metadata values -type f -print0 | sort -z | xargs -0 sha256sum > metadata/SHA256SUMS'
  )
fi

echo "Release bundle ready."
echo "  bundle    : ${BUNDLE_DIR}"
echo "  profile   : ${PROFILE}"
echo "  images    : ${#RENDERED_IMAGES[@]}"
