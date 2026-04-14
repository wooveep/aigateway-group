# AIGateway Group - 协作记忆

## 2026-04-09

### 本次目标

- 将第二轮模型资产 / AI 路由收口从“路由直接选绑定”修正为“路由按 Provider 选服务、按已发布绑定约束目标模型”。
- 把模型资产的能力字段也纳入系统预置口径，并为绑定创建补齐 Provider 模型目录下拉。

### 本次改动

- Console 后端新增 `GET /v1/ai/model-assets/options`，统一下发：
  - 模型资产 `模态 / 能力特性 / 请求类型` 预置选项
  - Provider 模型目录（按真实 `providerName` 返回）
- 模型资产页已改为：
  - 标签、模态、能力特性、请求类型全部走预置多选
  - 新建/编辑绑定时按 `Provider -> 模型目录` 联动选择 `modelId / targetModel`
  - 未配置目录的 Provider 仍允许手填，避免阻断存量接入
- AI 路由表单已改为：
  - 服务名称继续显示和提交 `provider`
  - 目标模型自动补全只来自该 Provider 下已发布绑定的 `targetModel`
  - 旧路由若引用未发布绑定或已下线 Provider，仍可回显和保存，但会提示当前候选集受限

### 验证结果

- `npm run build` 在 `higress-console/frontend` 通过。
- `./mvnw -q -pl console -am -DskipTests -Dpmd.skip=true compiler:compile` 在 `higress-console/backend` 通过。

### 注意点

- 后端 Provider 模型目录当前采用 Console 内置 catalog，不做数据库化管理；后续若要扩展，应优先收口到同一接口，不要回退到前端各页面硬编码。
- AI 路由已不再依赖 `higress.io/console-ai-binding-refs` 做新回显，但存量路由上可能仍残留该注解，当前实现会忽略并逐步自然淘汰。

## 2026-04-08

### 本次目标

- 为仓库补齐项目级 agent skill，降低“如何启动环境、如何看懂仓库、如何读当前状态”的重复沟通成本。
- 将这些 skill 的边界和维护责任写入根级团队约定，而不是只散落在 `.agents/skills` 目录中。

### 本次改动

- 新增项目级 skill：
  - `.agents/skills/aigateway-dev-environment`
    - 面向本地开发环境启动、镜像构建、minikube redeploy 和端口暴露。
    - 默认优先走 `scripts/aigateway-dev.py`、`scripts/port-forward-all.py`、`start.sh`。
  - `.agents/skills/aigateway-project-orientation`
    - 面向仓库导览、模块职责判断、根目录文档入口和改动落点选择。
  - `.agents/skills/aigateway-project-status`
    - 面向当前阶段、进行中任务、阻塞项、近期更新、里程碑状态和下一步判断。
- 为上述 skill 补齐了 `agents/openai.yaml` 元数据，方便在技能列表中识别和触发。
- 在 `Project.md` 新增“Agent / Skill 约定”：
  - 固定项目级 skill 存放位置为 `.agents/skills`
  - 固定三类问题的优先 skill：
    - 仓库导览：`aigateway-project-orientation`
    - 开发环境：`aigateway-dev-environment`
    - 阶段状态：`aigateway-project-status`
  - 明确根目录文档结构或开发工作流发生稳定变化时，需要同步更新 skill
- 在 `TODO.md`、`task.md` 回写 `P0-06`，将该项纳入根目录执行面板和当日更新。

### 验证结果

- 已核对三个项目级 skill 的 frontmatter、说明文本、默认提示和职责边界。
- 已确认 `aigateway-project-status` 的读取顺序与当前根目录文档结构一致：`task.md -> TODO.md -> roadmap.md -> Memory.md`。
- 已确认 `Project.md` 中的团队约定与 `.agents/skills` 下现有项目级 skill 一致，没有重复定义相互冲突的入口。

### 注意点

- 这些 skill 依赖根目录文档结构稳定；若未来调整 `task.md`、`TODO.md`、`roadmap.md` 的职责边界，需要同步修正 skill。
- 项目级 skill 只应承载仓库特有知识；通用技术栈能力仍优先复用已有通用 skill。

## 2026-03-26

### 本次目标

- 增加一个统一脚本，集中管理子项目镜像版本、构建本地镜像、并驱动 minikube 本地开发与更新。
- 避免继续手工分别修改多个 Helm values 文件，降低版本漂移和本地环境启动成本。

