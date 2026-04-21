# 03 服务发现、McpBridge 与 MCP

## Source URLs

- `https://higress.ai/docs/latest/user/mcp-bridge/`
- `https://higress.ai/docs/latest/user/nacos-route/`
- `https://higress.ai/docs/latest/user/spring-cloud/`
- `https://higress.ai/docs/latest/user/dubbo/`
- `https://higress.ai/docs/ai/mcp-server/`
- `https://higress.ai/docs/ai/mcp-quick-start/`

## What the official docs say

The upstream `McpBridge` doc is the base document for service discovery in Higress.

Important facts called out there:

- Higress watches the `McpBridge` resource named `default` in the install namespace.
- `spec.registries[]` is the core discovery list.
- Supported discovery `type` values include `nacos`, `nacos2`, `nacos3`, `zookeeper`, `consul`, `eureka`, `static`, and `dns`.
- `authSecretName` is used for registry auth such as Nacos or Consul.
- `static` and `dns` can be used as direct discovery backends.

The Nacos, Spring Cloud, and Dubbo docs show how Higress routes requests to discovered services after the discovery source is configured.

## Repo-specific mapping

In this repo:

- Console `service-sources` map directly to `McpBridge.spec.registries[]`
- Console `mcp-servers` can span:
  - `Ingress`
  - `higress-config`
  - builtin `mcp-server` Wasm plugin rules
  - route auth rules
  - `McpBridge` registries for direct or redirect routes
- AI providers may derive service-source style registry entries during runtime sync

## Local file map

- `aigateway-console/backend/utility/clients/k8s/controlplane.go`
  `service-sources` CRUD and AI route base resources.
- `aigateway-console/backend/utility/clients/k8s/controlplane_runtime.go`
  MCP runtime sync, `McpBridge` registry mutation, and provider-derived service-source logic.
- `aigateway-portal/backend/internal/client/k8s/model_catalog.go`
  Portal-side route and provider discovery.
- `aigateway-portal/backend/internal/service/portal/gateway_resolver.go`
  Portal gateway endpoint resolution.

## Decision rules

- If the user edits a registry address, auth, namespace, or discovery type, start from `McpBridge`.
- If the user edits an MCP server and sees unexpected runtime behavior, inspect both `Ingress` and `higress-config` before changing UI code.
- If the user asks why a provider or MCP route resolves to a certain internal service name, inspect provider runtime derivation in Console's K8s client.
- If the user mentions Nacos or Spring Cloud, do not treat it as a plain app config issue; it is a Higress discovery question.

## When to go back to the upstream pages

- The user asks for officially supported discovery types or fields
- The user needs Nacos, Spring Cloud, or Dubbo semantics rather than repo-specific adapter behavior
- A bug appears to be in service discovery timing, registry auth, or upstream routing rules
