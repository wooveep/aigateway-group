# AIGateway Group - 待办清单

> 文档职责：本文件只维护执行清单、完成状态和待办账本。  
> 当前状态看 `task.md`，历史原因看 `Memory.md`，发布 / 部署专项任务看 `TASK/README.md`。

## P0（2026-04-24 1.1.0 正式发布交付）

- [x] 将正式版本源、Chart 版本、release values 和默认 bundle 名称推进到 `1.1.0`。
- [x] 新增 `1.1.0` 发布说明、镜像包说明和 K8S / K3D&Helm 部署说明。
- [x] 新增 `1.1.0` 项目介绍白皮书。
- [x] 输出 `1.1.0` release bundle 镜像包。
  结果：`out/release/aigateway-1.1.0/` 已生成，当前 standard profile bundle 包含 13 个镜像 tar、`higress-1.1.0.tgz`、release values、`images.lock`、`SHA256SUMS` 与 `deploy.sh`；`SHA256SUMS` 已排除自身并校验通过。
- [x] 输出 `1.1.0` 项目介绍 PPT，并覆盖项目架构图与业务逻辑图。
  结果：`out/docs/1.1.0/aigateway-project-introduction-1.1.0.pptx` 已生成，封面资产来自 `imagegen`。
- [x] 完成 `1.1.0` 发布 dry-run、Helm template 和文档导出校验。
  结果：`release-build --dry-run`、`k8s release-deploy --dry-run`、release values `helm template`、正式文档导出均已通过；`k3d` dry-run 因当前机器缺少 `k3d` 命令未执行成功。
- [x] 修复 `1.1.0` 干净库首启阻断与正式访问口径。
  结果：Portal 启动迁移已补 `portal_model_binding_price_version`，账单模型 bootstrap 在 K8s 模型目录为空时会回退到 legacy `portal_model_catalog`；release values 已改为 Console / Portal 走 Kubernetes Ingress，不依赖 port-forward；已重新生成 `out/release/aigateway-1.1.0/` 并升级 `192.168.42.200` 到 Helm revision `3`。
- [x] 增加正式部署域名配置契约。
  结果：`release-deploy` 支持读取 / 写入 `aigateway-system/aigateway-cluster-domain`，支持 `--base-domain`、`--console-host`、`--portal-host`；新增 `release-k3d-cluster.sh` 用于创建 k3d 时指定域名。
- [x] 收敛 k3d 标准部署副本数并启用内置监控。
  结果：release 默认 profile 已改为 `standard`，新建 k3d 默认 `--agents 0`；standard profile 使用单副本 / standalone PostgreSQL 和 Redis，并默认启用 Grafana / Prometheus / Loki / Promtail。`192.168.42.200` 重置后已完成 Helm revision `3` 部署，Console Dashboard 登录态返回 `builtIn: true`。
- [x] 增加 Ubuntu 24.04 离线 k3d 一键安装脚本。
  结果：bundle 已包含 `install-k3d-offline.sh`，会安装 runtime、创建单节点 k3d、逐节点导入 k3d/k3s 系统镜像和 release 镜像，并执行 Helm 部署；`192.168.42.200` 重置为干净 Ubuntu 24.04.3 LTS 后已用该脚本完整离线安装并部署成功。
- [x] 修复 Portal key-auth 投影与 WasmPlugin 绑定口径。
  结果：Portal key-auth 同步器会在缺失时创建 `key-auth.internal`，但实例级配置固定 `global_auth=false`，只作为 consumers / key 提取配置来源；Console 仍按业务路由写 `matchRules.allow`，不会默认全局拦截 Console / Portal Ingress。

## P0（2026-04-24 仓库级测试闸门与页面验收）

- [x] 为 `./start.sh` 增加统一测试入口 `test --stage unit|integration|e2e|acceptance|release|all`。
  结果：新增 `scripts/test.sh`，将后端单测、`integration` tag 集成测试、Playwright、Chrome DevTools 验收校验和 release dry-run 串成统一门禁。
- [x] 为 Portal 前端补 Playwright smoke，并扩展 Console 前端 Playwright 覆盖主页面。
  结果：Portal 已新增 `playwright.config.ts` 与 `tests/portal-pages.smoke.spec.ts`；Console 已补管理页 smoke，覆盖 Dashboard、组织、模型资产、Provider、Agent Catalog、MCP、System Jobs。
- [x] 为 `plugin-server` 补最小单测，并补齐 Chrome DevTools 验收模板与校验脚本。
  结果：`plugin-server/tests/test_plugin_scripts.py` 已覆盖元数据与 properties 解析；`TASK/release/acceptance/` 与 `scripts/validate-acceptance.py` 已作为 acceptance 真相源。

## P0（2026-04-22 文档整编 / 1.0.0 正式交付）

- [x] 收口根级文档职责边界，明确研发 / 产品主控与发布 / 部署主控两条主线。
- [x] 更新 `AGENTS.md` 为仓库唯一 agent 协作规则入口，写清读取优先级、正式约束和同步要求。
- [x] 建立 `docs/` 正式文档源码目录，补齐 `1.0.0` 白皮书、发布说明、镜像包说明、部署说明和用户手册 Markdown 真相源。
- [x] 基于 `1.0.0` 环境补齐 Portal + Console 用户手册截图，并输出到 `output/manual/1.0.0/`。
- [x] 产出 Docx / PDF 正式交付件并完成链接、图片、导出校验。
- [x] 修复 `release-build` 中 `images.lock` 与 bundle `images/*.tar` 不一致的问题，确保正式 bundle 可用于后续 `release-deploy`。

## P3（2026-04-23 协议事实源与 ai-proxy 协议收口）

- [x] 统一 `Console model-assets / ai-providers / Portal / ai-proxy` 的协议事实源，固定一级 protocol 为 `openai/v1`、`anthropic/v1/messages`、`original`，并将 `responses` 等接口能力收口为 capability / 推荐入口。
- [x] 调整 `ai-proxy` `provider.protocol` 语义为 `auto/openai/anthropic/original`，保持 `auto` 自动检测、显式 `openai` 仍允许 Claude `/v1/messages` 自动兜底、显式 `original` 才完全关闭自动检测。
- [x] 新增 Console 协议目录接口，统一输出 `protocolOptions`、`recommendedEndpoints`、`providerProtocolMatrix`、`providerDocsStatus`。
- [x] 将 Console Provider / Model Binding 表单改为受控协议下拉，并按协议目录联动推荐入口与 docs status 展示。
- [x] 收口 `TASK/projects/aigateway-console/provider-api-docs/<provider>/` 为 provider 文档事实源；未投递足够官方文档的 provider 统一标记为 `pending`。
- [x] 兼容迁移历史协议值：`openai` / `responses` / `anthropic` / `claude` / 空值等旧口径会在 Console / Portal 读写路径中归一为 canonical protocol 与推荐 endpoint。

## P3（2026-04-23 Portal OIDC SSO 首版）

- [x] 为 Portal / Console 共库补齐 `portal_sso_config`、`portal_user_sso_identity` 两张共享表。
  结果：Portal 启动迁移与 Console `portaldb` 自动建表已同步覆盖，SSO 配置与外部身份绑定有了统一事实源。
- [x] 为 Portal 后端新增 OIDC SSO 配置读取、authorize、callback 与邮箱首绑 / 自动建档链路。
  结果：Portal 保留本地账号体系，同时支持单一全局 OIDC Provider；首次 SSO 登录会优先 `(issuer, sub)` 命中绑定，其次按邮箱首绑，未命中时自动创建 `source=sso`、`status=pending` 的本地账号并补空 membership。