### 本次改动

- 新增统一版本清单：
  - `helm/image-versions.yaml`
  - 作为以下信息的单一来源：
    - `aigateway/controller/gateway/pilot/console/portal/plugin-server` 的 repository/tag
    - 默认构建组件列表
    - `releaseName / namespace`
    - minikube 默认参数（`profile / driver / cpus / memory / diskSize / addons`）
- 新增统一本地脚本：
  - `scripts/aigateway-dev.py`
  - 提供命令：
    - `show`
    - `sync`
    - `build`
    - `minikube-start`
    - `minikube-dev`
    - `minikube-tunnel`
- `sync` 行为：
  - 将中心版本定点同步到以下 Helm values：
    - `helm/dev-mode.yaml`
    - `higress/helm/higress/values-local-minikube.yaml`
    - `higress/helm/higress/values-production-k3d.yaml`
    - `higress/helm/higress/values-production-gray.yaml`
    - `higress/helm/core/values-production-gray.yaml`
    - `higress-console/helm/values-production-gray.yaml`
    - `aigateway-portal/helm/values.yaml`
  - 实现方式为“按路径更新标量值”，不整份重写 YAML，尽量保留现有注释和布局。
- minikube 流程收敛：
  - `minikube-dev`
    - `sync -> minikube start -> update-context -> start.sh dev-redeploy`
    - 适用于本地开发模式：`console/portal` 走 `port-forward`，`gateway` 走 `hostPort 80/443`
  - `minikube-tunnel`
    - `sync -> minikube start -> update-context -> redeploy-minikube.sh --values values-local-minikube.yaml`
    - 适用于 `LoadBalancer + minikube tunnel` 模式

### 验证结果

- `python3 -m py_compile scripts/aigateway-dev.py` 通过。
- `./scripts/aigateway-dev.py --help` 通过。
- `./scripts/aigateway-dev.py show` 通过。
- `./scripts/aigateway-dev.py sync --check` 通过，当前 Helm values 已与中心版本一致。

### 注意点

- `helm/image-versions.yaml` 现在是本地镜像版本的首选修改入口；改版本后优先执行 `./scripts/aigateway-dev.py sync`。
- `images.aigateway` 目前仍会同步到 `aigateway-console.certmanager.image.*`，这是为了兼容现有 `build-local-images.sh` 对该值的读取约定。
- 这轮只验证了脚本语法、帮助输出和版本同步检查；没有实际触发一次完整镜像构建，也没有实际跑一轮 `minikube start / tunnel / redeploy`。

## 2026-03-25

### 本次目标

- 补齐正式环境（k3d）的一键发布链路，避免仅 `helm upgrade` 导致本地新镜像未生效。
- 收敛正式环境 Helm 配置，显式固定 Portal 关键后端参数（KeyAuth 同步、Usage 同步、Prometheus 地址）。
- 将上述结构变化同步到统一入口脚本与文档。

### 本次改动

- 新增 k3d 正式发布脚本：
  - `higress/helm/redeploy-k3d.sh`
  - 流程：`build-local-images -> k3d image import -> helm upgrade --install -> rollout restart/status`。
  - 支持参数：`--values/--cluster/--components/--skip-build/--skip-load/--skip-deploy`。
  - 自动从 `kubectl current-context` 推断 `k3d` 集群；若不一致会阻断并提示切换 context。
- 统一入口脚本增强：
  - `start.sh`
  - 新增 `prod-redeploy` 命令（强制 k3d 全流程）。
  - `deploy-prod` 在 `k3d-*` context 且无额外 helm 参数时，自动走 k3d 全流程。
  - 新增变量：
    - `PROD_VALUES_FILE`
    - `PROD_USE_K3D_REDEPLOY`
    - `PROD_REDEPLOY_SKIP_BUILD`
    - `PROD_REDEPLOY_SKIP_LOAD`
    - `PROD_REDEPLOY_SKIP_DEPLOY`
    - `K3D_CLUSTER`
- Helm values 收敛：
  - 新增 `higress/helm/higress/values-production-k3d.yaml`
    - 默认启用 `global.o11y.enabled=true`。
    - Portal 显式配置：
      - `backend.corePrometheusURL=http://aigateway-console-prometheus:9090/prometheus`
      - `backend.usageSyncEnabled=true`
      - `backend.keyAuthSyncEnabled=true`
      - `backend.rechargeFallbackAvgCostPer1K=0.02`
  - 更新 `higress/helm/higress/values-production-gray.yaml`
    - 显式补齐 Portal 后端关键同步参数（usage/key-auth/fallback）。
