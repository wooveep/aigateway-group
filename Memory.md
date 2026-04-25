# AIGateway Group - 协作记忆

> 文档职责：记录稳定决策、已验证事实、排障结论和重要 caveat。当前推进状态看 `task.md`，执行清单看 `TODO.md`。

更新时间：2026-04-25

## 当前稳定基线

- 仓库主控文档分两条线：研发 / 产品主控为 `Project.md`、`roadmap.md`、`task.md`、`TODO.md`、`Memory.md`；发布 / 部署主控为 `TASK/README.md` 与 `TASK/release/`。
- 四个主产品边界固定：Portal 管用户门户与账单；Console 管控制面与运行时配置；Higress 管网关核心、插件、Helm 基座；Plugin Server 管 Wasm 插件分发。
- 数据库主线固定为 PostgreSQL-only。Portal / Console 共用 Portal PostgreSQL，Helm 统一入口为 `higress-core.postgresql.*`。
- `helm/image-versions.yaml` 是镜像 repository / tag、默认 bundle 名称、release 参数和默认 namespace / releaseName 的单一事实源。
- 正式发布链路固定为纯 shell：`./start.sh release-build`、`./start.sh release-deploy --target k3d|k8s`。
- Markdown 是正式文档真相源，Docx / PDF / PPT 是导出交付件。

## Release 与部署事实

### `1.1.0`

- 当前正式发布版本已推进到 `1.1.0`。仓库管理的一方镜像统一使用 `1.1.0`：`aigateway`、`aigateway/controller`、`aigateway/gateway`、`aigateway/pilot`、`aigateway/console`、`aigateway/portal`、`aigateway/plugin-server`。
- 第三方依赖镜像保持上游版本，通过 release values、bundle `metadata/images.lock` 与 `SHA256SUMS` 锁定。
- `1.1.0` 文档真相源：`docs/release/1.1.0/release-notes.md`、`image-bundle.md`、`deployment-guide.md`、`docs/overview/aigateway-whitepaper-1.1.0.md`。
- `1.1.0` 交付件：release bundle 在 `out/release/aigateway-1.1.0/`，正式文档与 PPT 在 `out/docs/1.1.0/`。
- 已在 `192.168.42.200` 干净 Ubuntu 24.04.3 LTS 完成离线 k3d 部署验证。安装目录固定为 `/opt/aigateway-install/1.1.0/`，最新安装日志为 `logs/install-k3d-offline-20260425010528.log`。
- 正式访问口径走 Kubernetes Ingress：`console.aigateway.io`、`portal.aigateway.io`；不保留 Console / Portal port-forward systemd 服务。
- 标准 K8S 集群从 `aigateway-system/aigateway-cluster-domain` 读取 `baseDomain`；新建 k3d 可用 `release-k3d-cluster.sh --base-domain` 写入，后续可通过 `release-deploy --base-domain` 修改。
- release 默认 profile 已收敛为 `standard`，新建 k3d 默认单节点 `1 server + 0 agent`；`ha` profile 仅显式启用。
- standard profile 使用单副本 / standalone PostgreSQL 和 Redis，并默认启用 Grafana / Prometheus / Loki / Promtail。Console `/dashboard/info?type=MAIN` 登录态返回 `builtIn: true` 已验证。
- 离线机器部署必须携带 k3d / k3s / k3s system images 与 release bundle。仅 `docker load` 不足，必须把 `rancher/mirrored-pause:3.6` 等系统镜像导入 k3d 节点 containerd。
- Docker 29 + k3d v5.8.3 下，`k3d image import` 对部分 docker archive 可能报 digest / EOF 错误；可靠路径是 `docker cp + ctr -n k8s.io images import` 逐节点导入。

### `1.0.0`

- `1.0.0` 已完成根文档整编、`docs/` 正式文档源、用户手册截图、Docx / PDF 导出与 release bundle 校验。
- `scripts/release-build.sh` 已修复 `metadata/images.lock` 与实际 `images/*.tar` 脱节问题。
- `1.0.0` 口径保留为历史发布记录；新任务不得把 `1.0.0` 默认套用到当前开发或正式交付。

## 首启与运行时 caveat

