#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
source "${ROOT_DIR}/scripts/dev-shell-lib.sh"

STAGE="all"
RELEASE_REGISTRY="${TEST_RELEASE_REGISTRY:-registry.example.com/team}"
RELEASE_BUNDLE_DIR="${TEST_RELEASE_BUNDLE_DIR:-${ROOT_DIR}/out/release/aigateway-1.1.0}"
ACCEPTANCE_DIR="${TEST_ACCEPTANCE_DIR:-${ROOT_DIR}/out/test-acceptance/latest}"
ACCEPTANCE_TEMPLATE_DIR="${ROOT_DIR}/TASK/release/acceptance"
HELM_RELEASE_NAME="${TEST_HELM_RELEASE_NAME:-aigateway}"
HELM_CHART_DIR="${TEST_HELM_CHART_DIR:-${ROOT_DIR}/helm/higress}"
HELM_BASE_VALUES="${TEST_HELM_BASE_VALUES:-${ROOT_DIR}/higress/helm/higress/values-release-base.yaml}"
HELM_HA_VALUES="${TEST_HELM_HA_VALUES:-${ROOT_DIR}/higress/helm/higress/values-release-ha.yaml}"
HELM_UPSTREAMS_VALUES="${TEST_HELM_UPSTREAMS_VALUES:-${ROOT_DIR}/higress/helm/higress/values-release-upstreams.yaml}"
GO_TEST_TIMEOUT="${TEST_GO_TEST_TIMEOUT:-5m}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/test.sh --stage unit|integration|e2e|acceptance|release|all [options]

Options:
  --stage <name>             Test stage to execute.
  --bundle-dir <path>        Release bundle directory used by the release stage.
  --registry <host/prefix>   Registry used by the release deploy dry-run.
  --acceptance-dir <path>    Chrome DevTools acceptance artifact directory.
  -h, --help                 Show help.

Environment:
  TEST_RELEASE_REGISTRY      Defaults to registry.example.com/team.
  TEST_RELEASE_BUNDLE_DIR    Defaults to out/release/aigateway-1.1.0.
  TEST_ACCEPTANCE_DIR        Defaults to out/test-acceptance/latest.
EOF
}

run_cmd() {
  echo "+ $*"
  "$@"
}

prepare_acceptance_dir() {
  local summary_file="${ACCEPTANCE_DIR}/summary.json"
  local screenshots_dir="${ACCEPTANCE_DIR}/screenshots"

  mkdir -p "${ACCEPTANCE_DIR}" "${screenshots_dir}"

  if [[ ! -f "${ACCEPTANCE_DIR}/README.md" ]]; then
    cp "${ACCEPTANCE_TEMPLATE_DIR}/README.md" "${ACCEPTANCE_DIR}/README.md"
  fi
  if [[ ! -f "${ACCEPTANCE_DIR}/console-checklist.md" ]]; then
    cp "${ACCEPTANCE_TEMPLATE_DIR}/console-checklist.md" "${ACCEPTANCE_DIR}/console-checklist.md"
  fi
  if [[ ! -f "${ACCEPTANCE_DIR}/portal-checklist.md" ]]; then
    cp "${ACCEPTANCE_TEMPLATE_DIR}/portal-checklist.md" "${ACCEPTANCE_DIR}/portal-checklist.md"
  fi
  if [[ ! -f "${ACCEPTANCE_DIR}/notes.md" ]]; then
    cat > "${ACCEPTANCE_DIR}/notes.md" <<'EOF'
# Chrome DevTools Acceptance Notes

- Record console errors, network failures, and any deviations here.
- Attach screenshot filenames under the relevant page or flow.
EOF
  fi
  if [[ ! -f "${summary_file}" ]]; then
    cp "${ACCEPTANCE_TEMPLATE_DIR}/summary.template.json" "${summary_file}"
  fi
}