- 文档更新：
  - `helm/README.md` 增加 k3d 正式环境说明与 `prod-redeploy` 使用方式。

### 验证结果

- `bash -n start.sh` 通过。
- `bash -n higress/helm/redeploy-k3d.sh` 通过。
- `./start.sh help` 已展示 `prod-redeploy` 与新增环境变量说明。
- `higress/helm/redeploy-k3d.sh --help` 已展示参数说明。

### 注意点

- `deploy-prod` 自动切换到 k3d 全流程的前提：
  - 当前 context 必须是 `k3d-*`；
  - 且命令不带额外 helm 参数。
- `redeploy-k3d.sh` 会校验 context 与 `--cluster` 一致，不一致会直接退出，避免错集群发布。
- 若沿用 `values-production-gray.yaml` 且未启用 o11y，Portal 不会有可用 Prometheus 指标源；要展示统计/计费，优先使用 `values-production-k3d.yaml` 或显式开启 o11y 并配置 `corePrometheusURL`。
- 生产链路建议优先 `prod-redeploy`，避免“镜像已构建但未导入集群”导致旧版本继续运行。

### 会话补充（Helm 暴露策略与本地集群规范收敛）

#### 现象

- `console` 的 chart 之前会在本地集群直接占用宿主机 `8080`，容易与 `svc port-forward` 冲突。
- `gateway` 的 `hostPort` 之前跟 `global.local` 绑定，导致 `values-local-minikube.yaml` 在 `minikube tunnel` 场景下同时出现：
  - `LoadBalancer`
  - `hostPort 80/443`
- `start.sh dev` 在 `minikube` 上还会叠加 `values-local-minikube.yaml + helm/dev-mode.yaml`，暴露模型不够直观。
- 直接运行 `helm template` / `./start.sh deploy` 时，如果未先刷新父 chart 依赖包，可能继续使用旧的 vendored subchart 模板。

#### 本次改动

- `higress-console/helm/templates/deployment.yaml`
  - 去掉 `console` 的 `hostPort: 8080`，保留容器内 `8080` 与 `Service` 暴露。
- `higress/helm/core/values.yaml`
  - 新增显式开关 `gateway.hostPort.enabled`，默认 `false`。
- `higress/helm/core/templates/_pod.tpl`
  - `gateway` 的 `containerPort 80/443` 改为所有 profile 都显式声明。
  - `hostPort` 仅在 `gateway.hostPort.enabled=true` 时附加。
- `helm/dev-mode.yaml`
  - `higress-core.gateway.service.type=ClusterIP`
  - `higress-core.gateway.hostPort.enabled=true`
  - `dev.portForward.includeServices` 固定为：
    - `aigateway-console`
    - `aigateway-portal`
  - 固定本地端口：
    - `aigateway-console:8080`
    - `aigateway-portal:8081`
- `higress/helm/higress/values-local-minikube.yaml`
  - 明确 `gateway.service.type=LoadBalancer`
  - 明确 `gateway.hostPort.enabled=false`
  - 语义变为：用于 `minikube tunnel`，所有对外入口通过 `LoadBalancer` 暴露。
- `higress/helm/higress/values-production-k3d.yaml`
  - 明确 `gateway.service.type=LoadBalancer`
  - 明确 `gateway.hostPort.enabled=false`
- `higress/helm/higress/values-production-gray.yaml`
  - 同步显式声明 `gateway.service.type=LoadBalancer`
  - 同步显式声明 `gateway.hostPort.enabled=false`
- 新增校验脚本：
  - `scripts/validate-helm-exposure.py`
  - 固化检查以下 profile 的外部暴露规则：
    - `dev`
    - `minikube`
    - `minikube-dev`（`values-local-minikube + dev-mode` 叠加场景）
    - `k3d`
    - `prod-gray`
- `start.sh`
  - `HELM_DEPENDENCY_BUILD` 默认改为 `true`，避免父 chart 使用过期 vendored subchart。

#### 当前规则

- `dev-mode`
  - `console/portal`：`ClusterIP + port-forward`
  - `gateway`：`ClusterIP + hostPort 80/443`