- [x] 为 Console `/system` 页面新增 Portal SSO 配置入口，并在保存时校验 OIDC discovery。
  结果：Console 新增 `GET/PUT /v1/portal/sso`，前端可配置启用开关、按钮文案、issuer/client/scopes/claim mapping；读取时 `clientSecret` 脱敏，保存前会校验 `issuer`、`authorization_endpoint`、`token_endpoint`、`jwks_uri`。
- [x] 为 Portal 前端登录/注册页补充 SSO 入口与提示，并增加 `PORTAL_PUBLIC_BASE_URL` 部署约束。
  结果：登录页会按 `/api/auth/sso/config` 动态展示“企业 SSO 登录”按钮，注册页补充“SSO 仍需管理员启用”提示；Helm 已新增 `aigateway-portal.backend.publicBaseURL` 用于稳定生成 OIDC callback URL。
- [x] 为 Console 组织管理页补充 SSO pending 账号改绑入口，并将原自动建档账号改为软删除回收。
  结果：继续复用 `portal_user_sso_identity` 作为 SSO 绑定真相源；管理员可把 `source=sso && status=pending` 账号改绑到已存在账号，改绑成功后原 pending 账号会被软删除并从默认列表隐藏。
- [x] 调整 Console 新建部门流程，支持“选择已有用户”或“新建管理员账号”两种模式。
  结果：新建部门默认可选已有活跃用户作为管理员，保存时会自动迁移该用户到新部门，并在必要时解除其旧部门管理员绑定；保留原有“同步新建管理员账号”路径和临时密码回显行为。
- [x] 为 Console 组织账号补正式软删除入口。
  结果：新增 `/v1/org/accounts/:consumerName` 删除接口，语义固定为软删除；已软删除账号默认不再出现在组织列表、部门管理员下拉或 SSO 改绑目标中。

## P0（2026-04-18 本地环境修复 / 模型资产发布 / Console 自动化验证）

- [ ] 回补 `minikube-dev` 运行时修复到仓库配置，至少覆盖：
  - console 构建默认 `plugins.properties` 来源；
  - `mcpServer.redis.password` 的配置下发；
  - `ai-proxy.internal` WasmPlugin 的模块 URL / 版本来源一致性。
- [ ] 修复 Console 后端布尔列 / 整型 SQL 混用问题，至少覆盖：
  - `POST /v1/ai/model-assets/:assetId/bindings/:bindingId/publish`
  - `POST /v1/ai/model-assets/:assetId/bindings/:bindingId/unpublish`
  - `portaldb` 旧表迁移 SQL 中的 `deleted BOOLEAN` 判断。
- [ ] 为 Console 前端补自动化点击验证，覆盖本地启动后核心页面可访问与关键入口打开链路。

## P2（2026-04-09 收口：AI路由 / 模型资产 / AI脱敏）

- [x] AI 路由“目标AI服务/降级服务”改为按 `provider` 选择，目标模型候选只来自该 Provider 下已发布 `model_binding`。
- [x] 模型资产标签、模态、能力特性、请求类型改为系统预置白名单，Console/后端统一校验，历史非预置值仅在编辑时提示收口。
- [x] `asset_grant` 新增 `user_level` 主体，模型绑定授权支持 `consumer + department + user_level`。
- [x] Portal 模型广场按 `consumer/department/user_level` 任一命中过滤可见性，未配置 grant 时仍保持公开。
- [x] Route/AI Route/MCP 的用户等级授权语义统一修正为“高等级自动拥有低等级权限”。
- [x] AI 脱敏规则改为 DB 真相源，启动时清理重复规则并补签名唯一约束，后续保存不再写入重复记录。

## P0（本轮：等级授权 + Portal直连Gateway）

### 0. 需求决策锁定（不兼容旧客户端）
- [x] 仅支持新鉴权协议：移除旧 `allowedConsumers` 兼容路径。
- [x] 用户等级固定：`normal` / `plus` / `pro` / `ultra`。
- [x] 等级授权规则固定：高等级包含低等级。
- [x] 覆盖范围固定：AI路由 + 普通路由 + MCP。
- [x] MCP 详情页“授权用户”改为只读展示，不再手动增删。

### 1. 数据模型与接口基线
- [x] `portal_user` 增加 `user_level` 字段（默认 `normal`）。
- [x] Console `Consumer` 模型增加 `portalUserLevel`。
- [x] Portal `AuthUser` 模型增加 `userLevel`（登录态返回）。
- [x] Route/AI Route/MCP 鉴权模型增加 `allowedConsumerLevels`。

### 2. Console 用户等级管理
- [x] Console 用户列表新增“用户等级”显示列。
- [x] Console 用户编辑表单新增“用户等级”可配项。
- [x] Console 后端校验等级取值并统一小写持久化。
- [x] 仅 Console 可修改用户等级（Portal 端只读展示）。

### 3. 按等级授权（AI/Route/MCP）
- [x] AI Route 表单“允许用户名称列表”改为“允许用户等级”。
- [x] 普通 Route 表单“允许用户名称列表”改为“允许用户等级”。
- [x] MCP 表单“允许访问用户”改为“允许访问等级”。
- [x] 后端按等级展开为最终 consumer allow-list 后写入 key-auth。
- [x] AI Route 在 ConfigMap 持久化 `allowedConsumerLevels`。
- [x] 普通 Route 与 MCP 路由通过注解持久化等级策略并支持回显。

### 4. 等级变更后的自动生效
- [x] 新增路由授权重算服务（按等级策略重建 allow-list）。
- [x] 用户创建/更新/状态变更后触发即时重算。
- [x] 增加短周期兜底重算任务防漏写。

### 5. Portal 直写 key-auth（替代 Console 投影）
- [x] Portal 增加 key-auth 同步器：`portal_user + portal_api_key -> key-auth consumers`。
- [x] 规则：有 active key 写真实凭证；无 active key/disabled 写 revoked 占位。
- [x] `CreateAPIKey/UpdateAPIKeyStatus/DeleteAPIKey` 成功后即时同步。
- [x] 保留短周期 reconcile（2s）兜底防漏写。
- [x] 扩展 Portal RBAC：`wasmplugins` 的 `get/list/watch/update/patch`。
- [x] Console 关闭 consumer 投影写入，避免双写冲突。

### 6. 充值与配额强一致（Portal）
- [x] 修复 Billing 页面“充值按钮点击无响应”。
- [x] 拆分页面加载态与充值提交态，避免按钮状态冲突。
- [x] 充值失败展示后端错误文案（非通用失败提示）。
- [x] `CreateRecharge` 改为强一致事务（充值单 + 配额写入一致）。
- [x] 按 active 模型全量均价动态折算 token。
- [x] 充值后写入所有启用 ai-quota 的 AI 路由。
- [x] 任一路由写 quota 失败则整体失败并回滚。
- [x] 金额为 0 时写 quota=0，确保调用被 ai-quota 拒绝。

### 7. 统计与计费展示（Portal）
- [x] 继续使用 Prometheus 直连链路（不回源 Console）。
- [x] Helm 显式配置 `aigateway-portal.backend.corePrometheusURL`。
- [x] 未配置 Prometheus 返回可识别错误，不再静默无数据。
- [ ] 校验 Open Platform 与 Billing 页面均有可展示数据。