- 新环境数据库初始化必须由 `release-deploy` 在 Helm `--wait` 后显式执行 Portal `db-init` 与 Console `portaldb-init`。legacy 旧库迁移继续使用独立命令 `portal-legacy-migrate`。
- Console `portaldb` 健康检查不能缓存启动期失败结果；恢复后必须重新 `Ping + EnsureSchema` 并清掉旧错误。
- Portal `main` 必须在进程内循环等待数据库与 bootstrap 就绪，不能因 PostgreSQL 稍晚启动直接退出 Pod。
- Console / Portal Deployment 必须先跑 `wait-for-portal-db` initContainer，用 `pg_isready` 等待 PostgreSQL ready。
- Portal 主进程不应把 Redis 作为启动硬依赖；billing usage consumer 必须在首轮连接失败、断线、`NOGROUP` 后持续重连。
- Portal billing 同步必须周期性重新发现 `ai-quota` amount bindings，避免 Redis 或 K8s runtime 配置稍晚就绪时永久缺失账单消费链路。
- standard profile 下 Redis 服务名是 `redis-server-master`，`higress-config` 应渲染 `redis-server-master.aigateway-system.svc.cluster.local:6379`。
- release profile 必须保持 `global.onlyPushRouteCluster=false`，否则数据面不会为普通 Kubernetes Service 下发 outbound cluster，AI quota / token rate limit 访问 Redis 会报 `bad argument`。
- `higress-config` 模板应使用 `mergeOverwrite`，让新 release values 能覆盖旧集群 ConfigMap 字段。

## 鉴权、额度与插件顺序

- public AI Route 上 `ai-quota` 依赖 `key-auth` 注入的 `X-Mse-Consumer` / `X-Higress-Api-Key-Id`，必须在 `key-auth` 后执行。
- 控制面 builtin `WasmPlugin` 契约：`key-auth.phase=AUTHN`，`ai-quota.phase=AUTHN`，且 `ai-quota.priority` 低于 `key-auth.priority`。
- `ai-quota` 若回退到 `UNSPECIFIED_PHASE`，已在 `minikube-dev` 复现 `401 Request denied by ai quota check. No Key Authentication information found.`。
- public AI Route 不应把 `modelPredicates` 直接收口成 `x-higress-llm-model` 必填 header；标准 OpenAI-compatible 调用通常只在 body 中携带 `model`，若公网 ingress 强依赖该 header，请求会绕过挂在 AI Route 上的 `ai-quota` / `ai-statistics`，而 internal AI Route 仍正常计费。
- internal AI Route 由 Portal 后端直连 `/internal/ai-routes/*` 并写入 `x-mse-consumer`，不要求 `key-auth` 挂到 `*-internal` ingress。
- 不要在 release chart 默认预置全局认证的 `key-auth.internal`。Portal key-auth 同步器负责创建 / 更新 `key-auth.internal`，实例级 `global_auth=false`；Console 负责在业务 Route / AI Route 上写 `matchRules.allow`。
- key-auth 多来源认证口径固定支持 `Authorization: Bearer`、`x-api-key`、`x-goog-api-key`、query `key`；不同来源出现不同 key 时返回 `401`。

## 组织、账号与 SSO

- Portal / Console 组织账号模型固定为“部门树 + 部门管理员 + 部门成员”，不再使用“父账号 / 子账号”作为正式模型。
- 组织真相源为 `org_department`、`org_account_membership`；部门管理员真相源为 `org_department.admin_consumer_name`。
- `org_account_membership.parent_consumer_name` 是历史兼容列，新代码不得依赖它做业务判断。
- Portal 可管理范围固定为“当前部门管理员可管理自己所在部门子树内成员账号”。
- Portal 余额调整语义固定为管理员钱包与成员钱包之间的强一致转账，正数表示管理员转给成员，负数表示从成员回收到管理员。
- Console 新建部门支持选择已有活跃用户作为管理员或同步新建管理员账号；选择已有用户时会迁移 membership，并清空其原部门管理员绑定。
- Portal SSO 首版支持“本地账号 + 单一全局 OIDC Provider”。配置真相源为 `portal_sso_config`，身份绑定真相源为 `portal_user_sso_identity`。
- SSO 首绑顺序：先按 `(provider_key, issuer, subject)` 查绑定，再按 email 精确匹配本地账号，否则创建 `source=sso`、`status=pending`、`user_level=normal` 本地账号并补空 membership。
- 首版不从 IdP claim 覆盖本地部门、等级、状态，也不自动发 API Key。
- `PORTAL_PUBLIC_BASE_URL` 是 Portal OIDC callback URL 的稳定部署入口；未设置时才按请求头推导。
- Console 组织账号删除语义固定为软删除：写 `is_deleted=true`、`deleted_at=now`，软删除账号不可登录，不得作为部门管理员候选。

## 模型资产、协议与计费