- `values-local-minikube`
  - `console/portal/gateway`：`LoadBalancer`
  - 不使用 `hostPort`
- `values-production-k3d` / `values-production-gray`
  - `console/portal/gateway`：`LoadBalancer`
  - 不使用 `hostPort`

#### 验证结果

- `./scripts/validate-helm-exposure.py` 通过。
- `python3 -m py_compile scripts/port-forward-all.py scripts/validate-helm-exposure.py` 通过。
- `kubectl apply --dry-run=client --validate=false` 针对以下渲染结果均通过：
  - `helm/dev-mode.yaml`
  - `values-local-minikube.yaml`
  - `values-production-k3d.yaml`
  - `values-production-gray.yaml`

## 2026-03-23

### 本次目标

- 将 `build-local-images.sh` 中父 values 的 console 键从 `higress-console` 对齐为 `aigateway-console`。
- 联动修复 `redeploy-minikube.sh` 的同类键读取，并修复 portal 镜像键位不一致问题。
- 将父 Chart 的可用入口迁移到根目录 `./helm/higress`，保证在 `aigateway-group` 根目录可直接执行 Helm 命令。

### 本次改动

- Console/Portal 键读取修复：
  - `higress/helm/build-local-images.sh`
    - 父 values 读取改为 `aigateway-console.image.*`。
    - `certmanager` 对齐校验改为 `aigateway-console.certmanager.*`。
    - portal 镜像读取支持 `aigateway-portal.backend.image.*` 优先，回退 `aigateway-portal.image.*`。
  - `higress/helm/redeploy-minikube.sh`
    - console 镜像读取改为 `aigateway-console.image.*`。
    - portal 镜像读取增加 `backend.image -> image` 回退。
- 父 Chart 入口迁移到根目录：
  - 新建根目录父 Chart：`helm/higress`（从 `higress/helm/higress` 复制并作为根入口）。
  - `helm/higress/Chart.yaml` 的 `file://` 依赖路径改为相对根目录可用：
    - `file://../../higress/helm/core`
    - `file://../../higress-console/helm`
    - `file://../../aigateway-portal/helm`
  - 更新并刷新 `helm/higress/Chart.lock`。
- 脚本入口统一到根目录优先：
  - `start.sh`：默认 `CHART_DIR` 优先 `./helm/higress`，不存在时回退旧路径；并对 `CHART_DIR` 做 `pwd -P` 真实路径解析。
  - `higress/helm/redeploy-minikube.sh`：默认 `CHART_DIR` 同样改为根目录优先 + 旧路径回退，并做真实路径解析。
  - `higress/helm/build-local-images.sh`：默认 `WRAPPER_VALUES_FILE` 优先 `./helm/higress/values-production-gray.yaml`，不存在时回退旧路径。
  - `higress-console/helm/upgrade-higress-console-image.sh`：`HIGRESS_CHART_DIR` 改为根目录优先 + 旧路径回退，并做真实路径解析。
- 文档更新：
  - `helm/README.md` 增加根目录 `./helm/higress` 作为 Helm Chart 入口说明。

### 验证结果

- 语法检查通过：
  - `bash -n start.sh`
  - `bash -n higress/helm/build-local-images.sh`
  - `bash -n higress/helm/redeploy-minikube.sh`
  - `sh -n higress-console/helm/upgrade-higress-console-image.sh`
- Console/Portal 脚本验证通过：
  - `higress/helm/build-local-images.sh --dry-run --components console` 成功，`console` 镜像读取正常。
  - `higress/helm/build-local-images.sh --dry-run --components portal` 成功，portal 镜像可由 `aigateway-portal.image.*` 解析。
  - `higress/helm/redeploy-minikube.sh --skip-build --skip-load --skip-deploy` 成功，默认 values 路径已指向根目录 `helm/higress`。
- 根目录 Chart 验证通过：
  - `helm dependency update ./helm/higress` 成功。
  - `helm dependency build ./helm/higress` 成功。
  - `helm template aigateway ./helm/higress -f ./helm/higress/values-local-minikube.yaml` 成功。

### 决策记录

- 根目录 `./helm/higress` 作为统一父 Chart 入口，脚本默认优先使用该路径。
- 旧路径 `higress/helm/higress` 暂时保留作为兼容回退，不在本轮删除。
- portal 镜像键位采用兼容读取策略，避免新旧 values 结构差异导致构建脚本失败。

