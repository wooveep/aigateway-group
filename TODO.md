# AIGateway Group - 待办清单

> 文档职责：只维护执行清单、完成状态和待办账本。当前状态看 `task.md`，历史原因看 `Memory.md`，发布 / 部署专项台账看 `TASK/README.md`。

更新时间：2026-04-25

## 当前焦点

- 当前阶段：`P3 智能体产品化` 首版主链路已完成，下一步进入 `P4 观测、高可用、流控`。
- 当前活跃缺口：`P3/P5-AF` 模型资产 `RPM/TPM` 投影到每用户每模型限流，代码首版已完成，仍需补完整 live smoke、`429` 行为和 `/system/jobs` 手工触发验证。
- 正式交付口径：`1.1.0` release bundle、文档、离线 k3d 安装、standard profile 和 Ingress 访问已完成实机验证。

## 活跃待办

### P3/P5-AF 模型资产限流投影

- [ ] 完成 `P3/P5-AF` live smoke 闭环：验证 `modelPredicates -> x-higress-llm-model`、`ai-model-rate-limit-reconcile`、`cluster-key-rate-limit`、`ai-token-ratelimit` 在 public/internal AI Route 上协同生效。
- [ ] 补齐超限 `429` 行为验证，包括 RPM 与 TPM 两类拒绝语义。
- [ ] 验证 `/system/jobs` 手工触发 `ai-model-rate-limit-reconcile` 的 UI/API 链路。

### 运行时与本地环境遗留

- [ ] 回补 `minikube-dev` 运行时修复到仓库配置：Console 构建默认 `plugins.properties` 来源、`mcpServer.redis.password` 下发、`ai-proxy.internal` WasmPlugin 模块 URL / 版本一致性。
- [ ] 修复 Console 后端 PostgreSQL 布尔列 / 整型 SQL 混用风险：模型绑定发布 / 下架、AI Sensitive、AI Quota、旧表迁移 SQL。
- [ ] 为 Console 前端补核心页面自动化点击验证，覆盖本地启动后主要入口可访问。

### 跨项目工程治理

- [ ] 清理 `aigateway-portal/helm/values.yaml` 中遗留 deprecated fallback 字段，彻底按新入口收口。
- [ ] 评估并收口双份父 Chart 目录 `./helm/higress` 与 `higress/helm/higress` 的长期维护策略。
- [ ] 明确 Portal / Console 共库表级责任人，包括建表、迁移、回滚。
- [ ] 统一共库部署环境变量契约，保证 Helm / Manifest / release values 一致。
- [ ] 补充 `helm/README.md` 对 `start.sh dev` 自动 minikube redeploy 与 `dev-redeploy` 的说明。
- [ ] 继续收口 Portal DB 治理：DAO / DO / Entity 已补首批模型，后续推进 service 替换、共享表责任边界、testcontainers 集成测试。

### 发布治理与质量门禁

- [ ] 增加 Portal <-> Core 关键链路最小端到端验证脚本或流水线，覆盖 `./start.sh dev` 冷启动。
- [ ] 输出 core 服务、网络、数据库异常时的失败处理策略文档。
- [ ] 建立多子项目联动变更发布说明模板。
- [ ] 建立跨项目回滚手册，覆盖代码、数据库、配置、缓存投影。
- [ ] 制定跨项目最小可观测性要求：request id、consumer 标识、错误分类、核心业务指标。
- [ ] 统一后端 API 契约文档格式。
- [ ] 周期化追踪各子项目技术债：DAO 替换、SQL 治理、测试覆盖。
- [ ] 评估单次合并触发多子项目质量门禁的 CI 策略。

## 后续阶段

### P4 观测、高可用、流控

- [ ] `P4-01` 设计按部门成员、模型、智能体的调用统计口径。
- [ ] `P4-02` 规划请求级调用明细查询链路。
- [ ] `P4-03` 设计 `ai-load-balancer` 的 region / cost / latency 路由策略。
- [ ] `P4-04` 规划 fallback 与部门成员灰度放量。
- [ ] `P4-05` 设计并发 / RPM 配额能力，优先扩展 `ai-token-ratelimit` 或拆 `ai-concurrency-limit`。
- [ ] `P4-06` 规划告警规则、事件、Webhook/API 推送。

### P5 安全与上下文

- [ ] `P5-01` 设计模型、智能体、AK、输入、输出粒度的安全策略投影。
- [ ] `P5-02` 规划自定义安全规则管理。
- [ ] `P5-03` 规划配置变更审计与操作日志。
- [ ] `P5-04` 设计上下文窗口自动优化。
- [ ] `P5-05` 规划 `ai-cache`、`ai-history` 的租户与部门成员隔离。
- [ ] `P5-06` 规划长期记忆服务，默认基于 `ai-rag + 向量库`。

### P6 收口与发布

- [ ] `P6-01` 规划 Portal、Console、Higress、plugin-server 联调顺序。
- [ ] `P6-02` 定义迁移、回填、回滚步骤。
- [ ] `P6-03` 规划插件发版与分发。
- [ ] `P6-04` 定义全链路验收清单。
- [ ] `P6-05` 完成文档收口，回写 `roadmap.md` 里程碑状态与 `TODO.md` 完成记录。

## 已完成摘要

### 2026-04-24 ~ 2026-04-25：`1.1.0` 正式交付与首启稳定性

