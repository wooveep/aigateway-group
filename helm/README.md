# AIGateway Group Helm & Dev Mode

正式交付文档请优先查看：

- `../docs/release/1.0.0/release-notes.md`
- `../docs/release/1.0.0/image-bundle.md`
- `../docs/release/1.0.0/deployment-guide.md`

当前正式发布版本口径固定为 `1.0.0`。  
仓库管理的一方镜像统一使用 `1.0.0`，第三方依赖镜像保持上游版本并通过 bundle / Helm values 锁定。

推荐入口与兼容入口：

- 推荐高层入口：`./start.sh`
- 开发配置：`./helm/dev-mode.yaml`
- 镜像版本清单：`./helm/image-versions.yaml`
- Helm Chart 入口：`./helm/higress`（软链接，真源目录为 `./higress/helm/higress`）
- 端口暴露脚本：`./scripts/port-forward-all.sh`

`./helm/image-versions.yaml` 是本地开发入口的单一事实源，统一维护：

- 默认 `chartDir`
- 默认 `devConfigFile`
- 默认 `localValuesFile`
- 默认 `releaseName / namespace`
- 默认 `buildComponents`
- 默认 minikube profile / resources / addons
- 本地镜像 repository / tag

`./helm/dev-mode.yaml` 负责 dev 模式的启用项、端口转发和本地暴露行为。  
`./higress/helm/higress/values-local-minikube.yaml` 负责 minikube LoadBalancer / tunnel 暴露模型。

## 首次冷启动

先看当前统一配置：

```bash
./start.sh show
```

如果需要先校验 Helm values 是否已经和中心版本一致：

```bash
./start.sh sync --check
```

## 常用命令

```bash
# 查看当前统一版本清单和固定端口映射
./start.sh show

# 将中心版本同步回各个 Helm values
./start.sh sync

# 仅检查是否有 drift
./start.sh sync --check

# 本地构建所有镜像
./start.sh build

# 生成发布 bundle（chart tgz + images tar + values + deploy.sh）
./start.sh release-build

# 执行仓库级测试闸门
./start.sh test --stage unit
./start.sh test --stage integration
./start.sh test --stage e2e
./start.sh test --stage acceptance
./start.sh test --stage release

# 从 bundle 部署到 k8s / k3d
./start.sh release-deploy --target k8s --registry registry.example.com/team

# 只构建部分组件
./start.sh build --components controller,gateway,console

# 启动 minikube（使用 image-versions.yaml 中的 profile/resources/addons）
./start.sh minikube-start

# 推荐本地 minikube 开发模式：
# sync + minikube start + redeploy(dev profile) + port-forward
./start.sh minikube-dev

# minikube LoadBalancer 模式：redeploy(local-minikube profile) + tunnel
./start.sh minikube-tunnel --start-tunnel

# 兼容入口：历史命令仍可继续使用
./start.sh dev
./start.sh dev-redeploy

# 只部署（默认使用 ./helm/dev-mode.yaml）
./start.sh deploy

# 生产灰度 values 部署
./start.sh deploy-prod

# 生产(k3d)全流程：构建镜像 + 导入集群 + helm 发布 + rollout 检查
./start.sh prod-redeploy

# 仅做端口暴露
./start.sh port-forward

# 查看状态 / 卸载
./start.sh status
./start.sh down
```

## 重新构建路径

- `./start.sh sync`
  - 只同步 `image-versions.yaml` 到各个 Helm values
  - 不构建，不部署
- `./start.sh build`
  - 默认先执行 sync
  - 再构建本地镜像
- `./start.sh minikube-dev`
  - 默认执行：依赖检查 -> sync -> minikube start -> redeploy(dev profile) -> port-forward
  - 会自动将 `console.<baseDomain>`、`portal.<baseDomain>`，以及 `aigateway-system` 中 `domain-*` ConfigMap 声明的 gateway 业务域名写入 `/etc/hosts`（不包含通配符域名），让 `api.ai.local` 这类域名直接落到当前 minikube gateway `80/443`