### 当前状态

- 父 Chart 已可在根目录直接执行 Helm 依赖更新、构建与模板渲染。
- 关键部署/构建脚本已收敛到根目录优先策略。
- console/portal 键读取不一致导致的本地构建失败问题已闭环。

### 会话补充（start.sh dev 与 redeploy-minikube 差异）

#### 现象

- 使用 `./start.sh dev` 启动开发环境时，console 偶发出现前端代码未更新。
- 使用 `higress/helm/redeploy-minikube.sh` 部署时，同一版本行为正常。

#### 根因确认

- `higress-console/backend/build.sh` 的 `mvnw clean package` 会触发 `frontend-maven-plugin`，实际执行了：
  - `npm install`
  - `npx browserslist@latest --update-db`
  - `npm run build`
- 主要差异不在“是否编译前端”，而在“是否执行本地镜像完整链路”：
  - `start.sh dev`（原逻辑）仅 `helm upgrade + port-forward`。
  - `redeploy-minikube.sh` 包含 `build-local-images + minikube image load + rollout restart`。

#### 本次改动

- `higress/helm/build-local-images.sh`
  - `build_console()` 增加前置清理，避免旧静态资源残留：
    - `higress-console/frontend/.ice`
    - `higress-console/frontend/build`
    - `higress-console/backend/console/src/main/resources/static`
  - 构建日志增加 `console dir` 输出，便于确认实际构建路径。
- `start.sh`
  - 新增 minikube 场景下的 redeploy 收敛逻辑：
    - `dev` 命令在 `minikube` context 且无额外 helm 参数时，默认走 redeploy 全流程。
    - 新增 `dev-redeploy` 命令，强制走 redeploy。
  - redeploy 前合并 values：
    - base: `helm/higress/values-local-minikube.yaml`
    - overlay: `helm/dev-mode.yaml`
  - 新增开关：
    - `DEV_USE_MINIKUBE_REDEPLOY`
    - `DEV_REDEPLOY_SKIP_BUILD`
    - `DEV_REDEPLOY_SKIP_LOAD`
    - `DEV_REDEPLOY_SKIP_DEPLOY`
    - `BUILD_COMPONENTS`
    - `MINIKUBE_PROFILE`

#### 验证结果

- `bash -n start.sh`、`bash -n higress/helm/build-local-images.sh` 通过。
- `higress/helm/build-local-images.sh --dry-run --components console` 已显示前置清理步骤与 `console dir`。
- `start.sh help` 已包含 `dev-redeploy` 与新增环境变量说明。

#### 注意点

- `./start.sh dev --help` 不会进入帮助分支，会按 `dev` 执行部署；查看帮助请使用 `./start.sh help` 或 `./start.sh --help`。

## 2026-03-22

### 本次目标

- 在 `aigateway-group` 根目录建立跨子项目协作文档入口。
- 完成 Helm/启动入口收敛，支持按服务开关进行本地开发调试。
- 将 MySQL 归属统一到 `higress-core`，并移除旧兼容路径。

### 本次改动

- 新增根级协作文档：
  - [`Project.md`](./Project.md)
  - [`Memory.md`](./Memory.md)
  - [`TODO.md`](./TODO.md)
- 新增并落地统一入口：
  - `./start.sh`（`dev/deploy/deploy-prod/port-forward/status/down`）
  - `./helm/dev-mode.yaml`（统一开发模式配置）
  - `./scripts/port-forward-all.py`（自动端口暴露）
  - `./helm/README.md`（使用说明）
- 父 Chart 与服务命名调整：
  - `higress/helm/higress/Chart.yaml` 引入 `alias: aigateway-console`。
  - 统一使用 `aigateway-console.enabled`，去掉 `higress-console.enabled` 兼容条件。
- MySQL 归属调整到 `higress-core`：
  - `higress/helm/core/Chart.yaml` 改为 `condition: mysql.mysql.enabled`。
  - `higress/helm/core/values.yaml` 与 `higress-core/charts/mysql/*` 全量切换到新结构 `mysql.mysql.*`。
  - `helm/dev-mode.yaml`、`values-local-minikube.yaml`、`values-production-gray.yaml` 都改为 `higress-core.mysql.mysql.*`，并统一使用 `mysql-server`。
