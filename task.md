# AIGateway 实施任务台账

> 文档职责：本文件只记录“当前进行中、阻塞项、最近更新、最近验证”。  
> 稳定边界看 `Project.md`，执行清单看 `TODO.md`，发布 / 部署台账看 `TASK/README.md`。

更新时间：2026-04-25

## 当前阶段

- 当前阶段：`P3 智能体产品化`
- 当前状态：`P0`、`P1`、`P2` 已完成；`P3` 主链路已完成首版实现与验证，下一步可转入 `P4` 观测、高可用、流控规划
- 主控文档：`TODO.md`、`roadmap.md`、`task.md`
- 执行默认项：平台底座优先、MCP-backed agent、两档模型定价、根目录三文档主控

## 本周进行中

- [x] P3-01 ~ P3-06 智能体产品化与 Portal AI 对话主链路
  结果：已完成 `agent_catalog` 控制面、Portal 智能体广场、`AI对话` 菜单与流式会话接口、会话持久化、模型/API Key 作用域校验、grant 到 MCP `consumerAuthInfo` 的投影，以及 Portal 全站按根目录 `DESIGN.md` 的首版风格重构。
  验证：`go test ./...`、`npm run build`、`./mvnw ... compiler:compile`、`npm run build` 已分别在 Portal 后端、Portal 前端、Console 后端、Console 前端通过。
- [ ] P3/P5-AF 模型资产 RPM/TPM 投影到每用户每模型限流
  结果：Console 已新增 `ai-model-rate-limit-reconcile`、`ai-model-rate-limit-projections/default`、`cluster-key-rate-limit / ai-token-ratelimit` builtin runtime 规则同步；`AI Route` 的 `modelPredicates` 已真正投影到 `x-higress-llm-model` ingress 匹配，当前只对单条 `EQUAL(model_id)` 路由自动生效，并记录 skip reason。
  验证：`cd aigateway-console/backend && go test ./utility/clients/k8s ./internal/service/jobs ./internal/service/gateway ./internal/cmd`
  阻塞：`2026-04-23` 在 `minikube-dev` live smoke 中已复现 `POST /qwen/v1/chat/completions` 返回 `401 Request denied by ai quota check. No Key Authentication information found.`；已定位为 builtin `ai-quota` 默认落在 `UNSPECIFIED_PHASE`，导致 public/internal AI Route 上读取不到 `key-auth` 注入的 `x-mse-consumer`，代码已改为 `AUTHN` phase，仍需在重建后继续补 `429` 行为与 `/system/jobs` 手工触发链路验证。

## 本轮不做

- `resource/prompt` 在线编辑、版本管理、发布流不在 P3 首版范围内。
- Portal `AI对话` 首版只做文本会话，不做附件上传、多模态、联网搜索、深度思考和 regenerate。
- `ai-agent` 插件产品化与 OpenAI-compatible agent chat API 暂不进入本轮。

## 阻塞项

- 暂无。

## 今日更新

