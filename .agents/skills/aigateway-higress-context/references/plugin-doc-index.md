# Plugin Doc Index

This reference localizes the official plugin doc entrypoints from `https://higress.ai/llms.txt`.

Use this file when the user asks what a builtin plugin does, how it is configured, or which official page defines its fields and behavior.

## How to use this index

1. Identify the plugin name and category here.
2. Read the corresponding local source README under `higress/plugins/...`.
3. If the task is about runtime semantics or exact supported fields, open the official URL for that plugin.
4. If the task is about Console plugin metadata or schema distribution, also inspect `plugin-server/local-plugins/<plugin>/<version>/spec.yaml`.

## AI plugins

### AI provider side

- `ai-cache`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-provider/ai-cache/`
- `ai-prompt-decorator`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-provider/ai-prompt-decorator/`
- `ai-proxy`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-provider/ai-proxy/`
- `ai-security-guard`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-provider/ai-security-guard/`

### AI consumer side

- `ai-data-masking`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-consumer/ai-data-masking/`
- `ai-quota`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-consumer/ai-quota/`
- `ai-token-ratelimit`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-consumer/ai-token-ratelimit/`

### AI development side

- `ai-agent`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-dev/ai-agent/`
- `ai-json-resp`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-dev/ai-json-resp/`
- `ai-prompt-template`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-dev/ai-prompt-template/`
- `ai-search`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-dev/ai-search/`

### AI observability and others

- `ai-statistics`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-o11y/ai-statistics/`
- `geo-ip`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/api-o11y/geo-ip/`
- `ai-history`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/others/ai-history/`
- `ai-intent`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/others/ai-intent/`
- `ai-rag`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/others/ai-rag/`
- `ai-transformer`
  - Doc: `https://higress.ai/docs/latest/user/plugins/ai/others/ai-transformer/`

## Authentication plugins

- `basic-auth`
  - Doc: `https://higress.ai/docs/latest/user/plugins/authentication/basic-auth/`
- `ext-auth`
  - Doc: `https://higress.ai/docs/latest/user/plugins/authentication/ext-auth/`
- `hmac-auth`
  - Doc: `https://higress.ai/docs/latest/user/plugins/authentication/hmac-auth/`
- `hmac-auth-apisix`
  - Doc: `https://higress.ai/docs/latest/user/plugins/authentication/hmac-auth-apisix/`
- `jwt-auth`
  - Doc: `https://higress.ai/docs/latest/user/plugins/authentication/jwt-auth/`
- `key-auth`
  - Doc: `https://higress.ai/docs/latest/user/plugins/authentication/key-auth/`
- `oauth`
  - Doc: `https://higress.ai/docs/latest/user/plugins/authentication/oauth/`
- `oidc`
  - Doc: `https://higress.ai/docs/latest/user/plugins/authentication/oidc/`
- `opa`
  - Doc: `https://higress.ai/docs/latest/user/plugins/authentication/opa/`

## Transformation plugins

- `cache-control`
  - Doc: `https://higress.ai/docs/latest/user/plugins/transformation/cache-control/`
- `custom-response`
  - Doc: `https://higress.ai/docs/latest/user/plugins/transformation/custom-response/`
- `de-graphql`
  - Doc: `https://higress.ai/docs/latest/user/plugins/transformation/de-graphql/`
- `frontend-gray`
  - Doc: `https://higress.ai/docs/latest/user/plugins/transformation/frontend-gray/`
- `transformer`
  - Doc: `https://higress.ai/docs/latest/user/plugins/transformation/transformer/`

## Traffic plugins

- `cluster-key-rate-limit`
  - Doc: `https://higress.ai/docs/latest/user/plugins/traffic/cluster-key-rate-limit/`
- `key-rate-limit`
  - Doc: `https://higress.ai/docs/latest/user/plugins/traffic/key-rate-limit/`
- `request-validation`
  - Doc: `https://higress.ai/docs/latest/user/plugins/traffic/request-validation/`
- `traffic-tag`
  - Doc: `https://higress.ai/docs/latest/user/plugins/traffic/traffic-tag/`

## Security plugins

- `bot-detect`
  - Doc: `https://higress.ai/docs/latest/user/plugins/security/bot-detect/`
- `cors`
  - Doc: `https://higress.ai/docs/latest/user/plugins/security/cors/`
- `ip-restriction`
  - Doc: `https://higress.ai/docs/latest/user/plugins/security/ip-restriction/`
- `replay-protection`
  - Doc: `https://higress.ai/docs/latest/user/plugins/security/replay-protection/`
- `request-block`
  - Doc: `https://higress.ai/docs/latest/user/plugins/security/request-block/`
- `waf`
  - Doc: `https://higress.ai/docs/latest/user/plugins/security/waf/`

## General plugin development docs

- Plugin intro:
  - `https://higress.ai/docs/latest/user/plugins/intro/`
- Custom plugin overview:
  - `https://higress.ai/docs/latest/user/plugins/custom/`
- Wasm plugin dev intro:
  - `https://higress.ai/docs/latest/user/plugins/wasm-dev/wasm14/`
- Wasm plugin internals:
  - `https://higress.ai/docs/latest/user/plugins/wasm-dev/wasm15/`
- Go SDK and request flow:
  - `https://higress.ai/docs/latest/user/plugins/wasm-dev/wasm16/`
- HTTP call inside plugin:
  - `https://higress.ai/docs/latest/user/plugins/wasm-dev/wasm17/`
- Redis call inside plugin:
  - `https://higress.ai/docs/latest/user/plugins/wasm-dev/wasm18/`
- Wasm effect mechanism:
  - `https://higress.ai/docs/latest/user/plugins/wasm-dev/wasm19/`
- Go Wasm plugin development:
  - `https://higress.ai/docs/latest/user/wasm-go/`

## Repo-first shortcuts

- If the plugin is AI-heavy or modern builtin, check `higress/plugins/wasm-go/extensions/<plugin>/README.md` first.
- If the plugin name appears with underscores in source, also try the normalized C++ directory under `higress/plugins/wasm-cpp/extensions/<plugin_with_underscores>/`.
- If the plugin is distributed through plugin-server UI or marketplace metadata, inspect `plugin-server/local-plugins/<plugin>/<version>/spec.yaml`.