- Portal 与 Console 对齐：
  - `aigateway-portal` 对外端口统一为 `8081`（与 console 区分）。
  - 集成 values 中 `aigateway-portal.mysql.enabled=false`，数据库 host 指向 `mysql-server`。
  - `aigateway-portal` 启动配置入口风格与 `aigateway-console` 一致（`name/image/service/ingress`）。
- Ingress 策略调整：
  - `aigateway-portal` 在集成场景默认 `ingress.enabled=false`，改为端口区分访问。
  - `aigateway-portal/helm/values.yaml` 默认也改为 ingress 关闭。
- 端口转发稳定性修复：
  - 修复 `./start.sh dev` 首次部署时因 Pod `Pending` 导致 `port-forward` 直接退出的问题。
  - `scripts/port-forward-all.py` 增加 endpoint 就绪等待与超时跳过机制。
  - 新增配置 `dev.portForward.waitReadySeconds`（默认 `180`）。

### 问题与修复

- 问题：`./start.sh dev` 首次安装后立刻转发，`aigateway-console` 还未就绪，日志报错 `unable to forward port because pod is not running. Current status=Pending`，导致流程退出。
- 修复：端口转发脚本在每个 service 启动转发前等待 ready endpoints；超时后跳过该 service 并给出 warning，不会把瞬时未就绪当成全局致命错误。

### 验证结果

- `helm dependency update higress/helm/higress` 成功，`Chart.lock` 已刷新。
- `helm lint` 通过：
  - `higress/helm/core`
  - `higress/helm/higress`（dev/local/prod values）
  - `aigateway-portal/helm`
- `helm template` 验证通过：
  - local/prod/dev 渲染中不再生成 `aigateway-portal` 的 Ingress 资源。
  - `higress-core` 使用 `higress-core.mysql.mysql.*` 可正确渲染 `mysql-server`。
- `port-forward-all.py` `dry-run` 与短时实跑验证通过，已进入 `[READY]` 状态并稳定运行。

### 决策记录

- 根级文档用于记录跨项目协作与契约，不替代子项目文档。
- `aigateway-portal` 与 `aigateway-console` 的架构/契约变更必须同步更新根级文档。
- 本轮明确“不做兼容”：按新配置路径与新启停键执行。
- Portal 集成部署默认不启用 ingress，当前通过端口区分 + 本地转发进行调试。

### 当前状态

- 统一开发模式已可用，支持按服务开关启停与端口暴露。
- MySQL 已归并到 `higress-core`，Portal/Console 共库路径已统一。
- 剩余工作进入自动化验证、文档收敛与遗留兼容字段清理阶段。

## 2026-04-09：AI 路由 / 模型资产 / AI 脱敏收口

### 本次改动

- Console `AI Route` 表单不再直接从 `Provider` 选“目标AI服务”，改为从已发布 `model_binding` 选择；提交给网关时仍写回运行时兼容的 `provider + modelMapping`。
- 为支持 AI 路由编辑回显，新增自定义注解 `higress.io/console-ai-binding-refs`，仅用于 Console 记录 upstream/fallback 对应的绑定引用。
- 模型资产标签改为系统预置白名单：`旗舰 / 高性价比 / 推理 / 长上下文 / 视觉 / 多模态 / 代码 / Embedding / 图像生成 / 语音 / 函数调用 / 结构化输出`。
- `asset_grant` 新增 `user_level` 主体，模型绑定授权从 `consumer + department` 扩展为 `consumer + department + user_level`。
- Portal 模型广场可见性过滤已同步支持 `user_level`，命中任一 grant 即可见；无 grant 时仍公开。
- AI 脱敏规则 JDBC 服务新增签名去重、启动期历史重复清理和唯一索引，后续保存同签名规则会合并到同一条 DB 记录。
- Route / AI Route / MCP 的等级授权语义统一修正为“高等级自动拥有低等级权限”。

### 验证结果

- `npm run build`：`higress-console/frontend` 通过。
- `./mvnw -q -pl console -am -DskipTests -Dpmd.skip=true compiler:compile`：`higress-console/backend` 通过。
- `go test ./...`：`aigateway-portal/backend` 通过。

### 决策记录

- 模型绑定授权与 AI 路由授权继续保留两层职责，不做合并：
  - 模型绑定授权负责模型可见性和后续模型范围约束。
  - AI 路由授权负责运行时请求准入。
- 本轮不改 AI 路由运行时协议，绑定引用只保存在 Console 自定义注解中。
