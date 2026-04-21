# AIGateway Group - 项目协作设计

## 1. 目标

在 `aigateway-group` 根目录建立跨子项目协作设计基线，用于统一记录：

- 子项目职责边界。
- 跨项目 API/数据库契约。
- 多团队并行改造时的流程规则。

## 2. 子项目职责

| 子项目 | 路径 | 主要职责 |
| --- | --- | --- |
| Portal | `aigateway-portal` | 门户前后端、用户登录、API Key、计费、发票等业务 |
| AIGateway Console | `aigateway-console` | Consumer/Credential 管理、用量查询等控制面能力 |
| Higress | `higress` | 网关核心能力与控制/数据面相关组件 |
| Plugin Server | `plugin-server` | 插件分发、插件元数据管理 |

## 3. 协作规则

- 根级 `Project.md`、`Memory.md`、`TODO.md` 负责跨子项目协作记忆。
- 子项目内文档继续负责各自实现细节，不被根级文档替代。
- 涉及跨项目 API、数据库、配置变更时，必须先更新根级文档，再落地代码。

### 3.1 Agent / Skill 约定

- 项目级 skill 统一放在根目录 `.agents/skills`，只承载本仓库特有的流程、文档入口和协作规则。
- 当前约定保留三类仓库专用 skill：
  - `aigateway-project-orientation`
    - 用于仓库导览、模块职责判断、落点选择和根文档入口说明。
  - `aigateway-dev-environment`
    - 用于本地开发环境构建、启动、redeploy 和端口暴露。
  - `aigateway-project-status`
    - 用于读取当前阶段、进行中任务、阻塞项、近期更新和下一步。
  - `aigateway-higress-context`
    - 用于说明 Higress 参数配置、`higress-config`、Helm values、Ingress/ConfigMap/WasmPlugin/McpBridge 等对象落点，以及 Portal/Console 通过 API、K8s 资源、服务发现与 Higress 交互的方式。
- 使用优先级约定：
  - 问“该看哪里 / 该改哪个模块”时，优先用 `aigateway-project-orientation`。
  - 问“怎么启动 / 怎么本地联调 / 用什么命令跑起来”时，优先用 `aigateway-dev-environment`。
  - 问“现在做到哪 / 当前阶段 / 下一步做什么”时，优先用 `aigateway-project-status`。
  - 问“Higress 怎么配 / Console 或 Portal 底层对应哪些 Higress 对象 / CRD 或服务发现应该改哪里 / AI Route、Provider、MCP、Service Source 底层怎么落”时，优先用 `aigateway-higress-context`。
- 这类项目级 skill 必须优先引用根目录文档和仓库内脚本，不应脱离仓库上下文给出泛化回答。
- 当根目录协作规则、开发入口或阶段状态结构发生稳定变化时，需要同步更新相关 skill。

## 4. 集成架构（当前）

### 4.1 Portal 与 Core

- `aigateway-portal/backend` 不再依赖 `aigateway-console`，改为直连 core 服务/缓存/数据库。
- 当前对接能力覆盖：
  - Portal 用户与 API Key 生命周期直接落库。
  - Usage/Consumption 可通过 Prometheus 直接拉取并汇总。

### 4.2 共库策略（Portal + Console）

- Portal 与 AIGateway Console 固定共用同一 PostgreSQL。
- Portal 后端数据库配置项目标准：
  1. `PORTAL_DB_*`
  2. 回退 `PORTAL_CORE_DB_*` / `HIGRESS_PORTAL_DB_*`（仅用于存量兼容，不再作为新配置路径）
- 共库变更约束：
  - 禁止无迁移方案的破坏性变更。
  - 表结构与索引调整必须有回滚方案。
  - 变更责任人、影响范围写入根级 `TODO.md`，落地结果写入根级 `Memory.md`。

## 5. 跨项目 API 与函数边界

### 5.1 API 边界

- Portal 对前端的业务接口保持 `/api/*` 路由兼容。
- Portal 对 core 资源的访问统一封装在 service/client，不在 Controller 层直接拼接远程请求。

### 5.2 函数职责边界（后端）

- Controller：参数绑定、鉴权入口、统一响应。
- Service：业务编排、事务控制、错误语义。
- DAO/Model：数据访问与对象映射（按生成代码规范维护）。
- Client：外部系统调用（Prometheus/第三方）与协议适配。

## 6. 文档更新约定

- 每次迭代都更新：
  - `Memory.md`：记录“改了什么、为什么改、结果如何”。
  - `TODO.md`：维护“剩余事项、优先级、责任归属”。
- 只有架构或契约变化时才更新：
  - `Project.md`。
- 若根目录文档结构或仓库级工作流已被 skill 显式依赖，也要同步检查 `.agents/skills` 中对应说明是否仍然准确。

## 7. 部署与开发模式基线（2026-03-22）

### 7.1 统一入口

- 根目录作为统一入口：
  - 启动脚本：`./start.sh`
  - 开发配置：`./helm/dev-mode.yaml`
  - 端口暴露脚本：`./scripts/port-forward-all.py`
