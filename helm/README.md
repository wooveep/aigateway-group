# AIGateway Group Helm & Dev Mode

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
- `./start.sh minikube-tunnel`
  - 默认执行：依赖检查 -> sync -> minikube start -> redeploy(local-minikube profile)
  - `--start-tunnel` 时附带执行 `minikube tunnel`

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
  - `aigateway-console` / `aigateway-portal` / `grafana` / `prometheus` / `loki` / `controller` / `plugin-server` / `mysql` / `redis`
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

`./scripts/port-forward-all.sh` 会按 `./helm/dev-mode.yaml` 中的 `dev.portForward` 规则扫描并转发服务端口。

当前默认转发：

- `aigateway-console:8080`
- `aigateway-console-grafana:3000`
- `aigateway-console-loki:3100 / 7946 / 9095`
- `aigateway-console-prometheus:9090`
- `aigateway-controller:8888 / 8889 / 15010 / 15012 / 15014 / 15051 / 15443(local->443)`
- `aigateway-plugin-server:18080(local->80)`
- `aigateway-portal:8081`
- `mysql-server:3306`
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
