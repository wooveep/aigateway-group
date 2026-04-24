# AIGateway 平台能力建设 Roadmap

初版日期：2026-04-07

## 背景与目标

- 基于根目录 `TODO.md` 中新增的平台能力矩阵，统一规划 Portal、AIGateway Console、Higress、plugin-server 的跨项目实施顺序。
- 在正式编码前先冻结阶段目标、依赖关系、插件改造边界和默认假设，避免多项目并行时出现范围漂移。
- 以根目录 `TODO.md` 作为执行清单，以 `task.md` 作为活跃任务工作台，以本文件作为阶段路线图和里程碑说明。
- 首轮以平台底座优先，不同时推进所有能力，按“组织授权 -> 模型资产 -> 智能体 -> 运行时增强 -> 安全与上下文 -> 联调发布”顺序实施。

## 当前能力对比

| 模块 | 当前基线 | 主要缺口 | 主要落点 |
| --- | --- | --- | --- |
| 组织、部门管理员、部门成员 | 已有用户、API Key、平铺 department 字段与 Console 分组视图 | 缺少组织树、子部门嵌套、部门管理员和显式授权模型 | Portal、Console |
| 模型上架、开放 API、广场 | 已有 Provider 管理、模型目录、Portal 模型列表、AI Route、AK 能力 | 缺少统一上架流程、授权过滤、面向部门成员的资产管理 | Portal、Console、`ai-proxy`、`key-auth` |
| 模型定价与多模态 | 已有模型价格版本和完整价格字段扩展 | 多模态协议矩阵不完整，价格策略仍需产品化 | Portal、Console、`ai-quota`、`model-router` |
| 智能体接入与开放 | 已有 MCP Server 管理、访问地址、Consumer 授权 | 缺少 `agent_catalog`、智能体广场、标准化接入说明和资产封装 | Console、Portal、`mcp-server`、`mcp-router` |
| 可观测与记账 | 已有 `billing_usage_event`、AI Dashboard、用量聚合和基础计费 | 缺少请求级明细、子部门账单、告警闭环 | Portal、Console、`ai-statistics` |
| 智能路由与高可用 | 已有 AI Route fallback、部分 provider failover 能力 | 缺少 region/cost/latency 联合决策与部门成员灰度 | Console、`ai-load-balancer` |
| 流量控制 | 已有额度、窗口限流、金额限流等能力 | 缺少并发额度、按模型/智能体/部门成员维度的产品化配置与告警 | Console、`ai-token-ratelimit`、`ai-quota` |
| 安全增强 | 已有 AI 安全插件、敏感词、TLS/WAF 基础能力 | 缺少模型/智能体 + AK + 输入/输出粒度策略与审计 | Console、`ai-security-guard` |
| 上下文管理 | 已有 `ai-cache`、`ai-history`、`ai-rag` 基础能力 | 缺少窗口自动优化、租户隔离缓存策略、长期记忆产品化 | Portal、Console、`ai-cache`、`ai-history`、`ai-rag` |

## 阶段路线图

| 阶段 | 周期 | 目标 | 主要输出 | 依赖 | 涉及系统 | 涉及插件 |
| --- | --- | --- | --- | --- | --- | --- |
| P0 基线与文档 | 1 周 | 冻结范围、任务与默认项 | `roadmap.md`、`TODO.md` 执行面板、`task.md` 模板、能力对比矩阵 | 无 | 根目录协作文档 | 无 |
| P1 组织与授权底座 | 2 周 | 建立组织树、部门管理员与授权模型 | 领域模型、废弃旧 `department` 字段方案、组织与授权 API/UI 实现、Portal 部门成员管理能力 | P0 | Portal、Console | 复用 `key-auth`，投影到现有 consumer/AK |
| P2 模型资产与商业化 | 2 周 | 统一模型上架、定价、授权和账单视图 | 模型上架流程、两档价格策略、模型广场授权过滤、调用明细方案 | P1 | Portal、Console | 复用 `ai-proxy`、`ai-quota`、`model-router` |
| P3 智能体产品化 | 2 周 | 将 MCP 能力产品化为智能体资产 | `agent_catalog`、智能体接入配置、开放 API/AK、智能体广场 | P1 | Portal、Console | 复用 `mcp-server`、`mcp-router` |
| P4 观测、高可用、流控 | 3 周 | 补齐明细、智能路由、fallback、限流告警 | 请求明细链路、路由策略、灰度放量、并发/RPM 配额与告警 | P2、P3 | Portal、Console、Higress | 改造 `ai-load-balancer`、`ai-token-ratelimit`、`ai-statistics` |
| P5 安全与上下文 | 3 周 | 补齐细粒度安全、上下文优化和长期记忆 | 安全策略投影、审计、缓存隔离、短期/长期记忆方案 | P1、P2、P3、P4 | Portal、Console、Higress | 改造 `ai-security-guard`、`ai-cache`、`ai-history`，复用 `ai-rag` |
| P6 收口与发布 | 1 周 | 完成联调、迁移、发版与验收 | 联调顺序、回填/回滚步骤、插件发版、全链路验收结论 | P1-P5 | Portal、Console、Higress、plugin-server | plugin-server 分发与插件版本收口 |