- 已针对线上 `console.aigateway.io/consumer` 的 `Portal database is unavailable` 首启窗口做稳定性加固：Console `portaldb` 健康检查不再把启动期 PostgreSQL 失败永久缓存为 `portalHealthy=false`；Portal `main` 改为在进程内循环等待数据库与 bootstrap 就绪，不再因 PostgreSQL 稍晚启动而直接退出 Pod。
- 已补 release standard profile 的 Portal Prometheus 注入：`aigateway-portal.backend.corePrometheusURL` 固定指向 `http://aigateway-console-prometheus:9090/prometheus`，避免新环境 AI 监控面板因未注入指标源而无用量统计。
- 已补 release profile 的 `global.onlyPushRouteCluster=false`：默认 release 数据面现在会下发普通 Kubernetes Service cluster，避免 `ai-quota` / `ai-token-ratelimit` / `cluster-key-rate-limit` 访问 `redis-server-master.<namespace>.svc.cluster.local` 时因未推送 cluster 报 `error status returned by host: bad argument`。
- 已为 Console / Portal Deployment 增加 `wait-for-portal-db` initContainer，使用 `pg_isready` 先等待 PostgreSQL，再启动应用容器，降低 release 首启阶段命中共享库未就绪窗口的概率。
- 已补 Portal Redis 账单 runtime 的自愈能力：`billing` consumer loop 改为断线后持续重连，并在定时同步时重新发现 `ai-quota` amount bindings；Redis 或 K8s runtime 配置在启动窗口稍晚就绪时，不再因为首轮失败而永久丢失消费链路。
- 已执行 `cd aigateway-console/backend && go test ./utility/clients/portaldb ./internal/service/portal ./internal/service/jobs ./internal/service/platform ./internal/cmd/...`、`cd aigateway-portal/backend && go test ./internal/cmd/...`，并重新执行 release values `helm template`，渲染结果当前为 `4591` 行。
- 已为新环境发布链路补充显式数据库初始化阶段：`release-deploy` 在 Helm `--wait` 后会依次执行 Portal `db-init` 与 Console `portaldb-init`，不再依赖首个业务请求触发补表。
- 已在 `192.168.42.200` 干净 Ubuntu 24.04.3 LTS 环境完成 `1.1.0` k3d 实机部署；正式访问口径已切为 Kubernetes Ingress：`console.aigateway.io`、`portal.aigateway.io`。
- 已在目标机输出运行时离线包与安装日志：`/opt/aigateway-install/1.1.0/offline-packages/`、`/opt/aigateway-install/1.1.0/logs/`；过程文档已写入 `docs/release/1.1.0/install-192.168.42.200.md`。
- 已启动 `1.1.0` 正式发布交付：`helm/image-versions.yaml`、父 Chart、Console / Portal 子 Chart 和 release values 已切到 `1.1.0`，默认 bundle 名称为 `aigateway-1.1.0`。
- 已新增 `docs/release/1.1.0/` 发布说明、镜像包说明、部署说明，以及 `docs/overview/aigateway-whitepaper-1.1.0.md` 项目介绍白皮书。
- 已调整 `scripts/export-formal-docs.py` 支持按 `--version` 导出当前版本正式文档，默认输出为 `out/docs/1.1.0/`。
- 已生成 `1.1.0` release bundle：`out/release/aigateway-1.1.0/`，当前 standard profile bundle 包含 13 个镜像 tar、`higress-1.1.0.tgz`、`images.lock`、`SHA256SUMS` 和 `deploy.sh`；已修复 `release-build` 生成 `SHA256SUMS` 时包含自身的问题。
- 已生成 `1.1.0` 正式文档导出件与项目介绍 PPT：`out/docs/1.1.0/`，其中 PPT 为 `aigateway-project-introduction-1.1.0.pptx`，封面资产来自 `imagegen`。
- 已新增仓库级测试闸门入口 `./start.sh test --stage <unit|integration|e2e|acceptance|release|all>`，统一编排 Portal/Console 后端、关键 Higress runtime 插件、Portal/Console 前端黑盒、Chrome DevTools 验收以及 release dry-run。
- 已将 Go 集成测试切到 `integration` build tag：Portal/Console 的 PostgreSQL/Testcontainers 用例不再混入默认 `go test ./...`，避免发布前的 unit gate 与 integration gate 混在一起。
- 已补 Portal Playwright smoke、扩展 Console Playwright 页面覆盖，并新增 `plugin-server` 最小 Python 单测。
- 已新增 `TASK/release/acceptance/` 与 `scripts/validate-acceptance.py`，`./start.sh test --stage acceptance` 会生成/校验 Chrome DevTools 验收产物，并将未完成验收视为阻断。
- 根文档体系已收口为“研发 / 产品主控”与“发布 / 部署主控”两条主线，并以 `AGENTS.md` 固化读取顺序和同步规则。
- 已建立正式 `docs/` 文档源码目录，承载 `1.0.0` 白皮书、发布说明和用户手册。
- `1.0.0` 正式版本规则已固定：仓库管理的一方镜像统一使用 `1.0.0`，第三方依赖通过 bundle 与 Helm values 锁定。
- 已基于真实 `1.0.0` 运行环境补齐 Portal + Console 页面截图，正式截图统一落在 `output/manual/1.0.0/`。
- 已新增 `scripts/export-formal-docs.py`，将 `docs/` 下 5 份正式文档导出到 `out/docs/1.0.0/` 的 HTML / Docx / PDF 交付件。
- 已修复 `scripts/release-build.sh` 的 bundle 锁文件生成逻辑，当前 `out/release/aigateway-1.0.0/metadata/images.lock` 与 `images/*.tar` 已保持一致。
- `P3/P5-AF` 已完成首版实现：模型资产发布配置的 `RPM/TPM` 会按 `70%` 生成每用户每模型限流规则，`RPM -> cluster-key-rate-limit`，`TPM -> ai-token-ratelimit`，并绑定到 `AI Route` 的 public/internal/fallback ingress。
- `P3/P5-AF` 已补控制面闭环：`gateway` 写路径新增 `ai-route-save/delete` hook，`model-binding-*` 和 `ai-route*` 变更都会触发 `ai-model-rate-limit-reconcile`；projection 资源更新后会自动同步 builtin `WasmPlugin matchRules`。
- `P3/P5-AF` 已补测试：`AI Route modelPredicates -> x-higress-llm-model`、memory client projection sync、以及 `ai-model-rate-limit-reconcile` 的规则生成 / skip reason 都已有 Go 单测覆盖。
- `P3/P5-AF` live smoke 已定位一处运行时回归：`ai-quota` 默认 phase 若为 `UNSPECIFIED_PHASE`，public `AI Route` 会在 `key-auth` 之前执行并返回 `ai-quota.no_key`；当前已把控制面 builtin manifest 契约修正为 `AUTHN`，并在 `minikube-dev` 下用 `api.ai.local/qwen/v1/chat/completions` 实测恢复 `200`。
- Portal OIDC SSO 首版已完成：Portal 共享库已新增 `portal_sso_config` / `portal_user_sso_identity`，Portal 后端已接入 OIDC authorize/callback 流程并支持邮箱首绑、自动创建 `pending` 账号；Console `/system` 页面已新增 Portal SSO 配置区块，保存时会校验 OIDC discovery 文档并把配置写入共享库。
- Portal OIDC SSO 与组织管理已完成第二轮收口：Console 组织页已新增 SSO pending 账号改绑入口，改绑继续复用 `portal_user_sso_identity`，成功后原自动建档账号会执行软删除；新建部门已支持“选择已有活跃用户”或“同步新建管理员账号”两种模式，并在复用已有用户时自动迁移部门归属与旧管理员绑定。
- `P1-04 / P1-06` 已完成模型收口：正式废弃“父账号 / 子账号”管理模型，Portal 与 Console 统一按“部门树 + 部门管理员 + 部门成员”实现；Portal 已支持部门管理员创建当前部门成员、成员视角账单/API Key 管理和管理员余额转账，Console 已要求新建部门时同步创建管理员账号，并支持在编辑部门时改绑当前部门活跃管理员。
- `P1-04 / P1-06` 组织页口径已补充更新：Console 现在保留“新建部门即建管理员账号”兼容路径，但默认支持从已有活跃用户中搜索并选择部门管理员；组织账号删除入口已明确为软删除，不做物理删除。
- `P3-AF-07 ~ P3-AF-11` 已完成：`ai-proxy`、Console、Portal 已统一收口 `protocol / capability / endpoint / request path` 边界；一级 protocol 固定为 `openai/v1`、`anthropic/v1/messages`、`original`，Provider 资源额外允许 `auto`；Console 已新增 `provider-protocol-directory`，前端 Provider 与 Model Binding 表单已改为受控协议下拉，并按 `provider-api-docs/<provider>/` 子目录中的官方文档计算 `providerDocsStatus`。
- `P3-AF-08` 运行时语义已固定：`provider.protocol=""` 保留自动检测，显式 `openai` 仍允许 Claude `/v1/messages` 自动兜底，显式 `anthropic` 固定按 Claude `messages` 入口处理，显式 `original` 才完全关闭 OpenAI / Claude 自动检测。
- `P3-AF-09 / P3-AF-10` 已补最小验证：`higress/plugins/wasm-go/extensions/ai-proxy`、`aigateway-console/backend/internal/service/gateway`、`aigateway-console/backend/internal/service/portal`、`aigateway-portal/backend/internal/client/k8s` 定向 Go 测试通过，`aigateway-console/frontend` 构建通过。
- `P3-01` 已完成：Console 后端已新增 `portal_agent_catalog` 表、`AgentCatalogRecord` 模型、`/v1/ai/agent-catalog` CRUD/发布/下架接口，并固定一个 agent 绑定一个 Higress MCP Server。
- `P3-02` 已完成：Console 前端已新增“智能体目录管理”页面，支持新建、编辑、发布/下架、授权管理以及 MCP HTTP / SSE 地址复制。
- `P3-03` 已完成：`asset_grant` 已新增 `agent_catalog` 资产类型；保存授权时若目标 agent 已发布，会同步把 grant 展开的 consumer 名单投影到目标 MCP Server 的 `consumerAuthInfo.allowedConsumers`。
- `P3-04` 已完成：Console 智能体详情页已按只读方式展示 `resourceSummary` / `promptSummary`，明确“需在 MCP 原始配置中维护”的首版边界。
- `P3-05` 已完成：Portal 后端已新增 `/api/agents`、`/api/agents/:id`、`/api/ai-chat/sessions*` 和流式发送接口；Portal 前端已新增智能体广场与 `AI对话` 页面，并按 `DESIGN.md` 改造全站壳层和模型广场交互。
- `P3-05` 已补充说明：Portal `AI对话` 参考 `/home/cloudyi/code/chatserver-web` 与 `/home/cloudyi/code/chatserver-api` 的交互基线实现，支持新建会话、右侧历史会话、服务端持久化、SSE 增量补字、重命名和删除。
- `P3-06` 已完成：Portal AI 会话已新增 `portal_ai_chat_session` / `portal_ai_chat_message` 表，固定以当前有效 `consumerName` scope 作为会话归属；发送消息时会再次校验模型可见性、API Key 归属与可用状态，并把 `requestId` / `traceId` / `httpStatus` 写回消息记录。
- `P2-07` 已完成修订：AI 路由表单恢复为按 `provider` 选择服务名称，目标模型候选只来自该 Provider 下已发布绑定；旧路由若引用未发布绑定或已下线 Provider，仍按原 Provider 回显并给出提示。
- `P2-08` 已完成修订：模型资产的标签、模态、能力特性、请求类型都已收口到系统预置选项；新建绑定支持 `Provider -> 模型目录` 联动下拉，未配置目录的 Provider 保留手填兜底。
- `P2-09` 已完成：AI 脱敏规则链路已补 DB 去重和签名唯一约束，启动时会清理历史重复记录，后续保存不再插入重复规则。
- `P2-10` 已完成：Route / AI Route / MCP 的等级授权语义已统一修正为“高等级自动拥有低等级权限”。
- `P0-01` 已完成：新增 `roadmap.md` 初版，冻结背景目标、能力对比、阶段路线图、插件改造清单、里程碑与默认项。
- `P0-02` 已完成：在 `TODO.md` 追加 `2026-04 平台能力建设执行面板`，统一目标、规则、阶段任务和完成记录规范。
- `P0-03` 已完成：新增 `task.md` 作为活跃任务工作台，建立阶段、进行中、阻塞、验证的固定结构。
- `P0-04` 已完成：固化“平台底座优先、MCP 型智能体、两档模型定价、根目录三文档主控”默认实施假设。
- `P0-05` 已完成：完成当前能力对比与插件改造矩阵，明确重点插件范围。
- `P0-06` 已完成：已新增项目级 skill，覆盖“仓库导览 / 开发环境启动 / 当前阶段状态读取”，并将使用边界写入 `Project.md` 团队约定。
- `P1-01` 已完成：Portal/Console 共用 PostgreSQL 已新增 `org_department`、`org_account_membership`，并在启动时自动创建虚拟根部门和未分配 membership。
- 文档/skill 口径更新：根级文档、Portal/Console 项目文档与项目级 skill 已统一更新为 PostgreSQL-only；历史 MySQL 表述仅保留在迁移记录中。
- `P1-02` 已完成：按“无兼容路径”方案移除 Portal 注册页的 `department` 输入，Portal 登录态改为返回 `departmentId`、`departmentName`、`departmentPath`、`adminConsumerName`、`isDepartmentAdmin`。
- `P1-03` 已完成：Console 已新增 `asset_grant` 表服务、资产授权管理接口与 `AuthorizationSubjectResolver` 授权展开逻辑。
- `P1-04` 已完成：Console 已新增 `/v1/org/*` 接口，并将 `/consumer` 页面重构为组织树、部门管理、账号创建编辑和部门管理员指定视图。
- `P1-05` 已完成：现有 `key-auth` / `allowedConsumerLevels` 运行时协议保持不变，API Key 继续继承所属 `consumer_name`，首轮不新增 AK 独立授权模型。
- `P1-06` 已完成：Portal 已新增部门管理员对部门树成员的管理视图与接口，支持列出可管理成员、切换到成员视角查看账单和 API Key，并支持管理员与成员之间的余额转账、成员账号创建以及用户等级和状态更新。
- `P1-06` 已补充验证：已在运行中的 Console 实例上复现 `POST /v1/org/accounts` 因缺省 `email` 导致 `portal_user.email` 非空约束失败的问题；修正 `PortalUserJdbcService` 的空值回填后，重建并滚动 `aigateway-console`，用 `admin/admin` 登录后以 `consumerName=testa`、`departmentId=410c6127959c40ceb677dc0ee512d54e` 的原始请求实测创建成功。
- `P2-01` 已进入第二轮收口：Console 已新增 `model-assets` 控制面入口，Provider 页不再作为正式上架和定价入口；Provider CRUD 不再自动直写 Portal 模型价格。
- `P2-02` 已启动开发准备：已确认第二轮不把两档定价建在旧 Provider 定价链路上，而是把绑定草稿价格作为编辑态、把 `billing_model_price_version` 继续作为已发布价格真相源。
- 已确认价格版本回滚语义：历史版本只支持“恢复到草稿并重新发布”，不提供直接激活旧版本的入口。
- 已确认 Portal 模型广场读取边界：`/models`、`/models/:id` 优先读显式发布绑定及其发布快照，不再从 K8s Provider 目录兜底暴露未发布模型。
- `P2-03` 已完成首轮落地：模型资产新增 `requestKinds` 元数据，Console 与 Portal 已同步展示多模态请求能力。
- `P2-04` 已完成首轮落地：授权对象固定为 `model_binding`，Console 支持绑定 grant 管理，Portal 模型广场按 grant 过滤可见性。
- `P2-05` 已完成首轮落地：Portal 已新增请求级明细接口和页面表格，Console 已新增运维侧 usage event 查询接口。
- `P2-06` 已完成首轮落地：usage 事件和日汇总已落部门快照，Portal/Console 已新增部门账单汇总查询。