- `ai-proxy`、Console、Portal 的 canonical protocol 固定为 `openai/v1`、`anthropic/v1/messages`、`original`；Provider 资源额外允许 `auto`，`model_binding.protocol` 不允许 `auto`。
- `ai-proxy` 运行时语义：空协议为自动检测；显式 `openai` 仍允许 Claude `/v1/messages` 自动兜底；显式 `anthropic` 固定 Claude messages 入口；显式 `original` 完全关闭 OpenAI / Claude 自动检测。
- `responses`、`embeddings`、`images`、`audio`、`realtime`、`files`、`batches`、`models`、`videos` 等只作为 capability 或推荐入口，不作为一级 protocol。
- Provider API 文档事实源为 `TASK/projects/aigateway-console/provider-api-docs/<provider>/`，未提供足够官方文档时 `providerDocsStatus=pending`。
- AI Route 运行时仍提交 `provider + modelMapping`；Console 新建 / 编辑时按 Provider 约束目标模型候选，只来自已发布 `model_binding`。
- 模型绑定授权与 AI Route 授权是两层职责：绑定授权管模型可见性和模型范围，AI Route 授权管运行时请求准入。
- Portal 模型广场读取已发布绑定及发布快照，不从 K8s Provider 目录兜底暴露未发布模型。
- 对外价格字段固定为“元 / 百万 tokens”，运行时和账务真源固定为“微元 / token”。旧 `per_1k` 字段只作兼容镜像。
- Portal 账务主链以 PostgreSQL 钱包、流水、请求事件为真相源；Redis 是运行态投影，Prometheus 只做可选对账和观测。
- `administrator` 请求事件不进入业务账本。

## 智能体产品化

- `agent_catalog` 首版固定为 MCP-backed agent：一个已存在 Higress MCP Server 对应一个 agent 资产；`toolSet` 型 MCP Server 也按一个 agent 处理。
- 智能体开放 API v1 复用 MCP HTTP / SSE 端点，继续使用 `mcp-server`、`key-auth`、`ai-quota` 链路。
- `asset_grant` 已支持 `agent_catalog`。Console 保存 agent grant 后，会把命中 consumer 投影到目标 MCP Server 的 `consumerAuthInfo.allowedConsumers`。
- 未配置 grant 的 agent 保持“公开可见但仍要求合法 API Key”。
- `resource/prompt` 首版只做只读摘要与接入说明，不做在线编辑、版本管理和发布流。
- Portal `AI对话` 首版只做文本会话、SSE 增量、会话持久化、重命名 / 删除 / 恢复，不做附件、多模态、联网搜索、深度思考或 regenerate。

## 测试与验收

- 仓库级测试入口固定为 `./start.sh test --stage unit|integration|e2e|acceptance|release|all`。
- Portal / Console 的 PostgreSQL / Testcontainers 用例必须带 `integration` build tag，默认 `go test ./...` 不应拉起 Testcontainers。
- Chrome DevTools 验收真相源为 `TASK/release/acceptance/` 与 `out/test-acceptance/latest/summary.json`；未填写或状态不是 `pass` 时 acceptance gate 必须失败。
- 文档交付最小验证：`./start.sh help`、`./start.sh show`、`./start.sh sync --check`、`./start.sh release-build --dry-run`、`release-deploy --target k8s --dry-run`、release values `helm template`。

## Helm 与本地开发

- 根目录 `./helm/higress` 是统一父 Chart 入口，旧路径 `higress/helm/higress` 暂保留兼容回退。
- `start.sh dev` 在 minikube context 且无额外 Helm 参数时，默认走 `build-local-images + minikube image load + rollout restart`，避免只 `helm upgrade` 导致旧镜像继续运行。
- `dev-mode` 暴露策略：Console / Portal 使用 `ClusterIP + port-forward`，Gateway 使用 `ClusterIP + hostPort 80/443`。
- `values-local-minikube`、`values-production-k3d`、`values-production-gray` 暴露策略：Console / Portal / Gateway 使用 `LoadBalancer`，不使用 hostPort。
- `minikube-dev` 会从 `higress.io/config-map-type=domain` ConfigMap 自动同步 gateway 业务域名到 `/etc/hosts`；通配符域名仍跳过。

## 历史排障摘要

- Console 模型资产绑定弹窗的 `modelId / targetModel` 不能手输，根因是前端把存在 Provider 目录的字段渲染为纯 select；后端没有要求必须命中目录。当前口径为“可输入 + 建议列表”。
- `doubao` 不再作为独立 provider 类型维护，火山能力统一以 `volcengine` 暴露；读取存量 `doubao` 时兼容映射，保存后写回 `volcengine`。
- Portal 注册用户默认 `disabled`，需管理员在 Console 组织架构启用后登录；默认不再播种固定邀请码，除非显式配置 `PORTAL_BOOTSTRAP_INVITE_CODE`。
- `./start.sh dev --help` 曾误触发部署；当前应使用 `./start.sh help` 或 `./start.sh --help` 查看帮助，并保留误用保护。
