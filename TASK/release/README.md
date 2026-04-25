# 发布与部署任务台账

> 文档职责：本目录只负责 release bundle、部署目标、HA、发布回归和验收台账。  
> 日常产品研发状态不写在这里，统一回根目录 `task.md` / `TODO.md` / `Memory.md`。

## 状态约定

- `todo`：尚未开始
- `doing`：正在进行
- `done`：已完成
- `blocked`：被外部条件阻塞

## 阶段顺序

1. `P0-release-baseline.md`
2. `P1-release-bundle-shell-foundation.md`
3. `P2-release-deploy-targets.md`
4. `P3-dataplane-ha-and-upstream-lb.md`
5. `P4-redis-ha-and-postgresql-platform.md`
6. `P5-console-postgresql-cutover.md`
7. `P6-portal-postgresql-cutover.md`
8. `P7-e2e-validation-and-docs.md`

## 统一要求

- 每阶段都要补充“验收点”和“测试”。
- 每阶段完成后都要更新本台账的“当前进度 / 当前焦点 / 最近更新”。
- 变更脚本入口、Helm values、镜像清单、依赖 chart、应用数据库配置或发布文档时，需要同步更新对应阶段文档。
- 发布链路坚持纯 Shell，不引入 Python 作为发布入口依赖。
- 发布数据库主线固定为 PostgreSQL，默认内置 pgvector；本轮不包含 MySQL 到 PostgreSQL 的存量迁移工具。

## 当前进度

- `P0`：done
- `P1`：done
- `P2`：done
- `P3`：done
- `P4`：done
- `P5`：done
- `P6`：done
- `P7`：doing

## 当前焦点

- 主阶段：`P7`
- 当前重点：
  - 将 `./start.sh test --stage unit|integration|e2e|acceptance|release` 固化为发布前统一闸门。
  - 完成 release bundle 的 dry-run / 模板渲染 / PostgreSQL smoke 回归记录。
  - 在具备 `k3d` 和可推送 registry 的环境补齐完整端到端发布验收。
  - 将 `1.1.0` 正式版本口径、bundle 命名与正式交付文档统一收口。

## 最近更新