- 统一使用父 Chart：`./helm/higress` 进行多子项目编排部署（根目录可直接执行 Helm 命令）。
- 兼容策略：旧路径 `higress/helm/higress` 暂时保留为回退入口，脚本默认优先根目录路径。

### 7.2 服务命名与启停约束

- `aigateway-console` 在父 Chart 中以 `alias: aigateway-console` 方式使用。
- 统一通过 `enabled` 进行服务启停：
  - `higress-core.enabled`
  - `aigateway-console.enabled`
  - `aigateway-portal.enabled`
- 本轮调整后不再保留旧兼容开关（按新配置执行）。

### 7.3 数据库归属与配置契约

- Portal/Console 共用的 PostgreSQL 由 `higress-core` 统一启动和管理。
- PostgreSQL 配置路径为：`higress-core.postgresql.*`。
- 关键字段：
  - `higress-core.postgresql.enabled`
  - `higress-core.postgresql.fullnameOverride`
- 集成场景下：
  - `aigateway-portal.database.driver=postgres`
  - `aigateway-portal.database.host=aigateway-core-postgresql-pgpool`
  - `aigateway-console.portalDatabase.driver=postgres`
  - `aigateway-console.portalDatabase.host=aigateway-core-postgresql-pgpool`

### 7.4 网络暴露策略

- `aigateway-portal` 默认对外端口为 `8081`，用于和 console 区分。
- 集成部署中 `aigateway-portal.ingress.enabled=false`，当前通过 Service + 本地端口转发访问。
- 开发模式由端口转发脚本自动暴露服务端口，并支持固定映射与跳过服务。

## 8. 关联文档

- Portal 架构设计：[`aigateway-portal/project.md`](./aigateway-portal/project.md)
- Portal 变更记录：[`aigateway-portal/memory.md`](./aigateway-portal/memory.md)
- Portal 待办清单：[`aigateway-portal/TODO.md`](./aigateway-portal/TODO.md)

## 9. 开发部署链路（2026-03-23 补充）

### 9.1 minikube 场景推荐链路

- 本地镜像闭环链路为：
  - 构建：`higress/helm/build-local-images.sh`
  - 加载：`minikube image load`
  - 部署：`helm upgrade --install`
  - 生效：`kubectl rollout restart + rollout status`
- 该链路由 `higress/helm/redeploy-minikube.sh` 统一封装。

### 9.2 根入口 start.sh 对齐策略

- `./start.sh dev`：
  - 在 `minikube` context 且无额外 helm 参数时，默认走 `redeploy-minikube.sh` 全流程。
  - 非 minikube 或显式关闭时，保持原 `helm upgrade + port-forward` 行为。
- `./start.sh dev-redeploy`：
  - 强制使用 minikube redeploy 全流程。

### 9.3 values 组合规则（dev + local）

- `start.sh` 在 redeploy 分支下会先合并：
  - 基础：`helm/higress/values-local-minikube.yaml`
  - 覆盖：`helm/dev-mode.yaml`
- 目的：同时继承本地镜像/服务编排设置与开发模式开关，减少两套配置漂移。

### 9.4 console 前端构建一致性保障

- `build-local-images.sh` 在构建 console 前强制清理：
  - `aigateway-console/frontend/.ice`
  - `aigateway-console/frontend/build`
  - `aigateway-console/backend/console/src/main/resources/static`
- 目标：降低旧静态产物残留导致的“前端未更新”假象。

## 10. 正式环境链路（2026-03-25 补充，k3d）

### 10.1 发布入口

- 正式环境（k3d）统一入口：
  - `./start.sh prod-redeploy`（推荐，强制全流程）
  - `./start.sh deploy-prod`（在 `k3d-*` context 且无额外 helm 参数时自动走全流程）
- 全流程脚本：
  - `higress/helm/redeploy-k3d.sh`
  - 包含：本地镜像构建、导入 k3d、Helm 发布、rollout 校验。

### 10.2 values 基线

- k3d 正式环境默认 values：
  - `helm/higress/values-production-k3d.yaml`
- 回退 values：
  - `helm/higress/values-production-gray.yaml`
- Portal 后端关键参数要求显式化：
  - `backend.keyAuthSyncEnabled=true`
  - `backend.usageSyncEnabled=true`
  - `backend.rechargeFallbackAvgCostPer1K`
  - 启用统计时必须配置 `backend.corePrometheusURL`（k3d 基线为 `/prometheus` 路径）。

### 10.3 运行约束

- k3d 发布前，`kubectl current-context` 必须与目标 `k3d` 集群一致。
- 脚本会执行 context/cluster 一致性校验，不允许在上下文不明确时继续发布。
- 若需要跳过某阶段，统一通过：
  - `PROD_REDEPLOY_SKIP_BUILD`
  - `PROD_REDEPLOY_SKIP_LOAD`
  - `PROD_REDEPLOY_SKIP_DEPLOY`

### 10.4 风险控制点

- 禁止仅做 `helm upgrade` 而不导入本地镜像进行正式验证，否则容易出现“代码已改、Pod仍跑旧镜像”。
- 若使用非 k3d values，请自行保证 Prometheus 地址与 o11y 开关一致，否则 Portal 统计/计费会无数据或报错。