run_unit_stage() {
  dev_stage test "Running unit test gate."
  dev_need_cmd go
  dev_need_cmd npm
  dev_need_cmd python3

  run_cmd bash -lc "cd '${ROOT_DIR}/aigateway-portal/backend' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' ./..."
  run_cmd bash -lc "cd '${ROOT_DIR}/aigateway-console/backend' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' ./..."
  run_cmd bash -lc "cd '${ROOT_DIR}/higress/plugins/wasm-go/extensions/ai-proxy' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' ./..."
  run_cmd bash -lc "cd '${ROOT_DIR}/higress/plugins/wasm-go/extensions/key-auth' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' ./..."
  run_cmd bash -lc "cd '${ROOT_DIR}/higress/plugins/wasm-go/extensions/ai-quota' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' ./..."
  run_cmd bash -lc "cd '${ROOT_DIR}/higress/plugins/wasm-go/extensions/ai-token-ratelimit' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' ./..."
  run_cmd bash -lc "cd '${ROOT_DIR}/higress/plugins/wasm-go/extensions/model-router' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' ./..."
  run_cmd bash -lc "cd '${ROOT_DIR}/higress/plugins/wasm-go/extensions/mcp-server' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' ./..."
  run_cmd bash -lc "cd '${ROOT_DIR}/plugin-server' && python3 -m unittest discover -s tests -p 'test_*.py'"
}

run_integration_stage() {
  dev_stage test "Running integration test gate."
  dev_need_cmd go
  dev_need_cmd docker

  run_cmd bash -lc "cd '${ROOT_DIR}/aigateway-portal/backend' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' -tags=integration ./..."
  run_cmd bash -lc "cd '${ROOT_DIR}/aigateway-console/backend' && GOTOOLCHAIN=auto go test -timeout '${GO_TEST_TIMEOUT}' -tags=integration ./..."
}

run_e2e_stage() {
  dev_stage test "Running frontend Playwright gate."
  dev_need_cmd npm

  run_cmd bash -lc "cd '${ROOT_DIR}/aigateway-console/frontend' && npm run test:e2e"
  run_cmd bash -lc "cd '${ROOT_DIR}/aigateway-portal/frontend' && npm run test:e2e"
}

run_acceptance_stage() {
  local summary_file="${ACCEPTANCE_DIR}/summary.json"

  dev_stage test "Validating Chrome DevTools acceptance artifacts."
  dev_need_cmd python3
  prepare_acceptance_dir

  run_cmd python3 "${ROOT_DIR}/scripts/validate-acceptance.py" --summary "${summary_file}"
}

run_release_stage() {
  dev_stage test "Running release preflight gate."
  dev_need_cmd helm

  run_cmd "${ROOT_DIR}/start.sh" help
  run_cmd "${ROOT_DIR}/start.sh" show
  run_cmd "${ROOT_DIR}/start.sh" sync --check
  run_unit_stage
  run_integration_stage
  run_e2e_stage
  run_acceptance_stage
  run_cmd "${ROOT_DIR}/start.sh" release-build --dry-run

  [[ -d "${RELEASE_BUNDLE_DIR}" ]] || dev_die "Release bundle directory not found for deploy dry-run: ${RELEASE_BUNDLE_DIR}"
  run_cmd "${ROOT_DIR}/start.sh" release-deploy --target k8s --bundle-dir "${RELEASE_BUNDLE_DIR}" --registry "${RELEASE_REGISTRY}" --dry-run
  run_cmd helm template "${HELM_RELEASE_NAME}" "${HELM_CHART_DIR}" -f "${HELM_BASE_VALUES}" -f "${HELM_HA_VALUES}" -f "${HELM_UPSTREAMS_VALUES}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)
      STAGE="$2"
      shift 2
      ;;
    --bundle-dir)
      RELEASE_BUNDLE_DIR="$2"
      shift 2
      ;;
    --registry)
      RELEASE_REGISTRY="$2"
      shift 2
      ;;
    --acceptance-dir)
      ACCEPTANCE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      dev_die "Unknown test argument: $1"
      ;;
  esac
done

case "${STAGE}" in
  unit)
    run_unit_stage
    ;;
  integration)
    run_integration_stage
    ;;
  e2e)
    run_e2e_stage
    ;;
  acceptance)
    run_acceptance_stage
    ;;
  release|all)
    run_release_stage
    ;;
  *)
    dev_die "Unsupported test stage: ${STAGE}"
    ;;
esac