- 已补强 release 首启顺序与恢复口径：Console / Portal Helm Deployment 新增 `wait-for-portal-db` initContainer，先等待 PostgreSQL ready；Portal 进程内会继续重试数据库/bootstrap 初始化，Console `portaldb` 健康检查也会在数据库恢复后重新探测并清除启动期旧错误，避免 `Portal database is unavailable` 只能靠删 Pod 恢复。
- 已补强 Portal 对 Redis runtime 的恢复口径：账单 `billing` consumer loop 改为断线后持续重连，并在定时同步阶段重新发现 `ai-quota` amount bindings；Redis 在启动窗口稍晚就绪时，不再因为首轮失败而永久丢消费链路。
- 已为新环境部署链路补充显式数据库初始化阶段：`./start.sh release-deploy` 在 Helm `--wait` 后会依次执行 Portal `db-init` 与 Console `portaldb-init`，避免全新 PostgreSQL 环境把共享表 / Console 自有表初始化推迟到运行时首个请求；legacy 数据迁移不再混入该阶段。
- 已在 `192.168.42.200` 的干净 Ubuntu 24.04.3 LTS 环境完成 `1.1.0` k3d 实机部署验收；过程记录见 `docs/release/1.1.0/install-192.168.42.200.md`。
- 已补齐正式部署域名配置契约：标准 K8S 读取 `aigateway-system/aigateway-cluster-domain`，新建 k3d 通过 `./start.sh release-k3d-cluster --base-domain <domain>` 写入，后续通过 `./start.sh release-deploy --base-domain <domain>` 修改 Console / Portal Ingress 域名。
- 已将 release 默认 profile 调整为 `standard`，用于单节点 / 资源受限 k3d；`ha` profile 仅在显式指定时启用多副本、PostgreSQL 3 实例和 Redis replication。
- 已将 `standard` profile 默认启用内置监控，离线 bundle 已包含 Grafana / Prometheus / Loki / Promtail；`192.168.42.200` 最新干净安装为 Helm revision `1`，并验证 Console Dashboard 返回 `builtIn: true`。
- 已补 release standard profile 的 Portal Prometheus 注入：`aigateway-portal.backend.corePrometheusURL` 固定为 `http://aigateway-console-prometheus:9090/prometheus`，避免 AI 监控面板 / 用量统计在新环境因未配置指标源而为空。
- 已补 release profile 的普通 Service cluster 下发：`global.onlyPushRouteCluster=false`，避免数据面访问 `redis-server-master.<namespace>.svc.cluster.local` 时因未推送 outbound cluster 触发 Wasm Redis `bad argument`。
- 已新增 Ubuntu 24.04 离线 k3d 一键安装入口 `install-k3d-offline.sh`，并在再次重置后的 `192.168.42.200` 干净 Ubuntu 24.04.3 LTS 上完成 runtime 离线安装、单节点 k3d 创建和 Helm revision `1` 部署验收。
- 已修复 release standard profile 的 Redis standalone 地址与升级覆盖：`higress-config` 渲染 `redis-server-master.aigateway-system.svc.cluster.local:6379`，Helm 模板使用 `mergeOverwrite` 让新 release values 覆盖旧 ConfigMap 字段。
- key-auth 投影已修复为非全局认证口径：Portal 创建 / 更新 `key-auth.internal` 时写入 `global_auth=false` 和 consumers，Console 仅在业务路由上写 `matchRules.allow`，避免新环境无 AI 路由时持续报 `key-auth wasmplugin not found` 或全局拦截 Console / Portal Ingress。
- 本次实机部署补充了无互联网场景必须携带的运行时镜像集合，并记录 `k3d image import` 在 Docker 29 下需要回退到逐节点 `ctr images import` 的 caveat。
- 根级 `TASK/release/` 已收口为发布与部署改造的唯一任务台账。
- 已确定阶段顺序为 `P0 -> P1 -> P2 -> P3 -> P4 -> P5/P6 -> P7`。
- 已落下发布骨架：
  - `./scripts/release-build.sh`
  - `./scripts/release-deploy.sh`
  - `./scripts/release-k3d-cluster.sh`
  - `./scripts/test.sh`
  - `./start.sh release-build`
  - `./start.sh release-deploy`
  - `./start.sh release-k3d-cluster`
  - `./start.sh test --stage <...>`
- 已完成：
  - bundle 输出目录与镜像 `tar` 元数据
  - `k3d` / 通用 `k8s` 部署脚本接口
  - 数据面多副本与对上游 API 的多副本负载模板
  - Redis HA
  - PostgreSQL HA + pgvector 基础接入
- 新增完成项：
  - `console` 侧补齐 PostgreSQL rebind driver，并清理 portal store / platform state store / membership upsert 的 MySQL 专用 SQL。
  - `portal` 侧共享 schema、迁移器、账单投影、组织与模型目录 upsert 已切到 PostgreSQL 兼容语义。
  - 新增 PostgreSQL 容器烟测，覆盖 console portaldb 迁移链路和 portal 读取 shared schema 链路。
  - 新增仓库级测试闸门与 Chrome DevTools 验收模板：`unit / integration / e2e / acceptance / release` 已通过 `./start.sh test` 收口。
  - `helm/README.md` 与当前 agent skill 已同步发布回归命令清单，并移除过期的 PostgreSQL 兼容性说明。
  - `P7` 已补齐当前 smoke 记录：`show / sync --check / test gate / release-build --dry-run / helm template / k8s release-deploy --dry-run / PostgreSQL smoke`。
  - 已确认 `release-build --skip-build` 对本地 dev tag 镜像有前置依赖；当镜像未就绪时，bundle 会在 `docker save` 阶段失败。
