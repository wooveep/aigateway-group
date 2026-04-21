# 04 AI 网关、插件与鉴权配额

## Source URLs

- `https://higress.ai/docs/latest/user/plugins/ai/api-provider/ai-proxy/`
- `https://higress.ai/docs/latest/user/plugins/ai/api-consumer/ai-quota/`
- `https://higress.ai/docs/latest/user/plugins/ai/api-consumer/ai-token-ratelimit/`
- `https://higress.ai/docs/latest/user/plugins/ai/api-o11y/ai-statistics/`
- `https://higress.ai/docs/latest/user/plugins/authentication/key-auth/`
- `https://higress.ai/docs/latest/user/plugins/intro/`
- `https://higress.ai/docs/latest/user/plugins/custom/`
- `https://higress.ai/docs/latest/user/plugins/wasm-dev/wasm14/`
- `https://higress.ai/docs/latest/user/plugins/wasm-dev/wasm16/`
- `https://higress.ai/docs/latest/user/wasm-go/`

## Read with local plugin references

When the task is plugin-specific, do not use this file alone.

Also read:

- `../plugin-doc-index.md`
- `../plugin-code-map.md`
- `../plugin-development-workflow.md`

## What matters for this repo

This repo uses builtin Higress plugin concepts as durable runtime state, not just documentation examples.

Important runtime surfaces:

- AI provider config ultimately lives in builtin `ai-proxy.internal`
- auth and consumer allowlists ultimately live in builtin `key-auth`
- quota-related runtime behavior ultimately lives in builtin `ai-quota`
- route-level plugin behavior can be represented by builtin plugin match rules or plugin instances

## Repo-visible mappings

- `ai-providers`
  Persist into `ai-proxy.internal` under `spec.defaultConfig.providers[]`
- Portal API key sync
  Mutates builtin `key-auth` consumers
- route auth and MCP auth
  Reuse builtin key-auth rule machinery
- quota discovery and billing runtime
  Depend on builtin `ai-quota` rules and Redis config

Console code that matters:

- `aigateway-console/backend/utility/clients/k8s/controlplane.go`
- `aigateway-console/backend/utility/clients/k8s/controlplane_runtime.go`
- `aigateway-console/backend/internal/service/gateway/service.go`

Portal code that matters:

- `aigateway-portal/backend/internal/client/k8s/gateway_sync.go`
- `aigateway-portal/backend/internal/service/portal/keyauth_sync.go`
- `aigateway-portal/backend/internal/service/portal/model_pricing.go`

## Practical rules

- If the user changes provider endpoint, protocol, or token handling, inspect provider normalization and runtime sync before editing the form.
- If the user changes API key behavior, inspect `key-auth` runtime sync before editing Portal-only code.
- If the user changes quota or billing runtime assumptions, inspect `ai-quota` discovery and Redis binding before changing data presentation.
- If the request is "new capability belongs in gateway runtime or plugin layer", use the upstream plugin docs to decide whether it fits builtin config, plugin instance wiring, or custom Wasm development.
- If the request is about a named plugin's source code, jump to `plugin-code-map.md` to resolve the actual implementation directory before changing any UI, metadata, or packaged artifact.

## When to go back to the upstream pages

- The user asks what a builtin plugin officially supports
- The runtime object is present but you need upstream field semantics
- The request may require a custom Wasm plugin or deeper SDK knowledge