- `./start.sh minikube-tunnel`
  - 默认执行：依赖检查 -> sync -> minikube start -> redeploy(local-minikube profile)
  - `--start-tunnel` 时附带执行 `minikube tunnel`
- `./start.sh release-build`
  - 生成发布 bundle：chart tgz、镜像 tar、values、`images.lock`、`SHA256SUMS`、`deploy.sh`
- `./start.sh release-deploy`
  - 从 bundle 部署到 `k3d` / 通用 `k8s`
  - `--target k3d`：`docker load + k3d image import + helm upgrade`
  - `--target k8s`：`docker load + docker tag/push + helm upgrade`

## 发布 bundle

发布值文件：

- `./higress/helm/higress/values-release-base.yaml`
- `./higress/helm/higress/values-release-ha.yaml`
- `./higress/helm/higress/values-release-upstreams.yaml`

发布 bundle 默认目录：

```text
out/release/aigateway-1.0.0/
  charts/
  images/
  values/
  metadata/
  deploy.sh
```

说明：

- `./start.sh release-build` 会先构建本地镜像，再导出 `images/*.tar`。
- 如果显式使用 `--skip-build`，则要求渲染出的镜像已经存在于本机；对带本地 dev tag 的镜像，脚本不会自动帮你补构建。

上游负载值入口是 `release.upstreams[]`，支持：

- `k8sService`
- `external`
- `consistentHash`
- `roundRobin`
- `leastRequest`

## 发布与回归命令清单

推荐按下面顺序做发布回归：

```bash
# 1. 查看当前统一配置
./start.sh show

# 2. 检查 manifest -> values 是否有 drift
./start.sh sync --check

# 3. 生成 release bundle
./start.sh release-build --bundle-name aigateway-1.0.0

# 4. k8s 目标 dry-run
./start.sh release-deploy \
  --target k8s \
  --bundle-dir out/release/aigateway-1.0.0 \
  --registry registry.example.com/team \
  --dry-run

# 5. k3d 目标 dry-run
./start.sh release-deploy \
  --target k3d \
  --bundle-dir out/release/aigateway-1.0.0 \
  --cluster <k3d-cluster> \
  --dry-run

# 6. Helm 渲染检查：HA + upstream 负载模板
helm template aigateway ./helm/higress \
  -f ./higress/helm/higress/values-release-base.yaml \
  -f ./higress/helm/higress/values-release-ha.yaml \
  -f ./higress/helm/higress/values-release-upstreams.yaml

# 7. PostgreSQL smoke
cd ./aigateway-console/backend
GOTOOLCHAIN=auto go test ./utility/clients/portaldb \
  -run TestEnsureSchemaAndMigrateLegacyDataAgainstPostgres -count=1

cd ../../aigateway-portal/backend
GOTOOLCHAIN=auto go test ./internal/service/portal \
  -run TestPortalReadsConsoleWrittenSharedSchemaRowsOnPostgres -count=1
```

## Portal OIDC SSO 部署补充

- 若启用 Portal OIDC SSO，需在 Helm values 中显式设置 `aigateway-portal.backend.publicBaseURL`。
- 该值会注入为 `PORTAL_PUBLIC_BASE_URL`，Portal 后端据此生成稳定的 `/api/auth/sso/callback` 地址。
- 这里应填写用户浏览器真实访问的 Portal 外部基地址，而不是集群内 Service 地址；否则 OIDC Provider 回调会落到错误地址。
- OIDC 的 `issuer/client/scopes/claim mapping` 仍由 Console `/system` 页面写入共享库 `portal_sso_config`，不走 Helm values。

## fresh tags 规则