- [x] 版本源、Chart、release values、bundle 名称推进到 `1.1.0`。
- [x] 生成 `out/release/aigateway-1.1.0/`，包含镜像 tar、`higress-1.1.0.tgz`、release values、`images.lock`、`SHA256SUMS`、`deploy.sh`，并完成校验。
- [x] 新增 `docs/release/1.1.0/`、`docs/overview/aigateway-whitepaper-1.1.0.md`、`out/docs/1.1.0/aigateway-project-introduction-1.1.0.pptx`。
- [x] 完成 `release-build --dry-run`、`release-deploy --target k8s --dry-run`、release values `helm template`、正式文档导出。
- [x] 新增 `install-k3d-offline.sh`，已在 `192.168.42.200` 干净 Ubuntu 24.04.3 LTS 完整离线部署验证。
- [x] release 默认 profile 收敛为 `standard`，新建 k3d 默认单节点；`ha` 改为显式启用。
- [x] standard profile 默认启用 o11y，并将 Grafana / Prometheus / Loki / Promtail 纳入离线 bundle。
- [x] release 部署显式执行 Portal `db-init` 与 Console `portaldb-init`，避免首个业务请求承担建表职责。
- [x] Console / Portal Deployment 增加 `wait-for-portal-db` initContainer。
- [x] Console `portaldb` 健康检查、Portal `main` 数据库等待、Portal billing Redis consumer 重连均已加固。
- [x] Portal key-auth 投影固定创建 `key-auth.internal` 且 `global_auth=false`，Console 只在业务路由写 `matchRules.allow`。
- [x] release standard Redis 地址修复为 `redis-server-master`，`global.onlyPushRouteCluster=false`，`higress-config` 使用 `mergeOverwrite`。

### 2026-04-23：P3 智能体、SSO、协议收口、测试闸门

- [x] 仓库级测试入口固定为 `./start.sh test --stage unit|integration|e2e|acceptance|release|all`。
- [x] Portal / Console 集成测试切到 `integration` build tag，默认 `go test ./...` 不再拉起 Testcontainers。
- [x] 新增 Portal Playwright smoke、扩展 Console Playwright 主页面覆盖、补 `plugin-server` 最小 Python 单测。
- [x] 新增 `TASK/release/acceptance/` 与 `scripts/validate-acceptance.py`，Chrome DevTools 验收结果成为 release gate。
- [x] Portal OIDC SSO 首版完成：共享表、Portal authorize/callback、Console `/system` 配置、pending 账号改绑、组织账号软删除。
- [x] 组织模型正式收口为“部门树 + 部门管理员 + 部门成员”，废弃“父账号 / 子账号”作为正式模型。
- [x] `ai-proxy`、Console、Portal 协议事实源收口，一级 protocol 固定为 `openai/v1`、`anthropic/v1/messages`、`original`，Provider 额外允许 `auto`。
- [x] P3-01 ~ P3-06 智能体产品化完成：`agent_catalog`、Console 管理页、Portal 智能体广场、MCP HTTP/SSE 地址、grant 投影、Portal `AI对话`、会话持久化与 SSE 流式发送。

### 2026-04-09 ~ 2026-04-22：模型资产、计费、文档与 `1.0.0`

- [x] `1.0.0` 文档整编完成：根文档体系、`AGENTS.md`、`docs/` 真相源、用户手册截图、Docx / PDF 导出、bundle 镜像锁一致性。
- [x] P2 模型资产与商业化完成：显式发布绑定、两档定价、`requestKinds`、绑定授权、请求明细、部门账单汇总。
- [x] AI 路由按 Provider 选择服务、目标模型来自已发布绑定；模型资产能力字段收口为系统预置。
- [x] `asset_grant` 支持 `consumer / department / user_level`，等级授权语义统一为“高等级自动拥有低等级权限”。
- [x] AI 脱敏规则以 DB 为真相源，启动清理重复规则并补签名唯一约束。
- [x] Portal 计费主链完成：PostgreSQL 钱包 / 流水 / 请求事件为真相源，Redis 仅作运行态投影，Prometheus 只作可选对账。
- [x] `ai-quota` amount 模式、User / Key 金额限额、多来源 key-auth、细分 token / cache / image / request_count 计费、`ai-token-ratelimit` amount 窗口、AI Dashboard 细分观测均已完成首版。

### 2026-03 ~ 2026-04：平台底座与本地开发链路

- [x] 建立根级协作文档：`Project.md`、`Memory.md`、`TODO.md`、`roadmap.md`、`task.md`。
- [x] Portal / Console 共享数据库收敛为 PostgreSQL-only，统一入口为 `higress-core.postgresql.*`。
- [x] 根级 Helm 入口迁移到 `./helm/higress`，`start.sh`、`helm/dev-mode.yaml`、`scripts/port-forward-all.py` 成为统一开发入口。
- [x] `helm/image-versions.yaml` 成为镜像 repository / tag、默认 bundle 参数和 release 参数单一事实源。
- [x] `start.sh dev` 在 minikube 场景默认走本地镜像构建、加载和 rollout restart，避免前端旧产物残留。
- [x] 开发 / minikube / k3d / prod-gray 暴露策略已通过脚本校验：dev 使用 `ClusterIP + port-forward`，gateway 可按 profile 使用 hostPort 或 LoadBalancer。

## 已归档说明

- 详细过程日志已压缩到 `Memory.md` 的稳定事实与 caveat；不再在本文件保留逐日流水。
- 发布 / 部署 / bundle / HA / 验收专项材料统一看 `TASK/release/`。
- 子项目专项材料统一看 `TASK/projects/` 与各子项目轻量 `TODO.md`。
