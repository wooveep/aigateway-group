# Official Higress Doc Cache

This index localizes the Higress documentation most relevant to this skill.

- Source index: `https://higress.ai/llms.txt`
- Last rebuilt: `2026-04-18`
- Goal: let the skill read local topic references first, then open upstream docs only when exact semantics or latest details matter.

## Local topic references

Read these files by topic:

1. [01 参数与全局配置](./official-docs/01-parameters-and-global-config.md)
2. [02 路由、Annotation 与流量治理](./official-docs/02-routing-annotations-and-governance.md)
3. [03 服务发现、McpBridge 与 MCP](./official-docs/03-service-discovery-and-mcp.md)
4. [04 AI 网关、插件与鉴权配额](./official-docs/04-plugin-and-ai-gateway.md)
5. [05 Higress 开发、CRD 与调试](./official-docs/05-higress-development.md)

## How to use this cache

1. Read the local topic file first.
2. If the repo integration surface is clear but upstream Higress semantics are still ambiguous, open the source URL listed in that topic file.
3. Prefer local repo code for current `aigateway-group` integration details.
4. Prefer official docs for upstream Higress behavior, supported fields, and expected controller or plugin semantics.

## Quick selection rules

- Need Helm keys, values, or `higress-config`: start at topic `01`
- Need route matching, rewrite, gray release, or annotation scope: start at topic `02`
- Need `McpBridge`, Nacos, Spring Cloud, Dubbo, or MCP route exposure: start at topic `03`
- Need provider config, key auth, ai-quota, builtin plugin behavior, or Wasm plugin development: start at topic `04`
- Need Higress repo structure, CRD generation, controller integration, or e2e debugging: start at topic `05`
