# Repo Higress Map

## Core principle

In this repository, `aigateway-console` and `aigateway-portal` are upper layers built on top of Higress rather than alternatives to it.

- `higress` owns actual gateway runtime behavior, service discovery, plugin execution, and controller semantics.
- `aigateway-console` is the control-plane adapter that turns frontend contracts into Higress resources and runtime side effects.
- `aigateway-portal` owns user-facing business data, but still consumes gateway routes, model metadata, key-auth state, MCP exposure, and metrics derived from Higress.

If a request affects routing, provider binding, service discovery, auth, plugin matching, or MCP exposure, start from the Higress object mapping first.

## Resource mapping used by this repo

- `routes` -> Kubernetes `Ingress`
- `domains` -> `ConfigMap` labeled `higress.io/config-map-type=domain`
- `tls-certificates` -> Kubernetes TLS `Secret`
- `ai-routes` -> `ConfigMap` labeled `higress.io/config-map-type=ai-route`
  Save also triggers runtime projection via `syncAIRouteRuntime(...)`, so do not treat the ConfigMap as the only effect.
- `ai-providers` -> builtin WasmPlugin `ai-proxy.internal` under `spec.defaultConfig.providers[]`
  Save may also derive or update service sources and route/runtime bindings.
- `mcp-servers` -> route `Ingress` plus `higress-config` MCP section plus builtin `mcp-server` plugin rules plus route auth rules
  Direct and redirect modes may also depend on `McpBridge` registries.
- `service-sources` -> `McpBridge` resource named `default`, using `spec.registries[]`
- route auth and consumer allowlist -> builtin `key-auth` WasmPlugin
- quota or gateway-backed billing runtime -> builtin `ai-quota` WasmPlugin plus Redis config

## Console file map

- REST surface: `aigateway-console/backend/internal/controller/gateway/http.go`
- resource adapter: `aigateway-console/backend/utility/clients/k8s/controlplane.go`
- runtime sync, builtin plugin rules, MCP, provider wiring: `aigateway-console/backend/utility/clients/k8s/controlplane_runtime.go`
- `higress-config` editor and validation: `aigateway-console/backend/internal/service/platform/higress_config.go`
- gateway service entry: `aigateway-console/backend/internal/service/gateway/service.go`

Important repo facts visible in code:

- `/v1/routes`, `/v1/domains`, `/v1/ai/routes`, `/v1/ai/providers`, `/v1/mcpServer`, `/v1/wasm-plugins`, and plugin-instance endpoints are adapters over Higress resources, not separate durable domain models.
- `GetAIGatewayConfig` and `SetAIGatewayConfig` read and write the `higress-config` ConfigMap, validating sections like `tracing`, `gzip`, `downstream`, and `upstream`.
- `service-sources` map directly to `McpBridge.spec.registries[]`.
- `mcp-servers` combine multiple runtime surfaces: Ingress, `higress-config`, builtin `mcp-server` match rules, and key-auth route rules.

## Portal file map

- enabled model and route discovery: `aigateway-portal/backend/internal/client/k8s/model_catalog.go`
- key-auth and ai-quota runtime sync: `aigateway-portal/backend/internal/client/k8s/gateway_sync.go`
- public and internal gateway URL resolution: `aigateway-portal/backend/internal/service/portal/gateway_resolver.go`
- gateway-derived model pricing bootstrap: `aigateway-portal/backend/internal/service/portal/model_pricing.go`
- Portal API key to gateway auth sync: `aigateway-portal/backend/internal/service/portal/keyauth_sync.go`

Important repo facts visible in code:

- Portal can infer public gateway URLs from discovered gateway Ingress routes or from `PORTAL_GATEWAY_*` environment variables.
- Portal model catalog and model plaza behavior are partly derived from gateway provider config, not only from Portal DB.
- Portal API key sync eventually mutates the builtin `key-auth` WasmPlugin consumer list.
- Portal quota and billing runtime may depend on `ai-quota` plugin state, Redis keys, Prometheus, or gateway-derived metadata.

## Runtime and deploy entrypoints

- `./start.sh` is the repo-level entrypoint for local deploy and dev flows.
- `./helm/dev-mode.yaml` controls local dev service toggles and port-forward defaults.
- `./higress/helm/higress/values-*.yaml` are the Higress-oriented Helm value baselines used by local and release flows.

## Routing heuristics

- If the request adds or changes an admin API or page that edits Higress resources, start in `aigateway-console`.
- If the request adds or changes user-facing Portal behavior whose data or URLs are gateway-derived, inspect Portal plus the corresponding Higress mapping.
- If the request changes actual routing, discovery, controller, plugin, or CRD semantics, start in `higress`.
- If the request mentions `AI Route`, `AI Provider`, `MCP Server`, `service source`, `plugin instance`, `Ingress annotation`, or `key-auth`, assume Higress object mapping matters even if the visible bug is in Console or Portal.

## Verification checklist

- Identify the source object before editing.
- Check whether save logic also performs runtime sync side effects.
- Check whether Portal or Console rely on derived internal resource aliases.
- If discovery is involved, inspect `McpBridge` or provider-derived service source logic before changing only UI labels or controller glue.
