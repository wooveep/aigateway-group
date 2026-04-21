# 01 参数与全局配置

## Source URLs

- `https://higress.ai/docs/latest/user/configurations/`
- `https://higress.ai/docs/latest/user/configmap/`

## What these docs cover

Official Higress docs describe two different configuration surfaces:

- Helm or `hgctl` values used during install and deploy
- Runtime global config stored in the `higress-config` ConfigMap

In this repo, both matter:

- deploy-time values live under `higress/helm/higress/values-*.yaml` and root `helm/dev-mode.yaml`
- runtime `higress-config` editing is exposed by Console and validated in `aigateway-console/backend/internal/service/platform/higress_config.go`

## High-value Helm parameter groups

The official parameters doc groups the important install knobs into:

- `global.*`
- `higress-core.meshConfig.*`
- `higress-core.gateway.*`
- `higress-core.controller.*`
- `higress-core.pilot.*`
- `higress-console.*`

When working in this repo, pay special attention to:

- `global.ingressClass`
  Controls which `Ingress` resources Higress watches.
- `global.watchNamespace`
  Controls namespace scope for watched resources.
- `global.enableGatewayAPI`
  Matters if the task crosses from classic `Ingress` handling to Gateway API.
- `higress-core.gateway.httpPort` and `higress-core.gateway.httpsPort`
  Matter for public gateway exposure assumptions.
- `higress-core.gateway.service.type`
  Matters for local or cluster exposure behavior.
- `higress-core.controller.replicas`, `resources.*`, `probe.*`
  Matter when controller behavior or readiness changes are involved.
- `higress-core.pilot.env.*`
  Matters when runtime behavior is scoped by namespace or metadata exchange.
- `higress-console.*`
  Matters only when upstream Higress Console semantics are relevant. For this repo's Console, prefer local code and local charts first.

## High-value `higress-config` sections

The official global-config doc shows that the `higress-config` ConfigMap holds a `higress` YAML object with top-level sections such as:

- `addXRealIpHeader`
- `disableXEnvoyHeaders`
- `tracing`
- `gzip`
- `downstream`
- `upstream`

Key settings to remember:

- `downstream.maxRequestHeadersKb`
  Request-header limit at the gateway edge.
- `downstream.idleTimeout`
  Idle timeout for downstream connections.
- `downstream.http2.*`
  HTTP/2 concurrency and window sizing.
- `upstream.connectionBufferLimits`
  Upstream buffer limits.
- `tracing`
  Requires exactly one backend when enabled.
- `gzip.*`
  Compression behavior and safety bounds.

## Repo-specific mapping

- Console's AI Gateway config editor is not a generic text box. It validates the same major sections the official docs describe.
- If the user changes config semantics, inspect `aigateway-console/backend/internal/service/platform/higress_config.go` before editing UI.
- If the user changes deploy-time values, inspect root `./start.sh`, `./helm/dev-mode.yaml`, and `./higress/helm/higress/values-*.yaml` before applying upstream examples directly.

## When to go back to the upstream pages

- The user asks for exact Helm keys or default values
- The user asks what Higress itself officially supports in `higress-config`
- The repo code validates a field but you need upstream semantics for edge-case handling
