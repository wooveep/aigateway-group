# AIGateway 实施任务台账

更新时间：2026-04-10

## 当前阶段

- 当前阶段：`P3 智能体产品化`
- 当前状态：`P0`、`P1`、`P2` 已完成；`P3` 主链路已完成首版实现与验证，下一步可转入 `P4` 观测、高可用、流控规划
- 主控文档：`TODO.md`、`roadmap.md`、`task.md`
- 执行默认项：平台底座优先、MCP-backed agent、两档模型定价、根目录三文档主控

## 本周进行中

- [x] P3-01 ~ P3-06 智能体产品化与 Portal AI 对话主链路
  结果：已完成 `agent_catalog` 控制面、Portal 智能体广场、`AI对话` 菜单与流式会话接口、会话持久化、模型/API Key 作用域校验、grant 到 MCP `consumerAuthInfo` 的投影，以及 Portal 全站按根目录 `DESIGN.md` 的首版风格重构。
  验证：`go test ./...`、`npm run build`、`./mvnw ... compiler:compile`、`npm run build` 已分别在 Portal 后端、Portal 前端、Console 后端、Console 前端通过。

## 本轮不做

- `resource/prompt` 在线编辑、版本管理、发布流不在 P3 首版范围内。
- Portal `AI对话` 首版只做文本会话，不做附件上传、多模态、联网搜索、深度思考和 regenerate。
- `ai-agent` 插件产品化与 OpenAI-compatible agent chat API 暂不进入本轮。

## 阻塞项

- 暂无。

## 今日更新

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
- `P1-01` 已完成：Portal/Console 共用 MySQL 已新增 `org_department`、`org_account_membership`，并在启动时自动创建虚拟根部门和未分配 membership。
- `P1-02` 已完成：按“无兼容路径”方案移除 Portal 注册页的 `department` 输入，Portal 登录态改为返回 `departmentId`、`departmentName`、`departmentPath`、`parentConsumerName`。
- `P1-03` 已完成：Console 已新增 `asset_grant` 表服务、资产授权管理接口与 `AuthorizationSubjectResolver` 授权展开逻辑。
- `P1-04` 已完成：Console 已新增 `/v1/org/*` 接口，并将 `/consumer` 页面重构为组织树、部门管理、账号创建编辑和父账号分配视图。
- `P1-05` 已完成：现有 `key-auth` / `allowedConsumerLevels` 运行时协议保持不变，API Key 继续继承所属 `consumer_name`，首轮不新增 AK 独立授权模型。
- `P1-06` 已完成：Portal 已新增父账号对子账号的管理视图与接口，支持列出所有下级子账号、切换到子账号视角查看账单和 API Key，并支持调整余额、修改用户等级和状态。
- `P1-06` 已补充验证：已在运行中的 Console 实例上复现 `POST /v1/org/accounts` 因缺省 `email` 导致 `portal_user.email` 非空约束失败的问题；修正 `PortalUserJdbcService` 的空值回填后，重建并滚动 `aigateway-console`，用 `admin/admin` 登录后以 `consumerName=testa`、`departmentId=410c6127959c40ceb677dc0ee512d54e`、`parentConsumerName=liyuntian` 的原始请求实测创建成功。
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

- 已核对 `TODO.md`、`roadmap.md`、`task.md` 的任务编号和阶段划分一致。
- 已核对 `roadmap.md` 包含“背景与目标、当前能力对比、阶段路线图、插件改造清单、里程碑验收、风险与默认项”六个固定章节。
- 已核对 `task.md` 中所有任务都引用 `TODO.md` 中的任务 ID，不存在孤立任务。
- 已执行 `./mvnw -q -pl console -am -DskipTests -Dpmd.skip=true compiler:compile`，Console 后端新增组织与授权代码可编译通过。
- 已执行 `npm run build`，`aigateway-console/frontend` 构建通过，新的 `/consumer` 页面代码已进入生产构建。
- 已执行 `go test ./...`，`aigateway-portal/backend` 测试通过。
- 已执行 `npm run build`，`aigateway-portal/frontend` 构建通过，Portal 注册页与登录态类型改动已通过前端构建验证。
- 已执行 `go test ./...`，`aigateway-portal/backend` 在新增子账号管理能力后继续通过。
- 已执行 `npm run build`，`aigateway-portal/frontend` 在新增“子账号管理”页与子账号视角切换后继续通过。
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
- 已执行 `npm run build`，`aigateway-portal/frontend` 的全站 `DESIGN.md` 风格壳层、智能体广场和 `AI对话` 页面通过生产构建。
- 已执行 `./mvnw -q -pl console -am -DskipTests -Dpmd.skip=true compiler:compile`，`aigateway-console/backend` 的 `agent-catalog` 控制器、JDBC service 和 grant -> MCP 授权投影代码可编译通过。
- 已执行 `npm run build`，`aigateway-console/frontend` 的“智能体目录管理”菜单、页面、授权抽屉和地址复制功能通过生产构建。