- `console` 与 `portal` 在 `build`、`minikube-dev`、`minikube-tunnel` 中默认自动刷新 dev tag
- 其他组件只有显式使用 `--fresh-tags` 时才会刷新
- 可用 `--stamp YYYYMMDDHHMMSS` 指定固定时间戳

示例：

```bash
./start.sh build --components console
./start.sh minikube-dev --components controller,gateway --fresh-tags
./start.sh sync --components portal --fresh-tags --stamp 20260417093000
```

## 暴露模型

- `./start.sh minikube-dev` / `./helm/dev-mode.yaml`
  - `aigateway-console` / `aigateway-portal` / `grafana` / `prometheus` / `loki` / `controller` / `plugin-server` / `postgresql` / `redis`
    通过 `./scripts/port-forward-all.sh` 固定转发到本机
  - `aigateway-gateway`
    `ClusterIP + hostPort`，本机直接监听 `80/443`
- `./higress/helm/higress/values-local-minikube.yaml`
  - 面向 `minikube tunnel`
  - `aigateway-console` / `aigateway-portal` / `aigateway-gateway` 通过 `LoadBalancer` 暴露
- `./higress/helm/higress/values-production-k3d.yaml` / `values-production-gray.yaml`
  - `aigateway-console` / `aigateway-portal` / `aigateway-gateway` 通过 `LoadBalancer` 暴露

## 通过 YAML 选择不启动服务

编辑 `./helm/dev-mode.yaml`：

```yaml
higress-core:
  enabled: true
aigateway-console:
  enabled: true
aigateway-portal:
  enabled: true
```

将对应 `enabled` 改为 `false` 后，重新执行：

```bash
./start.sh minikube-dev
```

## 数据库与缓存

当前环境统一使用共享数据库与缓存：

- 本地开发
  - 默认使用共享 `PostgreSQL + Redis`
- 发布环境
  - 默认使用 `Redis HA + PostgreSQL HA + pgvector`

发布环境共享数据库入口：

```yaml
higress-core:
  postgresql:
    enabled: true
  redis:
    enabled: true

aigateway-portal:
  database:
    driver: postgres
    host: aigateway-core-postgresql-pgpool

aigateway-console:
  portalDatabase:
    driver: postgres
    host: aigateway-core-postgresql-pgpool
```

已知限制：

- 本轮不包含 MySQL 到 PostgreSQL 的存量数据迁移工具。
- `console / portal` 的 PostgreSQL 运行时路径已经补齐共享 schema、legacy migration 和核心 runtime SQL smoke，但 `fresh bundle -> k3d -> k8s` 的完整端到端发布回归仍需要在具备 `k3d` 与可推送镜像仓库的环境执行。
- `release-build --skip-build` 仅适用于镜像已经在本机准备完成的场景；如果本地不存在对应 dev tag 镜像，脚本会在 `docker save` 前失败。

## 本地端口暴露规则

`./scripts/port-forward-all.sh` 会按 `./helm/dev-mode.yaml` 中的 `dev.portForward` 规则扫描并转发服务端口。

当前默认转发：

- `aigateway-console:8080`
- `aigateway-console-grafana:3000`
- `aigateway-console-loki:3100 / 7946 / 9095`
- `aigateway-console-prometheus:9090`
- `aigateway-controller:8888 / 8889 / 15010 / 15012 / 15014 / 15051 / 15443(local->443)`
- `aigateway-plugin-server:18080(local->80)`
- `aigateway-portal:8081`
- `aigateway-core-postgresql-pgpool:5432`
- `redis-stack-server:6379`

端口选择规则：

- 优先使用相同端口
- 若端口冲突，则从 `dev.portForward.localPortStart` 起自动分配
- 启动前会等待 Service 有 ready endpoints
- 可在 `dev.portForward.servicePorts` 中固定某个服务端口的本地映射

可用下面的脚本快速校验各个 profile 的暴露策略是否仍符合约定：

```bash
./scripts/validate-helm-exposure.py
```