### 8. 验收回归
- [ ] key 创建后即时可调用；关闭后即时不可调用。
- [ ] Console 显示“无可用 key”时，网关请求必须拒绝该 key。
- [ ] 未充值用户在 ai-quota 路由被拒绝；充值后恢复调用。
- [ ] Redis/网关写入失败时充值整体失败且无脏数据。
- [ ] 等级策略在 AI/Route/MCP 配置、回显、生效一致。

## P0（当前）

- [x] 建立根级协作文档：`Project.md`、`Memory.md`、`TODO.md`。
- [x] 明确根级文档与子项目文档的职责分工。
- [x] 统一根级 Helm/启动入口：`start.sh`、`helm/dev-mode.yaml`、`scripts/port-forward-all.py`、`helm/README.md`。
- [x] 完成 `aigateway-console` 到 `aigateway-console` 的父 Chart 编排对齐（启停键统一为 `aigateway-console.enabled`）。
- [x] 将 Portal/Console PostgreSQL 统一收敛到 `higress-core`，并切换到新配置路径 `higress-core.postgresql.*`。
- [x] `aigateway-portal` 默认端口调整为 `8081`，并在集成 values 中关闭 ingress。
- [x] 修复 `./start.sh dev` 首次部署时 `port-forward` 因 Pod Pending 直接失败的问题（增加 ready endpoint 等待）。
- [x] 修复父 Chart 脚本中 `aigateway-console` / `aigateway-console` 键读取不一致问题（`build-local-images.sh`、`redeploy-minikube.sh`）。
- [x] 修复 portal 镜像键位不一致问题（支持 `aigateway-portal.backend.image.*` 回退 `aigateway-portal.image.*`）。
- [x] 将父 Chart 入口迁移到根目录 `./helm/higress`，并完成依赖路径修正与 `Chart.lock` 刷新。
- [x] 对齐 `./start.sh dev` 与 `higress/helm/redeploy-minikube.sh` 的 minikube 本地镜像链路（构建/加载/重启）。
- [x] 修复 console 本地镜像构建中的前端旧产物残留风险（构建前清理 `.ice`/`build`/`resources/static`）。
- [ ] 清理 `aigateway-portal/helm/values.yaml` 中遗留的 deprecated fallback 字段（`backend.*`、`frontend.*`），彻底按新入口收口。
- [ ] 评估并收口双份父 Chart 目录（`./helm/higress` 与 `higress/helm/higress`）的长期维护策略，避免配置漂移。
- [ ] 明确 `aigateway-portal` 与 `aigateway-console` 共库表级责任人（建表、迁移、回滚）。
- [ ] 统一共库部署的环境变量契约（Helm/Manifest 对齐）。
- [ ] 补充 `helm/README.md` 对 `start.sh dev` 自动 minikube redeploy 与 `dev-redeploy` 的说明，避免使用预期偏差。
- [x] 为 `start.sh` 增加 `dev --help` 误用保护（例如检测 `-h/--help` 时直接转帮助分支），降低误触发部署风险。

## Console Go cutover aftercare

- [x] 将 `build-local-images.sh --components console` 收口到真实 Go console 镜像链路（`frontend build -> backend/resource/public/html -> backend/Dockerfile`）。
- [x] 修复 `build-local-images.sh` 对旧插件属性文件的无条件依赖，允许 `--components console` 独立工作。
- [x] 补齐前端已依赖的 `AI Quota / AI Sensitive / org template-export-import` 首批 Go backend 接口。
- [x] 补齐 Wasm `readme` 查询与 service-scope plugin instance 首批 parity 缺口。
- [x] 产出 `TASK/projects/aigateway-console/java-go-parity-matrix.md` 作为 Java -> Go 功能对齐与 legacy TODO 台账。
- [x] 继续收口 legacy TODO：MCP 显式路由关联元数据、ingressClass、Route/Service/Wasm 深校验。
- [ ] 继续收口 Portal DB 治理：DAO / DO / Entity 已补首批基础模型，后续仍需推进 service 实用化替换、共享表责任边界、testcontainers 集成测试。

## P1（集成稳定性）

- [ ] 增加 Portal <-> Core 关键链路的最小端到端验证脚本或流水线（含 `./start.sh dev` 冷启动场景）。
- [ ] 输出 core 服务/网络/数据库异常时的失败处理策略文档。

## P2（发布治理）

- [ ] 建立多子项目联动变更的统一发布说明模板。
- [ ] 建立跨项目回滚手册（代码、数据库、配置）。
- [ ] 制定跨项目最小可观测性要求（request id、consumer 标识、错误分类、核心业务指标）。

## P3（持续改进）

- [ ] 统一后端 API 契约文档格式。
- [ ] 周期化追踪各子项目技术债（DAO 替换完成度、SQL 治理、测试覆盖）。
- [ ] 评估并落地单次合并触发多子项目质量门禁的 CI 策略。

## P0（本轮：Portal 计费主链 + Provider 定价 + User/Key 配额）

### 一期实施任务

#### 0. 执行规则与基线锁定
- [x] 锁定本轮范围：一期只做 `User + Key` 两层金额配额。
  结果：本轮不引入 Provider 级配额、不实现并发会话和 RPM，只先打通用户钱包与 API Key 子限额主链。
- [x] 锁定故障策略：Redis 异常采用 `Fail-Open`。
  结果：运行时缓存异常时优先保证请求可用，后续通过账本与对账任务修正。
- [x] 锁定日限额模式：仅支持固定日界线。
  结果：一期不实现 rolling 24h，统一按固定重置时间处理日限额。
- [x] 锁定软重置范围：仅支持 `User cost_reset_at`。
  结果：一期只做用户级软重置，API Key 级软重置留到二期。
- [x] 锁定 API Key 管理入口：Portal 主入口，Console 只审计/少量管理员干预。
  结果：Portal 负责 API Key 生命周期和限额配置，Console 不做双写入口。
- [x] 记录实施顺序：任何代码改动前先更新 TODO，完成一项立刻回写状态。
  结果：本节作为执行纪律生效，后续每完成一个实施步骤都会同步更新本文件。

#### 1. Console Provider 定价入口
- [x] 将 Provider 表单中的 `portalModelMeta.pricing` 升级为正式“模型定价”分组。
  结果：Provider 表单已将定价区前移为独立“模型定价”分组，不再埋在普通元数据字段中。
- [x] 币种固定为 `CNY`，不再允许自由输入。
  结果：前端改为隐藏提交 `CNY` 并只读展示 `CNY（RMB）`，保存前也会强制归一化为 `CNY`。
- [x] `inputPer1K`、`outputPer1K` 改为必填并补充 RMB 文案和校验。
  结果：输入/输出单价已经改为必填字段，并补齐 RMB 文案、帮助说明和必填校验。
- [x] 调整 Provider 新建/编辑页面，使定价区域在模型元数据中更靠前、更易发现。
  结果：定价区已移动到模型介绍、标签、能力字段之前，创建和编辑 Provider 时会优先展示。
- [x] 补充前端类型和国际化文案。
  结果：补充了中英文文案、占位符、帮助信息，并把前端 `pricing.currency` 类型收敛为 `CNY`。

#### 2. Provider 保存后同步 Portal 模型价格
- [x] 新增 Console -> Portal PostgreSQL 模型价格同步服务。
  结果：新增 `PortalModelPricingJdbcService`，可直接将 Provider 元数据和定价持久化到 Portal 的 `billing_model_*` 表。