## 插件改造清单

| 插件 | 处理方式 | 改造目标 | 对应阶段 |
| --- | --- | --- | --- |
| `ai-load-balancer` | 重点改造 | 支持 region、cost、latency 的综合路由决策，并为 fallback/灰度预留策略参数 | P4 |
| `ai-token-ratelimit` | 重点改造或拆分 | 承接并发/RPM/金额窗口控制；若实现复杂度过高，拆出 `ai-concurrency-limit` | P4 |
| `ai-security-guard` | 重点改造 | 支持模型/智能体/AK/输入/输出多粒度策略投影与拦截结果标记 | P5 |
| `ai-cache` | 中度改造 | 增加主租户、部门成员命名空间和上下文缓存控制 | P5 |
| `ai-history` | 中度改造 | 增加短期记忆隔离与调用侧可控策略 | P5 |
| `ai-statistics` | 轻度改造 | 对齐请求级明细查询、告警口径和实时指标字段 | P4 |
| `mcp-server` / `mcp-router` | 复用为主 | 不改核心协议，围绕资产封装、展示和授权补产品层能力 | P3 |
| `ai-quota` / `key-auth` / `model-router` | 复用为主 | 沿用现有运行时能力，通过控制面下发新的配置模型 | P1、P2 |
| `ai-rag` | 复用为主 | 作为长期记忆底座，不在首轮扩展核心协议 | P5 |

## 里程碑验收

| 里程碑 | 状态 | 完成判定 |
| --- | --- | --- |
| M0 文档基线完成 | 已完成 | 根目录 `TODO.md`、`roadmap.md`、`task.md` 对齐，任务 ID 唯一且可追踪 |
| M1 组织与授权底座完成 | 已完成 | 子部门与部门管理员模型冻结，授权链路可投影到现有 consumer/AK，Portal 已可由部门管理员管理本部门树成员 |
| M2 模型资产与账务完成 | 未开始 | 模型上架、价格、授权、明细、部门账单形成闭环 |
| M3 智能体产品化完成 | 未开始 | MCP-backed agent 可在 Console/Portal 以资产方式管理和调用 |
| M4 运行时增强完成 | 未开始 | 智能路由、fallback、灰度、并发/RPM/告警链路闭环 |
| M5 安全与上下文完成 | 未开始 | 细粒度安全、审计、缓存隔离、短期/长期记忆方案落地 |
| M6 联调发布完成 | 未开始 | Portal、Console、Higress、plugin-server 完成全链路验证并具备回滚方案 |

## 风险与默认项

- 默认采用平台底座优先，先打通组织、授权、资产与账务，再进入运行时增强。
- 智能体 v1 默认定义为 MCP-backed agent，不单独设计新协议栈。
- 模型定价 v1 默认维持“两档模型定价”，即基础价和 `above_200k` 分级，不扩展为任意 N 档。
- 请求级调用明细默认复用 `billing_usage_event` 作为真相源，不新增平行明细表。
- P1 明确不保留旧 `portal_user.department` 的兼容读写链路，现有账号统一通过 `org_account_membership` 进入未分配状态后再由 Console 重新分配。
- 根目录 `TODO.md`、`roadmap.md`、`task.md` 是首轮跨项目主控文档；子项目内只保留本项目自身的 `README.md`、`project.md`、`TODO.md`、`TASK.md` 作为轻量入口，不作为跨项目同步源。
- 插件发布默认继续通过 `plugin-server` 分发，插件改造完成后必须补版本和联调记录。
