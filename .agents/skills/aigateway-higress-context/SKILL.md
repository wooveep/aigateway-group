---
name: aigateway-higress-context
description: Understand Higress as the runtime and control-plane foundation of the aigateway-group repository. Use this skill whenever the task touches Higress 参数配置、higress-config、Helm values、Ingress/ConfigMap/WasmPlugin/McpBridge/EnvoyFilter、AI Route/AI Provider/MCP Server/Service Source、服务发现、插件实例、Key Auth/AI Quota，or when developing `aigateway-portal` / `aigateway-console` features that actually read or write Higress runtime state through APIs, Kubernetes resources, annotations, or service discovery. This skill should also trigger when the user asks “这个 Console/Portal 功能底层对应什么 Higress 资源”, “Higress 怎么配”, “Higress 怎么开发/调试”, “CRD/服务发现改哪里”, or wants repo-specific Higress context before editing.
---

# AIGateway Higress Context

Use this skill to reason from Higress source-of-truth objects before editing upper-layer Portal or Console features.

## Goal

Answer these questions first:

1. Which layer owns the behavior: `higress`, `aigateway-console`, or `aigateway-portal`?
2. Which Higress object or config is the real source of truth?
3. Is the requested change a UI/API adapter change, or a runtime semantics change?

## Read order

Read these files first:

1. `./Project.md`
2. `./task.md`
3. `./.agents/skills/aigateway-higress-context/references/repo-higress-map.md`
4. `./.agents/skills/aigateway-higress-context/references/official-doc-map.md`

If the task is plugin-related, also read these references before opening plugin source code:

5. `./.agents/skills/aigateway-higress-context/references/plugin-doc-index.md`
6. `./.agents/skills/aigateway-higress-context/references/plugin-code-map.md`
7. `./.agents/skills/aigateway-higress-context/references/plugin-development-workflow.md`

Then inspect only the relevant local code:

- Console control-plane adapter:
  - `./aigateway-console/backend/utility/clients/k8s/controlplane.go`
  - `./aigateway-console/backend/utility/clients/k8s/controlplane_runtime.go`
  - `./aigateway-console/backend/internal/service/gateway/service.go`
  - `./aigateway-console/backend/internal/service/platform/higress_config.go`
  - `./aigateway-console/backend/internal/controller/gateway/http.go`
- Portal gateway/runtime integration:
  - `./aigateway-portal/backend/internal/client/k8s/model_catalog.go`
  - `./aigateway-portal/backend/internal/client/k8s/gateway_sync.go`
  - `./aigateway-portal/backend/internal/service/portal/gateway_resolver.go`
  - `./aigateway-portal/backend/internal/service/portal/model_pricing.go`
  - `./aigateway-portal/backend/internal/service/portal/keyauth_sync.go`
- Runtime/deploy/config entrypoints:
  - `./start.sh`
  - `./helm/dev-mode.yaml`
  - `./higress/helm/higress/values-local-minikube.yaml`
  - `./higress/helm/higress/values-production-k3d.yaml`
  - `./higress/helm/higress/README.md`

## Default mental model

- `higress` owns gateway runtime semantics, service discovery, plugin execution, and controller behavior.
- `aigateway-console` is an adapter over Higress resources. Its backend exposes REST endpoints and maps frontend payloads to Higress K8s resources, annotations, ConfigMaps, WasmPlugin rules, and service discovery config.
- `aigateway-portal` is an upper-layer product. Its business data lives in Portal DB, but model metadata, gateway URLs, MCP exposure, API key sync, and parts of billing or usage still depend on Higress runtime state.
- If a Portal or Console feature changes route matching, provider wiring, service discovery, plugin binding, auth behavior, or MCP exposure, inspect the Higress object mapping first.

## Decision rules

- For `routes`, `domains`, `tls-certificates`, `ai-routes`, `ai-providers`, `mcp-servers`, `service-sources`, or plugin instances, start from Console's K8s client and map the request to the underlying object type.
- For Portal work on model plaza, agent plaza, MCP access URL, API key sync, or gateway-derived usage data, inspect Portal's K8s and gateway integration before editing UI or controller code.
- For pure Portal account, invoice, recharge, or session work with no gateway effect, stay in `aigateway-portal`.
- For pure Higress runtime, CRD, service discovery, or plugin behavior, work in `higress` first and treat Portal and Console as consumers of that behavior.
- For builtin plugin behavior, resolve the plugin name to its source directory first. Do not start from `plugin-server/local-plugins` unless the task is about packaged metadata, `spec.yaml`, README distribution, or plugin-server publishing behavior.
- For plugin config or effect questions, inspect this sequence: official plugin doc index -> plugin source README -> plugin code -> plugin-server packaged `spec.yaml` if UI/schema or distribution metadata is involved.

## When to open official Higress docs

Open the relevant URLs from `references/official-doc-map.md` when local repo code shows the integration surface but not the upstream semantics, especially for:

- Helm values and runtime parameters
- `higress-config` structure
- `McpBridge` and service discovery behavior
- Wasm plugin behavior and SDK semantics
- Custom CRD generation, controller integration, and e2e/debug workflow
- Official plugin configuration semantics and supported fields

## Working style

- Explain changes in terms of object truth, not just page names or directories.
- Be explicit about which layer owns the change: Portal business layer, Console adapter layer, or Higress runtime layer.
- When a feature spans layers, name the primary write path and the secondary consumers.
- Prefer repo scripts and repo values files for verification. Do not replace `./start.sh` and local Helm values with invented generic Higress workflows unless the user explicitly asks for a lower-level path.
- When a user asks about a named plugin, identify:
  1. official config doc
  2. local source directory
  3. local README/config examples
  4. build/test path
  5. whether `plugin-server/local-plugins` metadata also needs updating