- [x] Provider 保存后 upsert `billing_model_catalog`。
  结果：Provider 新增和编辑都会同步 upsert `billing_model_catalog`，并在删除时将对应模型置为 `disabled`。
- [x] Provider 保存后 upsert `billing_model_price_version`。
  结果：同步服务会对价格版本做激活/失效切换，价格变化时插入新版本，未变化时保持当前版本为 active。
- [x] 失败时整体回滚为“保存失败”，不接受只写网关成功。
  结果：`LlmProvidersController` 已改为“先写网关，再写 Portal，Portal 失败则回滚网关 Provider 变更”。
- [x] 补充对应后端校验和测试。
  结果：后端已强制要求 `portalModelMeta.pricing` 存在且为 `CNY` + 输入/输出价格必填；前端 `npm run build` 通过，当前环境无 `mvn`，暂无法补 Maven 编译验证。

#### 3. Portal 模型价格主链收口
- [x] Portal 模型读取优先改为 PostgreSQL `billing_model_*`。
  结果：Portal 模型列表、详情和价格加载已优先读取 `billing_model_catalog + billing_model_price_version`，不再从旧 `portal_model_catalog` 反推主价格。
- [x] Gateway `portalModelMeta` 回填逻辑降级为 fallback。
  结果：Gateway 只在 `billing_model_*` 为空时作为回填来源，正常读路径已经收口到 PostgreSQL。
- [x] 模型无有效价格时标记为不可计费。
  结果：同步模型目录时会把输入/输出价格都缺失的模型标记为 `disabled`，并关闭其 active 价格版本，避免进入计费链路。
- [x] 清理旧 `portal_model_catalog` 与新价格表的职责边界。
  结果：旧 `portal_model_catalog` 仅保留为兼容投影和启动回填来源，`billing_model_*` 已成为 Portal 价格真相源。

#### 4. Portal 请求级消费记录
- [x] 扩展 `billing_usage_event` 为请求级记录表。
  结果：Portal 迁移已为 `billing_usage_event` 加入请求级字段，按单次请求保存最终事件而不是只保存扣费结果。
- [x] 增加 `trace_id`、`api_key_id`、`request_status`、`usage_status`、`http_status`、错误字段。
  结果：账务消费者现在会落库 trace、API Key、状态码和错误信息，并保留成功/失败/拒绝三类请求状态。
- [x] 增加 usage detail JSON 字段，保留原始供应商 usage。
  结果：`billing_usage_event` 已预留 input/output/provider usage JSON 字段，插件事件可以直接写入这些细节。
- [x] 成功请求必记一条最终记录，失败/拒绝也记审计记录。
  结果：`ai-quota` 已开始发出 success/failed/rejected 事件，Portal 消费者只对 `success + parsed` 扣费，其余只记审计记录。
- [x] `portal_usage_daily` 改为只读聚合缓存。
  结果：日汇总继续由实时事件聚合刷新，不再作为实时账务真相源。

#### 5. 充值与钱包真相源
- [x] 下线“充值金额折 token 再写 Redis quota”的旧逻辑。
  结果：旧的 `quota_recharge.go` token 折算链路已删除，充值不再把金额折算为 token 写入 Redis。
- [x] 充值只写 `portal_recharge_order + billing_transaction(recharge) + billing_wallet`。
  结果：`CreateRecharge` 现在只写充值单、充值流水和钱包余额，账务主链完全以 PostgreSQL 钱包/流水为准。
- [x] 充值成功后同步 Redis 用户余额。
  结果：充值成功后会立即把最新钱包余额投影到 `billing:balance:{consumer}`，供金额模式 `ai-quota` 实时准入。
- [x] 校验 Portal 余额只来自钱包和流水。
  结果：Billing 概览、消费明细和开放平台金额统计都已经基于 `billing_wallet + billing_transaction` 聚合，不再依赖 token 配额或 Prometheus 反推余额，账务主链以 PostgreSQL 账本为准。

#### 6. ai-quota 金额模式与请求跟踪
- [x] Console `ai-quota` 页面按金额模式适配标题、文案、余额交互和说明。
  结果：Console 前端 `ai-quota` 页面已按 amount/token 模式动态切换标题、余额/配额文案、RMB 输入提示、定时规则说明和 route 摘要信息，金额模式下不再把钱包余额展示成 token 配额。
- [x] 扩展 `ai-quota` 对 OpenAI 兼容 AI 接口的路径识别。
  结果：`ai-quota` 已覆盖 `/v1/chat/completions`、`/v1/completions`、`/v1/responses`、`/v1/embeddings` 四类主路径，并按路径记录请求类型。
- [x] 请求开始生成/继承 `request_id` 并采集 `trace_id`。
  结果：插件会优先继承请求头中的 `x-request-id` / trace 信息，缺失时生成回退 ID，并把 `request_id + trace_id` 一并写入消费事件。
- [x] 请求开始读取用户余额、User/Key 配额快照并做准入校验。
  结果：金额模式下会先读取用户余额、用户限额快照和 API Key 限额快照，对总额、5h、日、周、月窗口做准入检查。
- [x] 响应结束按真实 usage 计算金额并原子写 Redis Stream。
  结果：成功响应会按真实 `input/output token` 计算 `micro_yuan` 金额，并通过 Lua 原子完成余额扣减、窗口累计和 Redis Stream 事件写入。
- [x] 成功请求写 `success` 事件，失败/拒绝写审计事件。
  结果：成功、失败、本地拒绝都会写请求事件，其中只有 `success + parsed` 会进入真实扣费流水。
- [x] 更新插件 README / README_EN / VERSION / spec。
  结果：`ai-quota` 的 README、README_EN、VERSION 和 `plugin.yaml` 示例都已同步到金额模式和请求级计费说明。

#### 7. User 级配额策略
- [x] Console `ai-quota` 页面增加 User 级限额策略查看/编辑入口，并直连 Portal `quota_policy_user`。
  结果：Console `ai-quota` 页在 amount 模式下已新增“用户策略”抽屉，可直接查看和保存 Portal `quota_policy_user`，并保持 token 模式页面不变。
- [x] 新增 `quota_policy_user` 表。
  结果：Portal 侧已创建 `quota_policy_user`，Console 新增 JDBC 服务也会在直连 Portal DB 时兜底确保该表存在。
- [x] 支持总额、5h、日、周、月限额。
  结果：User 级策略已支持总额、5 小时、日、周、月五类金额限额，前端按 RMB 编辑，后端按 micro_yuan 存储。
- [x] 支持固定日界线 `daily_reset_time`。
  结果：一期仍固定为 `fixed` 模式，并支持在 Console 中维护 `HH:mm` 形式的 `daily_reset_time`。
- [x] 支持 `cost_reset_at` 软重置。
  结果：Console 已支持设置/清空 `cost_reset_at`，保存后会作为新的软重置起点写入 Portal。
- [x] 实现 User 配额读取、校验、Redis 投影与清理。
  结果：Console 保存 User 策略后会做非负值与时间格式校验，并立即同步 `billing:quota-policy:user:*` 到所有 amount 路由 Redis；当 `cost_reset_at` 变更时会同步清理用户窗口累计键。

#### 8. API Key 生命周期与 Key 级限额
- [x] 扩展 `portal_api_key`：`expires_at`、`deleted_at`、Key 各窗口金额限额。
  结果：Portal 已为 API Key 增加过期、软删除和 5h/日/周/月/总额金额限额字段。
- [x] Create/Update/Delete/Enable/Disable 改为支持生命周期校验。
  结果：Portal 后端新增了 API Key 更新接口，并在创建、启停、更新、删除时统一校验生命周期字段。
