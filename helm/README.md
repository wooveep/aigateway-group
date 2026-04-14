# AIGateway Group Helm & Dev Mode

统一入口放在仓库根目录：

- 启动脚本：`./start.sh`
- 本地版本/构建/Minikube 脚本：`./scripts/aigateway-dev.py`
- 开发配置：`./helm/dev-mode.yaml`
- 镜像版本清单：`./helm/image-versions.yaml`
- Helm Chart 入口：`./helm/higress`（软链接，真源目录为 `./higress/helm/higress`）
- 端口暴露脚本：`./scripts/port-forward-all.py`

## 常用命令

```bash
# 查看当前统一版本清单和固定端口映射
./scripts/aigateway-dev.py show

# 检查本地开发依赖联通性
./scripts/aigateway-dev.py check-connectivity

# 将中心版本同步回各个 Helm values
./scripts/aigateway-dev.py sync

# 本地构建所有镜像
./scripts/aigateway-dev.py build

# 本地 minikube 开发模式：构建 + redeploy + 全量开发端口转发
./scripts/aigateway-dev.py minikube-dev

# minikube LoadBalancer 模式：构建 + redeploy，随后用 tunnel 暴露 svc
./scripts/aigateway-dev.py minikube-tunnel

# 开发模式：部署 + 自动本地端口暴露
./start.sh dev

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

## Console 镜像链路

`console` 组件现在固定走新的 Go backend 项目链路：

```text
higress/helm/build-local-images.sh --components console
-> aigateway-console/frontend npm run build
-> aigateway-console/backend/resource/public/html
-> aigateway-console/backend/Dockerfile
-> aigateway/console:<tag>
```

这条链路不再依赖旧 Java 静态资源目录，也不再把 `aigateway-console/backend/build.sh` 误当成 Docker 镜像构建入口。

## 统一版本与本地脚本

`./helm/image-versions.yaml` 现在是本地联调镜像版本的单一来源，集中维护：

- `aigateway/controller/gateway/pilot/console/portal/plugin-server` 的仓库和 tag
- 默认构建组件列表
- 默认 `releaseName / namespace`
- 默认 minikube 配置（profile / driver / cpus / memory / diskSize / addons）

推荐优先用 `./scripts/aigateway-dev.py` 驱动本地流程：

```bash
# 仅检查 Helm values 是否已经和中心版本一致
./scripts/aigateway-dev.py sync --check

# 启动 minikube（会更新 kube context 并开启 manifest 中声明的 addons）
./scripts/aigateway-dev.py minikube-start

# 走 dev 模式：
# - sync image versions
# - minikube start
# - start.sh dev-redeploy
# - 按 dev-mode.yaml 固定端口表做本地转发
./scripts/aigateway-dev.py minikube-dev

# 走 minikube tunnel 模式：
# - sync image versions
# - minikube start
# - redeploy-minikube.sh -f values-local-minikube.yaml
./scripts/aigateway-dev.py minikube-tunnel --start-tunnel
```

可选项：

- `--components controller,gateway,console` 只构建/更新部分组件
- `--skip-sync` 跳过版本同步
- `--skip-start` 假定 minikube 已经启动
- `--profile <name>` 临时覆盖 `helm/image-versions.yaml` 里的 minikube profile

## k3d 正式环境

- 当 `kubectl` 当前 context 为 `k3d-*` 且 `deploy-prod` 不带额外 helm 参数时，`./start.sh deploy-prod` 会自动走 k3d 全流程发布（等价于 `prod-redeploy`）。
- 默认使用 values：`./helm/higress/values-production-k3d.yaml`（若不存在则回退 `values-production-gray.yaml`）。
- 强制执行全流程推荐直接使用：

```bash
./start.sh prod-redeploy
```

常用环境变量：

```bash
# 指定 k3d 集群名（默认从当前 context 推断）
K3D_CLUSTER=prod

# 控制 prod 全流程的构建/导入/部署步骤
PROD_REDEPLOY_SKIP_BUILD=true
PROD_REDEPLOY_SKIP_LOAD=true
PROD_REDEPLOY_SKIP_DEPLOY=true

# 是否在 deploy-prod 自动切换到 k3d 全流程（auto|true|false）
PROD_USE_K3D_REDEPLOY=auto
```

## 暴露模型

- `./start.sh dev` / `./helm/dev-mode.yaml`
  - `aigateway-console` / `aigateway-portal` / `grafana` / `prometheus` / `loki` / `controller` / `plugin-server` / `mysql` / `redis`：
    通过 `./scripts/port-forward-all.py` 固定转发到本机
  - `aigateway-gateway`: `ClusterIP`，Pod 通过 `hostPort` 直接监听本机 `80/443`
- `./helm/higress/values-local-minikube.yaml`
  - 面向 `minikube tunnel`
  - `aigateway-console` / `aigateway-portal` / `aigateway-gateway` 都通过 `LoadBalancer` 暴露
  - 不再额外绑定 `hostPort`
- `./helm/higress/values-production-k3d.yaml` / `values-production-gray.yaml`
  - `aigateway-console` / `aigateway-portal` / `aigateway-gateway` 都通过 `LoadBalancer` 暴露
  - 不使用 `hostPort`

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

将对应 `enabled` 改为 `false`，重新执行 `./start.sh deploy` 或 `./start.sh dev` 即可。

`aigateway-console` 与 `aigateway-portal` 统一采用相同风格的顶层配置入口（`name / image / service / ingress`）。

## MySQL 归属

Portal/Console 使用的 MySQL 由 `higress-core` 统一启动与管理：

```yaml
higress-core:
  mysql:
    mysql:
      enabled: true
      name: mysql-server
      repository: aigateway/mariadb
      tag: "11.4"

aigateway-portal:
  mysql:
    enabled: false
  database:
    host: mysql-server

aigateway-console:
  portalDatabase:
    host: mysql-server
```

## 本地端口暴露规则

`./scripts/port-forward-all.py` 默认会扫描当前 release 下的 Service 端口并转发到本机；也可以通过 `dev.portForward.includeServices` / `skipServices` 限定范围。

当前 `./helm/dev-mode.yaml` 默认转发：

- `aigateway-console:8080`
- `aigateway-console-grafana:3000`
- `aigateway-console-loki:3100 / 7946 / 9095`
- `aigateway-console-prometheus:9090`
- `aigateway-controller:8888 / 8889 / 15010 / 15012 / 15014 / 15051 / 15443(local->443)`
- `aigateway-plugin-server:18080(local->80)`
- `aigateway-portal:8081`
- `mysql-server:3306`
- `redis-stack-server:6379`

其余入口规则：

- `aigateway-gateway` 在本地模式通过 `hostPort` 直接监听 `80/443`

端口选择规则：

- 优先使用相同端口（例如容器 8080 -> 本地 8080）
- 若端口冲突，则从 `dev.portForward.localPortStart` 起自动分配
- 启动前会等待 Service 有 ready endpoints（超时由 `dev.portForward.waitReadySeconds` 控制）
- 可在 `dev.portForward.servicePorts` 中固定某个服务端口的本地映射

可用下面的脚本快速校验各个 profile 的暴露策略是否仍符合约定：

```bash
./scripts/validate-helm-exposure.py
```

可用下面的脚本检查当前开发环境与 Console 依赖是否已打通：

```bash
./scripts/aigateway-dev.py check-connectivity
```
