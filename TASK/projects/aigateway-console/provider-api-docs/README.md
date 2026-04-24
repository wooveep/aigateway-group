# Provider API 文档投递位

该目录用于存放供应商协议与接口文档，作为 `Console model-assets / ai-providers / Portal / ai-proxy` 扩展协议推荐、入口推荐和转换策略的判断前提。

当前实现按 `TASK/projects/aigateway-console/provider-api-docs/<provider>/` 子目录读取事实源，而不是只看本目录根 `README.md`。

## 使用原则

- 只接受供应商官方 API 文档、官方 OpenAPI 描述、官方 SDK 协议说明，或项目内已确认引用的正式文档摘录。
- 未投递文档的供应商协议统一标记为“待确认”，不得据此猜测原生协议、OpenAI 兼容程度、推荐入口地址或转换规则。
- `responses` 等接口能力优先按 `capability` 管理，不默认上升为一级 `protocol`。
- `openai` 协议继续保留现有自动协议检测前提下的兼容语义；显式 `openai` 仍允许 Claude `/v1/messages` 自动兜底，显式 `original` 才完全关闭 OpenAI / Claude 自动检测。
- 若某能力已被当前 `ai-proxy` 的 `openai` 协议覆盖，应记录为 OpenAI 协议内 capability，而不是新增独立协议。

## 建议命名

- `<provider>-official-api.md`
- `<provider>-openapi.json`
- `<provider>-compatibility-notes.md`

其中 `<provider>` 使用仓库内 canonical provider 名称，例如：

- `openai`
- `claude`
- `gemini`
- `qwen`
- `zhipuai`
- `volcengine`
- `vllm`

## 启用门槛

- 只有当该目录下存在足够确认协议行为的官方文档时，才允许把供应商纳入：
  - 协议推荐下拉
  - 入口地址推荐
  - `providerProtocolMatrix`
  - `providerDocsStatus=confirmed`
  - 新的真实协议转换或 capability 标注

- `providerDocsStatus` 的判断粒度固定到 provider 子目录：
  - `confirmed`：`provider-api-docs/<provider>/` 子目录下已有足够确认协议行为的官方文档
  - `pending`：缺少对应子目录，或子目录里只有占位说明、没有足够官方文档

- 若文档只覆盖部分接口，需明确标记已确认范围，例如：
  - 仅确认 `chat/completions`
  - 仅确认 `messages`
  - 仅确认 `responses`
  - 仅确认 embeddings / rerank / image 等附属能力

## 当前约束

- 本目录是协议判断前提，不是可选参考。
- 未确认项只允许写入 TASK 待办，不允许直接进入实现。
- 协议目录接口、推荐入口和 docs status 的服务端实现，必须以各 provider 子目录中的实际文档文件为准。