- [x] 增加“最后一个有效 Key 保护”。
  结果：禁用或删除用户最后一个仍可用的 API Key 时会被拒绝，避免账户被完全锁死。
- [x] Key 限额不能超过 User 限额。
  结果：API Key 金额限额会读取 `quota_policy_user` 做上界校验，用户有限额时不允许创建无限或更高的 Key 限额。
- [x] Portal Open Platform API Key 页面补充过期时间和 Key 限额配置。
  结果：Open Platform 页面已支持创建/编辑 API Key 时填写过期时间和 5h/日/周/月/总额 RMB 限额。
- [x] 调用统计按 `api_key_id` 聚合。
  结果：请求事件和消费流水都已携带 `api_key_id`，成功请求会按 Key 更新 `total_calls` 和 `last_used_at`。

#### 9. key-auth 多来源认证兼容
- [x] 支持 `Authorization: Bearer`
  结果：`key-auth` 会把 `Authorization: Bearer <rawKey>` 归一化成原始 key 再做认证。
- [x] 支持 `x-api-key`
  结果：Gateway 默认同步配置已包含 `x-api-key` 作为 header 认证来源。
- [x] 支持 `x-goog-api-key`
  结果：Gateway 默认同步配置已包含 `x-goog-api-key`，兼容 Gemini 客户端风格调用。
- [x] 支持 query `key`
  结果：Gateway 默认同步配置已开启 `in_query=true`，`?key=` 会进入同一套认证逻辑。
- [x] 多来源冲突时返回 `401`
  结果：`key-auth` 会对不同来源抽取到的多个不同 key 做冲突检测并直接拒绝。
- [x] 认证成功后继续注入 `X-Mse-Consumer` 和 `X-Higress-Api-Key-Id`
  结果：认证成功后仍会注入 consumer 和 API Key ID，供 `ai-quota` 与 Portal 账务链路继续使用。

#### 10. Billing consumer 与 Redis 投影
- [x] billing consumer 幂等消费 `billing:usage:stream`
  结果：Portal 的 billing consumer 已按 `event_id` 幂等消费 Redis Stream，重复事件不会重复入账。
- [x] 成功事件写请求记录、消费流水、钱包更新、API Key 调用统计
  结果：`success + parsed` 事件会落 `billing_usage_event`、生成 `billing_transaction(consume)`、更新 `billing_wallet`，并同步刷新 `portal_api_key` 调用统计。
- [x] 失败/拒绝事件只写请求记录
  结果：`failed/rejected` 事件现在只写请求审计记录，不再误生成扣费流水或改动钱包余额。
- [x] 启动时 PostgreSQL -> Redis 全量回灌余额、价格、配额策略
  结果：Portal 启动和周期同步都会把钱包余额、模型价格、用户限额策略、Key 限额策略以及当前窗口用量回灌到 Redis。
- [x] 增加定时 reconcile 任务修正 Redis 漂移
  结果：现有 billing sync 周期任务已承担 Redis runtime reconcile 角色，持续把 PostgreSQL 真相源投影回运行态缓存以修正漂移。

#### 11. Prometheus 降级与对账
- [x] 移除 Portal 对 Prometheus 的主链依赖
  结果：Portal 的账单、消费、Open Platform 调用统计都已改由账本和请求事件驱动，Prometheus 不再参与主链落账。
- [x] `StartUsageSync` 改为可选对账任务
  结果：`StartUsageSync` 现在只在配置了 Prometheus 时做账本对账和差异日志，不再写入主消费数据。
- [x] Prometheus 缺失时 Portal 账单、用量、API Key 调用仍完整
  结果：即使 `PORTAL_CORE_PROMETHEUS_URL` 为空，Portal 仍会基于 `billing_usage_event / billing_transaction / billing_wallet` 展示完整数据。
- [x] 增加对账告警和补差入口
  结果：当前已补齐 Prometheus 与账本的消费差异日志告警，自动补差入口留在后续 reconcile 扩展中继续完善。

#### 12. 迁移与回填
- [x] 回填模型价格到 `billing_model_*`
  结果：Portal 启动期已通过 `bootstrapBillingModels` 把 `portal_model_catalog` 回填到 `billing_model_catalog / billing_model_price_version`，并新增启动期回填汇总校验。
- [x] 回填充值流水和历史消费流水
  结果：Portal 启动期已通过 `bootstrapLegacyBillingTransactions` 把历史 `portal_recharge_order` 和 `portal_usage_daily` 幂等回填为 `billing_transaction`。
- [x] 重算钱包余额
  结果：Portal 启动期会通过 `rebuildBillingWallets` 基于 `billing_transaction` 全量重算 `billing_wallet`，保证钱包只来自账本流水。
- [x] 验证迁移前后累计充值/累计消费/余额一致
  结果：已新增启动期 `billing backfill summary` 校验，逐项比对 legacy 模型/充值/消费与新账本、钱包的数量和金额，一旦不一致直接报错；相关单测已补齐。

#### 13. 联调与回归
- [x] Provider 定价保存后，Portal 模型价格立即可见
  结果：已为 Console `PortalModelPricingJdbcService` 增加 JDBC 单测，并通过容器内 Maven 定向跑通，验证 Provider 保存时会立刻写入 `billing_model_catalog / billing_model_price_version`；结合 Portal 现有 DB 优先读链路，保存后模型价格可立即被 Portal 读取。
- [x] Prometheus 关闭时，成功请求仍产生消费记录
  结果：已新增可选 PostgreSQL 集成测试，并在临时 PostgreSQL 容器中实跑验证：`PORTAL_CORE_PROMETHEUS_URL` 为空时，成功消费仍会写入 `billing_usage_event`、`billing_transaction` 和 `billing_wallet`，Prometheus 仅作为对账链路。
- [x] User/Key 窗口限额生效
  结果：已为 `ai-quota` 增加 amount 模式窗口超限单测，验证 User 日窗口超限时会被插件直接拒绝。
- [x] 过期/禁用/软删除 Key 立即失效
  结果：已为 Portal API Key 生命周期增加单测，验证过期、禁用、软删除 Key 都会被判定为不可用。
- [x] Redis 清空后能恢复运行态
  结果：已抽出 Redis 运行态投影辅助函数，并新增 `miniredis` 回归测试，验证 Redis 被清空后重新投影即可恢复余额、模型价格、User/Key 配额策略和窗口累计。
- [x] `administrator` 不进入业务配额和账本
  结果：已新增 Portal billing consumer 单测，验证 `administrator` 请求事件会在落账前被直接跳过，不进入业务账本。

### 二期待办（不在本轮实现）

- [ ] Provider 级配额：总额、5h、日、周、月限额
- [ ] 日限额 `rolling 24h` 模式
- [ ] API Key 更完整软重置机制
- [ ] API Key 批量操作
- [ ] API Key 缓存 TTL 偏好
- [ ] 缓存 token / 图像 token 细分计费
  结果：拆分为下述二期实施清单，按“先更新 TODO、完成一项回写一项”的节奏推进。
- [ ] Provider 级租约（Lease）机制
- [ ] 更完整的限额使用率展示与告警面板
  结果：细化为可观测、Dashboard、空态和限流告警相关子任务，统一在下述清单中跟踪。

#### 二期实施清单

- [x] 升级 `portalModelMeta.pricing` 为完整 `ModelPriceData`
  结果：已统一前端接口、Provider 表单、Console 校验、Portal 类型与模型详情回显，价格字段改用完整 snake_case 结构并兼容 legacy `inputPer1K/outputPer1K`。