## 已完成待回写

- 无，`P3-01` 至 `P3-06` 已同步回写根目录 `TODO.md`。

## 验证记录

- 已执行 `bash -n start.sh scripts/test.sh`，新增仓库级测试入口脚本语法通过。
- 已执行 `python3 -m py_compile scripts/validate-acceptance.py plugin-server/generate_metadata.py plugin-server/pull_plugins.py plugin-server/tests/test_plugin_scripts.py`，新增 Python 验收/插件脚本语法通过。
- 已执行 `cd plugin-server && python3 -m unittest discover -s tests -p 'test_*.py'`，`plugin-server` 新增最小单测通过。
- 已核对 `TODO.md`、`roadmap.md`、`task.md` 的任务编号和阶段划分一致。
- 已核对 `roadmap.md` 包含“背景与目标、当前能力对比、阶段路线图、插件改造清单、里程碑验收、风险与默认项”六个固定章节。
- 已核对 `task.md` 中所有任务都引用 `TODO.md` 中的任务 ID，不存在孤立任务。
- 已执行 `./mvnw -q -pl console -am -DskipTests -Dpmd.skip=true compiler:compile`，Console 后端新增组织与授权代码可编译通过。
- 已执行 `npm run build`，`aigateway-console/frontend` 构建通过，新的 `/consumer` 页面代码已进入生产构建。
- 已执行 `go test ./...`，`aigateway-portal/backend` 测试通过。
- 已执行 `npm run build`，`aigateway-portal/frontend` 构建通过，Portal 注册页与登录态类型改动已通过前端构建验证。
- 已执行 `go test ./...`，`aigateway-portal/backend` 在切换到“部门树 + 部门管理员 + 部门成员”模型后继续通过。
- 已执行 `npm run build`，`aigateway-portal/frontend` 在新增“部门成员管理”页与成员视角切换后继续通过。
- 已在真实运行环境完成接口复现与验证：旧 Console Pod 日志明确报错 `Column 'email' cannot be null`；滚动到新 Pod `aigateway-console-5f9f5fcd57-lwbd4` 后，通过本地端口转发到 `127.0.0.1:18080`，以 `admin/admin` 登录并调用 `POST /v1/org/accounts`，用户 `testa` 创建成功。
- 已确认 `P2-02` 至 `P2-06` 的顺序和依赖关系，不与 `P2-01` 并行启动。
- 已确认第二轮范围：先收口 `P2-01` 的控制面与 Portal 读取切换，再推进 `P2-02` 的两档价格编辑、active 版本切换、历史回显和“恢复到草稿”链路。
- 已执行 `./mvnw -q -pl console -am -DskipTests -Dpmd.skip=true compiler:compile`，`aigateway-console/backend` 的 `model-assets` 控制器、价格版本接口和 Provider 链路收口代码可编译通过。
- 已执行 `npm run build`，`aigateway-console/frontend` 的模型资产页、价格历史回显和 Provider 页入口调整已通过生产构建。
- 已执行 `go test ./...`，`aigateway-portal/backend` 的显式发布绑定读取和计费运行时切换在第二轮改造后继续通过。
- 已执行 `go test ./...`，`aigateway-portal/backend` 的模型授权过滤、请求明细、部门快照回填与部门账单汇总代码通过。
- 已执行 `npm run build`，`aigateway-portal/frontend` 的模型广场 `requestKinds` 展示、开放平台请求明细与账单页部门汇总通过构建。
- 已执行 `./mvnw -q -pl console -am -DskipTests -Dpmd.skip=true compiler:compile`，`aigateway-console/backend` 的 usage-events / department-bills API、`requestKinds` 存储与模型绑定授权编译通过。
- 已执行 `npm run build`，`aigateway-console/frontend` 的模型资产 `requestKinds` 表单与绑定授权视图通过生产构建。
- 已执行 `npm run build`，`aigateway-console/frontend` 的 AI 路由 `provider` 联动选择、模型资产预置能力字段和绑定模型下拉通过生产构建。
- 已执行 `./mvnw -q -pl console -am -DskipTests -Dpmd.skip=true compiler:compile`，`aigateway-console/backend` 的 `model-assets/options` 接口、能力字段白名单校验和既有 `asset_grant user_level` / AI 脱敏改动编译通过。
- 已执行 `go test ./...`，`aigateway-portal/backend` 的模型绑定 `user_level` 可见性过滤回归通过。
- 已执行 `go test ./...`，`aigateway-portal/backend` 的 `agent_catalog` 查询、AI 会话持久化、SSE 流式对话和模型/API Key 作用域校验代码通过。
- 已执行 `cd aigateway-portal/backend && go test ./internal/service/portal/... ./internal/controller/portal/... ./internal/model/... ./schema/shared/...`，部门成员管理与余额转账改造后的 Portal 后端测试通过。
- 已执行 `cd aigateway-portal/frontend && npm run build`，Portal 前端的“部门成员管理”页、新建成员与成员视角改造通过构建。
- 已执行 `cd aigateway-console/backend && go test ./internal/service/portal/... ./internal/controller/portal/... ./utility/clients/portaldb/...`，部门管理员创建/改绑与 membership 清理后的 Console 后端测试通过。
- 已执行 `cd aigateway-console/frontend && npm run build`，Console `/consumer` 页面新增“建部门即建管理员 / 编辑部门改绑管理员”流程后通过构建。
- 已执行 `cd aigateway-console/backend && go test ./internal/service/portal`、`cd aigateway-console/backend && go test -run '^$' ./internal/service/portal ./internal/controller/portal ./internal/cmd/...`、`cd aigateway-console/frontend && npm run build`，Portal SSO 配置读写、共享 schema mock 与 `/system` 页面改造通过验证。
- 已执行 `cd aigateway-portal/backend && go test ./internal/service/portal ./internal/controller/portal ./internal/cmd/...`、`cd aigateway-portal/frontend && npm run build`，Portal OIDC SSO 后端 authorize/callback 链路与登录/注册页入口改造通过验证。
- 已执行 `npm run build`，`aigateway-portal/frontend` 的全站 `DESIGN.md` 风格壳层、智能体广场和 `AI对话` 页面通过生产构建。
- 已执行 `./mvnw -q -pl console -am -DskipTests -Dpmd.skip=true compiler:compile`，`aigateway-console/backend` 的 `agent-catalog` 控制器、JDBC service 和 grant -> MCP 授权投影代码可编译通过。
- 已执行 `npm run build`，`aigateway-console/frontend` 的“智能体目录管理”菜单、页面、授权抽屉和地址复制功能通过生产构建。
- 已执行 `./start.sh help`、`./start.sh show`、`./start.sh sync --check`、`./start.sh release-build --dry-run`、`./start.sh release-deploy --target k8s --bundle-dir out/release/aigateway-1.0.0 --registry registry.example.com/team --dry-run`，`1.0.0` 正式发布链路可完成命令级校验。
- 已执行 `helm template aigateway ./helm/higress -f ./higress/helm/higress/values-release-base.yaml -f ./higress/helm/higress/values-release-ha.yaml -f ./higress/helm/higress/values-release-upstreams.yaml`，渲染结果共 `3904` 行。
- 已导出 `out/docs/1.0.0/` 正式文档交付件，并校验 `user-manual` 的截图引用已全部落盘。
- `./start.sh release-deploy --target k3d ... --dry-run` 在当前机器失败，原因是缺少本机命令 `k3d`，属于环境前置条件未满足，不是仓库脚本错误。
- 已执行 `./start.sh show`、`./start.sh sync --check`、`./start.sh release-build --dry-run`、`./start.sh release-build`、`./start.sh release-deploy --target k8s --bundle-dir out/release/aigateway-1.1.0 --registry registry.example.com/team --dry-run`，`1.1.0` 发布包与通用 K8S dry-run 通过。
- 已执行 `helm template aigateway ./helm/higress -f ./higress/helm/higress/values-release-base.yaml -f ./higress/helm/higress/values-release-ha.yaml -f ./higress/helm/higress/values-release-upstreams.yaml`，`1.1.0` 渲染结果共 `3904` 行，并确认一方镜像渲染为 `1.1.0`。
- 已执行 `.venv-docs/bin/python scripts/export-formal-docs.py --version 1.1.0`，导出 `out/docs/1.1.0/` 的 HTML / Docx / PDF 交付件。
- 已执行 `.venv-docs/bin/python scripts/generate-project-intro-ppt.py` 并用 `python-pptx` 校验 PPT 文本层，`aigateway-project-introduction-1.1.0.pptx` 共 `6` 页。
- 已执行 `sha256sum -c metadata/SHA256SUMS`，`out/release/aigateway-1.1.0/` 中 17 个条目校验通过。
- `./start.sh release-deploy --target k3d --bundle-dir out/release/aigateway-1.1.0 --cluster aigateway-110 --dry-run` 在当前机器失败，原因是缺少本机命令 `k3d`。
- 已在 `192.168.42.200` 执行 `sha256sum -c metadata/SHA256SUMS`、创建 `k3d` 集群 `aigateway-110`、部署 `out/release/aigateway-1.1.0`，最终 `helm status aigateway -n aigateway-system` 为 `deployed`，`aigateway-system` 业务 Pod 全部 Running。
- 已从目标机验证 `curl -H 'Host: console.aigateway.io' http://127.0.0.1/` 与 `curl -H 'Host: portal.aigateway.io' http://127.0.0.1/` 均返回 `200 OK`；临时排障用 port-forward systemd 服务已停用并删除。
- 已在修复 Portal 干净库首启问题后重新执行 `./start.sh release-build`，同步新 bundle 到 `192.168.42.200`，导入修复后的 Portal 镜像，并将目标机 Helm release 升级到 revision `3`；Console / Portal Ingress 从本机连续访问均为 `200`。
- 已为 release 部署脚本增加 Console / Portal Ingress 域名契约：标准 K8S 读取 `aigateway-system/aigateway-cluster-domain`，新建 k3d 可用 `k3d-cluster.sh --base-domain` 写入，后续可用 `release-deploy --base-domain` 修改并触发 Helm upgrade。
- 已按组件重新构建并发布 `aigateway/console:1.1.0` 与 `aigateway/portal:1.1.0`，刷新 `out/release/aigateway-1.1.0/`，同步到 `192.168.42.200`，目标机 Helm release 升级到 revision `4`，Console / Portal Ingress 连续访问均为 `200`。
- 已定位新环境 Pod 数量偏多原因：目标机 k3d 实际为 `1 server + 2 agent`，且部署使用 `ha` profile；已将 release 默认 profile 调整为 `standard`，k3d 创建脚本默认 `--agents 0`，`ha` profile 改为显式 opt-in。
- 已修复 Console Dashboard “监控未启用”：release standard profile 默认启用 `global.o11y.enabled=true`，bundle 已补齐 Grafana / Prometheus / Loki / Promtail 离线镜像，目标机升级到 Helm revision `5` 后 `/dashboard/info?type=MAIN` 登录态返回 `builtIn: true`。
- 已新增并验证 Ubuntu 24.04 离线 k3d 一键安装脚本 `install-k3d-offline.sh`；`192.168.42.200` 再次重置为干净 Ubuntu 24.04.3 LTS 后已通过该脚本完整离线安装 runtime、创建单节点 k3d、导入 runtime 与 release 镜像，当前 Helm revision `1`，Console / Portal Ingress 均返回 `200`，Console Dashboard 返回 `builtIn: true`，部署阶段已显式执行 Portal `db-init` 与 Console `portaldb-init`。
- 已修复 release standard profile 的 Redis standalone 地址：`higress-config` 现在指向 `redis-server-master.aigateway-system.svc.cluster.local:6379`，并将 ConfigMap 模板合并策略改为新 release values 覆盖旧集群值，避免升级后继续保留旧 `redis-server` 地址。
- 已修复 Portal key-auth 投影：Portal 首次同步会创建非全局认证的 `key-auth.internal`，`defaultConfig.global_auth=false`，后续只由 Console 在业务 Route / AI Route 上通过 `matchRules.allow` 启用鉴权，避免新环境持续打印 `key-auth wasmplugin not found` 且不拦截 Console / Portal Ingress。