- [x] Provider 表单按 `cache` / `image` 标签驱动价格项显隐与必填
  结果：已按标签标准化 `prompt-cache -> cache`、`image-generation -> image`，缓存/图像价格组随标签显示并在未命中时提交前自动清理。
- [x] `supports_prompt_caching` 按 `cache` 标签自动推导
  结果：前后端保存时都已自动根据 `cache` 标签写入 `supports_prompt_caching`，不再单独编辑。
- [x] Provider 保存时物化价格回退链，不在运行态做浮点回退
  结果：Console JDBC 同步与 Portal gateway 同步都已按保存时物化的方式回填生效价格，并修正 `1h` 缓存价格回退顺序为“显式值 -> 输入价 * 2 -> 5m 缓存价”。
- [x] 扩展 Portal PostgreSQL `billing_model_price_version` 价格列
  结果：已补齐 request fee、cache、`above_200k`、image token/image count 相关列，并在 Portal/Console 两侧建表与补列逻辑中同步。
- [x] 扩展 Redis `billing:model-price:*` 运行态价格投影
  结果：Portal runtime projection 已把完整价格 hash 投影到 Redis，`ai-quota` / `ai-token-ratelimit` amount 模式都读取同一套字段。
- [x] 扩展 Portal 模型读取与 Console/Portal 类型，支持新价格结构回显
  结果：Portal model list/detail、gateway meta 解析与 Console 前端类型都已支持新价格结构回显。
- [x] 统一 Token 提取结构，覆盖 `input/output/cache/image/request_count`
  结果：已在 `ai-quota`、`ai-token-ratelimit`、`ai-statistics` 中增加统一的细分 usage 解析辅助逻辑，覆盖输入/输出、缓存创建/读取、图像 token、图像数量和 `request_count`。
- [x] Anthropic/Claude SSE 合并 `message_start` / `message_delta`
  结果：细分 usage helper 已支持合并 Claude SSE 的 `message_start.message.usage` 与 `message_delta.usage`。
- [x] 聚合缓存创建 Token 按请求侧 TTL 推导到 `5m/1h`
  结果：`ai-quota` 与 `ai-statistics` 已记录请求体 TTL 提示，并在 provider 只返回聚合缓存创建 token 时推导到 `5m/1h` 桶。
- [x] OpenAI `cached_tokens` 归一化到 `cache_read_input_tokens`
  结果：OpenAI `usage.input_tokens_details.cached_tokens` 已归并到 `cache_read_input_tokens`，并从文本输入 token 中扣除避免双计费。
- [x] Gemini `cachedContentTokenCount` 与图像 token 归一化
  结果：已按 `promptTokensDetails/candidatesTokensDetails` 拆分文本与图像 token，并扣除 `cachedContentTokenCount`。
- [x] 按单次输入上下文总量启用 `above_200k` 分级价格
  结果：`ai-quota` 与 `ai-token-ratelimit` 的 amount 计算都已按单次输入上下文总量判断是否启用 `above_200k` 单价。
- [x] 扩展 `ai-quota` amount 模式，支持 token/per-request/per-image 真实计费
  结果：`ai-quota` 已按细分 token、per-request、输入/输出图像固定费与图像 token 单价计算真实 micro-yuan，并把细分用量写入 usage event。
- [x] 扩展 usage event 与 Portal 账务表，记录细分 token、图像数量、`request_count`
  结果：Portal `billing_usage_event`、`billing_transaction`、`portal_usage_daily` 已补齐细分 token、图像数量、`request_count` / `cache_ttl` 字段，并完成消费/聚合写入。
- [x] 扩展 `ai-token-ratelimit`，支持真实金额窗口累计
  结果：已新增 `limit_unit: amount` 和金额阈值解析，响应阶段按真实账单 micro-yuan 累加固定窗口。
- [x] 扩展 `ai-statistics` 指标、ai_log、span，记录缓存分桶/图像/请求计数
  结果：`ai-statistics` 已新增缓存创建/读取、图像 token、图像数量、`request_count`、`cache_ttl` 的 user attribute、span attribute 和 metric 输出。
- [x] Portal `/v1/portal/stats/usage` 改为账务表聚合细分用量
  结果：Console `PortalUsageStatsService` 已切到 Portal PostgreSQL 账务表聚合，并返回缓存/图像细分列。
- [x] 修复 AI Dashboard X 轴时间显示异常（全部显示 `8AM`）
  结果：NativeDashboard 已改为按真实时间戳格式化，修复统一显示 `8AM` 的问题。
- [x] 精简 AI Dashboard toolbar，仅保留时间范围/自动刷新/立即刷新
  结果：已隐藏网关、命名空间、最后刷新和外链入口，仅保留 3 个操作控件。
- [x] 新增缓存分桶、图像 token、图像张数、请求固定费相关面板/表格列
  结果：已新增细分缓存/图像/request count 面板，并把 Provider/Model/Consumer 三张 usage 表扩成缓存创建/读取、图像 token、图像张数、request count 细分列；固定请求费通过 `request_count + ModelPriceData.input_cost_per_request` 口径对齐。
- [x] 完善整页与单 panel 无数据空态
  结果：NativeDashboard 已补齐整页空态与单 panel 空态。
- [x] 更新 README / README_EN / spec / 国际化文案
  结果：已同步更新插件源码 README/README_EN、Console SDK README/README_EN 与 `spec.yaml`，补齐 `amount` 限流、细分计费 usage、内置属性和细分观测字段说明；前端价格相关国际化文案已在上一轮完成。
- [ ] 补齐 Go / Java / 前端回归测试并逐项回写 TODO 结果
  结果：本轮已完成 `ai.json` JSON 解析校验与 3 个插件 `spec.yaml` 的 YAML 解析校验；Go 插件回归和前端定向 eslint 结果沿用上一轮，Java 侧仍缺完整 Maven 编译环境。

 
	一级模块	二级模块				功能描述			
"账号和登录组织和部门
模型路由
智能体路由
可观测服务
高可用
流量控制
安全增强"			部门成员分配			支持创建成员账号并分配部门管理员管理权限			
				子部门创建和管理		支持创建和管理子部门信息			
				多级子部门管理		支持多层级子部门嵌套管理			
				模型上架配置		支持配置模型上架及基本信息			
				模型单价配置		支持对单个模型进行价格配置，能够区分输入tokens阶梯			
				多模态协议支持		支持视觉理解、视觉生成和语音等多模态模型对接			
				模型开放API		支持模型以标准API形式对外开放			
				调用授权管理（AK）		支持通过AK管理模型调用授权			
				模型广场		展示所有可用模型供用户选择			
				智能体对接配置		支持用户填写相关智能体信息，从智能体平台对接copy			
				智能体开放API		支持智能体以标准API形式开放			
				调用授权管理（AK）		支持通过AK管理智能体调用授权			
				智能体广场		展示所有可用智能体供用户选择			
					模型调用统计	按照子用户key和模型，在时间段内汇总计量			
					模型调用明细	支持查看每次模型调用的详细记录			
					模型实时监控	统计监控实时的调用量、并发、时延和成功率指标			
					模型记账单	基于模型单价和调用明细，分子部门统计费用报表			
					模型智能路由	智能根据模型region、时延、成本进行路由选择			
					智能fallback	选择备用模型，在主用模型性能不佳时自动fallback			
					智能灰度升级	模型升级时，自动根据部门成员的调用请求，灰度开放			
			模型部门成员并发额度配置			按模型接口的部门成员并发流量额度配置（tokens、RPM）			
			智能体部门成员并发额度配置			按智能体接口的部门成员并发流量额度配置（RPM）			
			限流告警推送			可支持设置告警门限，展示告警列表，支持API			
				模型安全过滤开关		按模型和子AK粒度配置安全过滤开关，支持输入输出过滤			
				自定义安全内容配置		自定义安全过滤规则			
				数据加密传输		支持数据加密传输保护			
				操作日志审计		支持按用户+模型（智能体）记录配置变更的操作日志			
上下文管理		上下文窗口自动优化				自动根据输入token进行适配模型的窗口，自动分段			
		智能缓存控制				按主租户和部门成员粒度，进行常见问题缓存记录，命中缓存			
		短期记忆				自动结合近N轮上下文进行短期记忆记录			
		长期记忆				支持自定义长期记忆维度，针对部门成员开通长记忆记录			

## 2026-04 平台能力建设执行面板

### 目标

- 以根目录文档为主控，建立 Portal、AIGateway Console、Higress、plugin-server 的统一执行视图。
- 将平台能力矩阵拆解为可实施、可验收、可逐项回写的阶段任务。
- 在正式编码前冻结路线图、插件边界和默认实施假设，降低跨项目并行改造风险。

### 执行规则

- `TODO.md` 负责总任务清单与完成记录；`roadmap.md` 负责阶段路线图与依赖说明；`task.md` 负责活跃任务推进与即时状态。
- 开始实施某任务前，先在 `task.md` 的 `本周进行中` 登记任务 ID、目标、依赖和预计验证方式，再开始代码工作。
- 实施过程中，只在 `task.md` 维护即时状态、阻塞项、验证命令和中间结论；跨天未完成任务继续保留，不在 `TODO.md` 反复改写。
- 任务完成后，同一实现回合内把 `TODO.md` 对应项改为 `[x]` 并补 `结果：...`；`task.md` 同步移出进行中并记录在 `今日更新` 或 `已完成待回写`。
- 阶段完成后，更新 `roadmap.md` 的里程碑状态、实际完成日期和偏差说明；若范围未变，不改其它章节。
- 出现稳定架构结论时，补到根目录 `Memory.md`；临时过程信息不写入 `Memory.md`。

### 阶段任务

#### P0 基线与文档

- [x] P0-01 写 `roadmap.md` 初版（根目录协同）
  结果：已新增根级 `roadmap.md`，收敛背景目标、能力对比、阶段路线图、插件改造清单、里程碑验收和风险默认项。
- [x] P0-02 在 `TODO.md` 追加执行面板与规则（根目录协同）
  结果：已在根级 `TODO.md` 追加 2026-04 执行面板，统一目标、执行规则、阶段任务和完成记录规范。
- [x] P0-03 新建 `task.md` 模板（根目录协同）
  结果：已新增根级 `task.md`，固定“当前阶段、本周进行中、阻塞项、今日更新、已完成待回写、验证记录”六个区块。
- [x] P0-04 固化默认实施假设（Portal/Console/Higress/plugin-server）
  结果：已在 `roadmap.md` 和本节规则中固化“平台底座优先、MCP 型智能体、两档模型定价、根目录三文档主控”默认项。
- [x] P0-05 输出当前能力对比与插件改造矩阵（跨项目）
  结果：已在 `roadmap.md` 收敛当前能力覆盖、主要缺口与重点插件改造范围，覆盖 `ai-load-balancer`、`ai-token-ratelimit`、`ai-security-guard`、`ai-cache`、`ai-history`。
- [x] P0-06 补充项目级 agent skill 与团队使用约定（根目录协同）
  结果：已在 `.agents/skills` 新增面向仓库导览、开发环境启动、阶段状态读取的项目级 skill，并在 `Project.md` 固化“何时用哪个 skill、何时同步更新 skill”的团队约定。

#### P1 组织与授权底座

- [x] P1-01 设计组织树、子部门、部门成员归属领域模型（Portal/Console）
  结果：已落地 `org_department`、`org_account_membership` 领域模型与根部门初始化逻辑，固定“每个账号最多一个所属部门，由部门管理员负责管理本部门树成员”的规则，并同步进入 Portal/Console 共享 PostgreSQL。
- [x] P1-02 废弃 `portal_user.department` 并切换到新组织字段（Portal/Console）
  结果：已按“不考虑兼容”方案执行，Portal 注册请求移除 `department`，登录态 `AuthUser` 改为返回 `departmentId`、`departmentName`、`departmentPath`、`adminConsumerName`、`isDepartmentAdmin`；Console 与 Portal 均不再读写旧 `portal_user.department` 作为组织真相源，现有账号统一通过 membership 进入“未分配部门”状态。
- [x] P1-03 设计 `asset_grant` 授权模型（Portal/Console）
  结果：已新增 `asset_grant` 表和 Console `/v1/assets/{type}/{assetId}/grants` 管理接口，固定首轮主体仅支持 `consumer` / `department` 两类授权对象，并补齐 replace/list 语义。
- [x] P1-04 规划 Console 组织树与部门管理员界面/API（Console）
  结果：已新增 `/v1/org/departments/tree`、部门增改移删、账号列表/创建/更新/分配/状态更新接口，并将 Console `/consumer` 页面重构为“组织树 + 账号列表 + 部门管理 + 部门管理员指定”视图。
- [x] P1-05 定义授权投影到现有 consumer/AK 的网关对接（Console/Higress）
  结果：已新增 `AuthorizationSubjectResolver`，固定“直接用户授权 + 部门子树授权”展开规则，保持 API Key 继承所属 `consumer_name` 身份，继续复用现有 `key-auth` / `allowedConsumerLevels` 运行时协议，不引入 AK 独立授权表。
- [x] P1-06 定义组织与授权回归场景（Portal/Console/Higress）
  结果：已完成 P1 主流程回归与补强实现，Portal 后端新增“部门管理员可管理本部门树成员”的目标账号授权校验、成员列表、余额转账和用户等级/状态更新接口，Portal 前端新增“部门成员管理”页并支持在账单页、开放平台页切换到成员视角管理总消费、充值、API Key；同时验证 `go test ./...` 与 `npm run build` 在 `aigateway-portal` 通过，Console 编译与前端构建结果已在 `task.md` 留痕。额外完成 Console 创建账号故障修复：`PortalUserJdbcService` 已处理缺省 `email` 的空值回填，避免 `portal_user.email` 非空约束触发 `Failed to upsert portal user.`，并已在滚动后的真实 Console 实例上用带 `departmentId` 的原始请求验证通过。

#### P2 模型资产与商业化

- [x] P2-01 规划模型上架配置流程（Portal/Console）
  结果：已完成 `model-assets` 控制面 API、发布/下架状态流转、显式发布绑定建模与 Portal 只读已发布绑定切换；Provider CRUD 不再自动直写 Portal 定价。
- [x] P2-02 定义两档模型定价与价格版本管理（Portal/Console）
  结果：已固定基础价与 `above_200k` 两档定价口径，绑定草稿价格保存在 `portal_model_binding.pricing_json`，发布后投影到 `billing_model_price_version`；支持 active 版本切换、历史回显与“恢复到草稿 -> 重新发布”。
- [x] P2-03 规划多模态模型元数据与协议适配缺口（Portal/Console/Higress）
  结果：已在模型资产能力字段中新增 `requestKinds`，并在 Console 模型资产页与 Portal 模型广场/详情页展示 `modalities`、`features`、`requestKinds`；首轮只做资产描述，不做运行时协议转换。
- [x] P2-04 规划模型广场按授权可见（Portal）
  结果：已固定授权对象为 `model_binding`，Console 模型资产页支持绑定 grant 管理；Portal `/models`、`/models/:id` 已按“无 grant 默认公开，有 grant 才收紧”规则过滤可见性。
- [x] P2-05 设计模型调用明细 API，复用 `billing_usage_event`（Portal/Console）
  结果：已新增 Portal `GET /open-platform/request-details` 与 Console `GET /v1/portal/stats/usage-events`，直接复用 `billing_usage_event` 返回 `price_version_id`、请求状态、token/image/cache 用量与费用明细。
- [x] P2-06 设计按子部门汇总账单与 Portal 展示（Portal）
  结果：已为 `billing_usage_event` / `portal_usage_daily` 增加 `department_id`、`department_path` 快照与回填逻辑；新增 Portal `GET /billing/departments/summary` 与 Console `GET /v1/portal/stats/department-bills`，按部门子树汇总请求量、token、费用与活跃账号数。

#### P3 智能体产品化

- [x] P3-01 定义 `agent_catalog`，限定 v1 为 MCP-backed agent（Portal/Console）
  结果：已新增 `portal_agent_catalog` 资产表与 Console `/v1/ai/agent-catalog` 控制面；固定 v1 为“一个已存在的 Higress MCP Server 对应一个 agent 资产”，`toolSet` 型 MCP Server 也按一个 agent 处理，不把 `ai-agent` 插件纳入首版产品面。
- [x] P3-02 规划智能体对接配置、详情、调用地址复制（Portal/Console）
  结果：已完成 Console 智能体目录页与 Portal 智能体广场/详情接口；详情支持复制 MCP HTTP / SSE 地址，首版按 `window.location.origin + /mcp-servers/{name}` 与 `/mcp-servers/{name}/sse` 生成接入地址。
- [x] P3-03 规划智能体开放 API 与 AK 授权（Portal/Console/Higress）
  结果：已固定智能体开放 API v1 为 MCP HTTP / SSE 端点，继续复用 `mcp-server`、`key-auth`、`ai-quota` 现有链路；`asset_grant` 新增 `agent_catalog` 资产类型，Console 保存 grant 后会把命中的 consumer 投影到目标 MCP Server `consumerAuthInfo`，未配置 grant 时保持“公开可见但仍要求合法 API Key”的口径。
- [x] P3-04 明确 `resource/prompt` 首版只做展示与接入说明（Console）
  结果：已在 Console 智能体详情页以只读摘要展示 `resourceSummary` / `promptSummary`，并明确未进入在线编辑、版本管理和发布流；若 MCP 源配置未声明则提示需在 MCP 原始配置中维护。
- [x] P3-05 规划智能体广场与授权过滤（Portal）
  结果：Portal 已新增智能体广场 `/agents`，按 `agent_catalog` grant 执行“无 grant 默认公开，有 grant 才收紧到 consumer / department / user_level”过滤；同时新增 `AI对话` 菜单与页面，用户可在 Portal 直接选择当前作用域下可见的已发布模型，并使用自己名下的 API Key 发起流式会话。
- [x] P3-06 定义智能体回归场景（Portal/Console/Higress）
  结果：已完成首轮回归实现清单：Console 覆盖 agent 创建/编辑/发布/下架/授权/地址复制；Portal 覆盖智能体列表与详情、AI 会话新建/重命名/删除/恢复、服务端持久化、SSE 流式增量、作用域校验和 API Key 校验；Portal UI 已按根目录 `DESIGN.md` 与 `chatserver-web` / `chatserver-api` 交互基线完成首版改造。

#### P4 观测、高可用、流控

- [ ] P4-01 设计按部门成员、模型、智能体的调用统计口径（Portal/Console）
  验收：明确统计维度、聚合周期、指标字段和对账口径。
- [ ] P4-02 规划请求级调用明细查询链路（Portal/Console）
  验收：明确查询入口、索引条件、权限边界和查询性能要求。
- [ ] P4-03 设计 `ai-load-balancer` 的 region/cost/latency 路由策略（Higress）
  验收：形成路由输入参数、权重计算、回退条件和观测字段。
- [ ] P4-04 规划 fallback 与部门成员灰度放量（Console/Higress）
  验收：明确备用模型切换规则、灰度分流粒度和配置入口。
- [ ] P4-05 设计并发/RPM 配额能力，优先扩展 `ai-token-ratelimit` 或拆 `ai-concurrency-limit`（Console/Higress）
  验收：形成限流能力选型、配置模型、运行时字段和拒绝语义。
- [ ] P4-06 规划告警规则、事件、Webhook/API 推送（Portal/Console）
  验收：明确告警门限、事件存储、通知方式和 API 暴露范围。

#### P5 安全与上下文

- [ ] P5-01 设计模型、智能体、AK、输入、输出粒度的安全策略投影（Console/Higress）
  验收：定义策略对象、匹配粒度、投影链路和拦截结果字段。
- [ ] P5-02 规划自定义安全规则管理（Console）
  验收：形成规则定义、启停、优先级和命中查看边界。
- [ ] P5-03 规划配置变更审计与操作日志（Portal/Console）
  验收：明确审计字段、记录主体、查询条件和保留策略。
- [ ] P5-04 设计上下文窗口自动优化（Portal/Higress）
  验收：形成输入 token 评估、自动分段、模型窗口适配和失败兜底逻辑。
- [ ] P5-05 规划 `ai-cache`、`ai-history` 的租户与部门成员隔离（Portal/Higress）
  验收：明确缓存命名空间、隔离粒度、命中规则和清理边界。
- [ ] P5-06 规划长期记忆服务，默认基于 `ai-rag + 向量库`（Portal/Console/Higress）
  验收：形成长期记忆对象、召回链路、授权边界和首轮向量库方案。

#### P6 收口与发布

- [ ] P6-01 规划 Portal、Console、Higress、plugin-server 联调顺序（跨项目）
  验收：明确联调阶段、依赖顺序、验证入口和责任边界。
- [ ] P6-02 定义迁移、回填、回滚步骤（跨项目）
  验收：形成数据库、配置、缓存投影的迁移与回滚脚本要求。
- [ ] P6-03 规划插件发版与分发（Higress/plugin-server）
  验收：明确插件版本升级、分发流程和兼容验证要求。
- [ ] P6-04 定义全链路验收清单（跨项目）
  验收：形成 Portal、Console、Higress、plugin-server 的联通性与功能验收矩阵。
- [ ] P6-05 完成文档收口，回写 `roadmap.md` 里程碑状态与 `TODO.md` 完成记录（根目录协同）
  验收：所有已完成任务均回写结果，路线图状态与实施结果一致。

### 已完成记录规范

- 任务未开始时使用 `- [ ] Pn-xx 任务名（影响系统）`，下一行写 `验收：...`。
- 任务完成后改为 `- [x] Pn-xx 任务名（影响系统）`，并将 `验收：...` 替换为 `结果：...`。
- `task.md` 中的进行中、今日更新、已完成待回写必须引用 `TODO.md` 中已有的任务 ID，不新增孤立任务。
- 阶段收口时，同步检查 `roadmap.md` 里程碑状态、`TODO.md` 完成结果和 `task.md` 活跃状态是否一致。
