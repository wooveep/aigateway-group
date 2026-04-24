# AIGateway 1.1.0 安装记录：192.168.42.200

日期：2026-04-24  
目标机：Ubuntu 24.04.3 LTS / root / `192.168.42.200`  
部署方式：`k3d + Helm + out/release/aigateway-1.1.0`

> 最新状态：目标机已重置为干净 Ubuntu 24.04.3 LTS，并使用 `install-k3d-offline.sh` 完整离线安装运行时、创建单节点 k3d、导入镜像和部署 `standard` profile。

## 结果

- k3d 集群：`aigateway-110`
- k3d 节点：`1 server + 0 agent`
- Helm release：`aigateway`，当前 revision `3`
- 当前 Helm profile：`standard`
- Namespace：`aigateway-system`
- Console Ingress：`console.aigateway.io`
- Portal Ingress：`portal.aigateway.io`
- 集群域名定义：`aigateway-system/aigateway-cluster-domain`，`baseDomain=aigateway.io`
- 安装目录：`/opt/aigateway-install/1.1.0/`
- release bundle：`/opt/aigateway-install/1.1.0/bundle/aigateway-1.1.0/`
- 运行时离线包：
  - `/opt/aigateway-install/1.1.0/offline-packages/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-20260424.tar.gz`
- 过程日志：`/opt/aigateway-install/1.1.0/logs/`
  - 最新一键安装日志：`/opt/aigateway-install/1.1.0/logs/install-k3d-offline-20260424133028.log`

## 已安装运行时

- Docker：Ubuntu `docker.io`，实测 `29.1.3`
- k3d：`v5.8.3`
- k3s image：`rancher/k3s:v1.31.5-k3s1`
- kubectl：`v1.32.3`
- Helm：`v3.17.3`

## 关键步骤

### 最新一键离线安装

已将运行时离线包上传到：

```bash
/opt/aigateway-install/1.1.0/offline-packages/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-20260424.tar.gz
```

已将 release bundle 上传到：

```bash
/opt/aigateway-install/1.1.0/bundle/aigateway-1.1.0/
```

最终使用 bundle 自带一键脚本部署：

```bash
cd /opt/aigateway-install/1.1.0/bundle/aigateway-1.1.0
./install-k3d-offline.sh \
  --runtime-package /opt/aigateway-install/1.1.0/offline-packages/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-20260424.tar.gz \
  --install-root /opt/aigateway-install/1.1.0 \
  --cluster aigateway-110 \
  --base-domain aigateway.io \
  --profile standard
```

本次修复了两个干净离线安装问题：

- k3d 节点 containerd 需要逐节点导入 `rancher/mirrored-pause:3.6` 等 k3d/k3s 系统镜像，否则 kubelet 会尝试访问 Docker Hub。
- 单节点 `standard` profile 需要降低 Gateway / Controller / Pilot 等默认资源请求，否则 4C/8G 单节点会因 CPU / memory requests 不足导致 PostgreSQL、Redis 和 o11y Pod Pending。
- 验证过程中曾尝试预置全局认证口径的 `key-auth.internal` WasmPlugin，但 Portal 同步会把 key-auth 默认配置打开到全局，导致 Console / Portal 入口返回 `500`。修复口径已调整为：Portal 可创建 `key-auth.internal`，但实例级配置必须写 `global_auth=false`，只保存 consumers / key 提取规则；业务鉴权只由 Console 在具体 Route / AI Route 上写 `matchRules.allow`。

### 早期手工部署记录

1. 目标机 apt 默认源下载 `.deb` 时返回 `403`，将 `/etc/apt/sources.list.d/ubuntu.sources` 切到 `https://archive.ubuntu.com/ubuntu/` 与 `https://security.ubuntu.com/ubuntu/` 后恢复。
2. 安装 `docker.io`、`curl`、`jq` 等基础依赖，安装 k3d / kubectl / Helm 二进制。
3. 直接从 GitHub 下载 k3d 超时，改为在本机从 SourceForge k3d mirror 下载 `k3d-linux-amd64-v5.8.3` 后传到目标机。
4. 目标机访问 Docker Hub 超时，补充离线导入 k3d / k3s / k3s system images：
   - `rancher/k3s:v1.31.5-k3s1`
   - `ghcr.io/k3d-io/k3d-tools:5.8.3`
   - `ghcr.io/k3d-io/k3d-proxy:5.8.3`
   - `rancher/mirrored-pause:3.6`
   - `rancher/mirrored-coredns-coredns:1.12.0`
   - `rancher/local-path-provisioner:v0.0.30`
   - `rancher/mirrored-metrics-server:v0.7.2`
   - `rancher/klipper-lb:v0.4.9`
   - `rancher/klipper-helm:v0.9.3-build20241008`
   - `rancher/mirrored-library-traefik:2.11.18`
   - `rancher/mirrored-library-busybox:1.36.1`
5. 传输 `out/release/aigateway-1.1.0/` 到目标机并执行 `sha256sum -c metadata/SHA256SUMS`，校验通过。
6. 创建 k3d 集群：

```bash
k3d cluster create aigateway-110 \
  --servers 1 \
  --agents 2 \
  --k3s-arg "--disable=traefik@server:*" \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --wait
```

本次最初创建集群时未禁用 k3s 默认 Traefik，后续正式改为 Ingress 访问时发现 Traefik 与 `IngressClass=aigateway` 同时监听 80/443，会导致外部请求间歇命中默认 404。当前目标机已删除默认 Traefik：

```bash
kubectl delete helmchart -n kube-system traefik traefik-crd --ignore-not-found
kubectl delete deploy -n kube-system traefik --ignore-not-found
kubectl delete svc -n kube-system traefik --ignore-not-found
kubectl delete pod -n kube-system -l svccontroller.k3s.cattle.io/svcname=traefik --ignore-not-found
```

7. 执行 bundle 部署：

```bash
HELM_TIMEOUT=20m ./deploy.sh \
  --target k3d \
  --bundle-dir /opt/aigateway-install/1.1.0/bundle/aigateway-1.1.0 \
  --cluster aigateway-110
```

8. 因 `k3d image import` 在当前 Docker 29 环境下对部分镜像输出 `ctr: content digest ... not found` / `unexpected EOF`，改为对每个 k3d 节点执行：

```bash
docker cp <image.tar> <k3d-node>:/tmp/<image.tar>
docker exec <k3d-node> ctr -n k8s.io images import /tmp/<image.tar>
```

9. 首次 Helm 会话断开导致 release 停在 `pending-install`，删除 `sh.helm.release.v1.aigateway.v1` 后用同一 chart / values 重新执行 `helm upgrade --install --wait`，最终状态为 `deployed`。
10. Console / Portal 正式访问不使用 port-forward；通过 `IngressClass=aigateway` 的 Kubernetes Ingress 暴露：
    - `console.aigateway.io`
    - `portal.aigateway.io`
11. 已补充集群域名定义，后续 `deploy.sh` 可自动读取：

```bash
kubectl -n aigateway-system get configmap aigateway-cluster-domain
```

> 备注：部署排障过程中曾临时创建 `aigateway-console-port-forward.service` 与 `aigateway-portal-port-forward.service` 验证服务连通性，后续已停用并删除。正式部署不保留 port-forward systemd 服务。

## 发现的问题与修复

部署过程中发现 `1.1.0` 首启共享库有两个启动阻断：

1. 缺少 Console 侧持有表 `portal_model_binding_price_version`，Portal 启动时报 `relation "portal_model_binding_price_version" does not exist`。
2. 新环境只有 legacy `portal_model_catalog` 种子模型，没有匹配的 `billing_model_catalog / billing_model_price_version`，Portal 账单 backfill 校验失败。

本次在目标库手工补齐后完成验证：

- 创建 `portal_model_binding_price_version`
- 从 `portal_model_catalog` 回填 `billing_model_catalog`
- 从 `portal_model_catalog` 生成 active `billing_model_price_version`

后续已在仓库修复：

- Portal 启动迁移会自动创建 `portal_model_binding_price_version`
- 当 K8s 模型目录为空时，Portal 账单模型 bootstrap 会回退到 legacy `portal_model_catalog`

修复后已重新执行 `./start.sh release-build`，覆盖生成 `out/release/aigateway-1.1.0/`，并同步到目标机 `/opt/aigateway-install/1.1.0/bundle/aigateway-1.1.0/`。目标机已重新校验 `metadata/SHA256SUMS`，导入修复后的 `aigateway/portal:1.1.0` 镜像，并执行 Helm upgrade 到 revision `3`。

后续按组件重新执行 `./start.sh release-build --components console,portal`，刷新 `aigateway/console:1.1.0` 与 `aigateway/portal:1.1.0` 镜像和 bundle；目标机已同步新 bundle，导入 Console / Portal 两个镜像，并执行 Helm upgrade 到 revision `4`。

### Pod 数量与 Dashboard 未启用

用户现场反馈 k3d 是单节点但 `aigateway-system` Pod 数量较多，并且 Console 登录后 Dashboard 显示监控未启用。排查结论：

- 目标机 k3d 实际创建为 `1 server + 2 agent`，不是单节点 k3d。
- 初始部署使用 `ha` profile，会启用多副本：Gateway 3、Controller 2、Console 2、Portal 2、Plugin Server 2、PostgreSQL 3、Pgpool 2、Redis replication。
- release base values 中 `global.o11y.enabled=false`，Console 环境变量 `AIGATEWAY_CONSOLE_GRAFANA_ENABLED=false`，因此 Dashboard API 返回未启用。

已做修复：

- `helm/image-versions.yaml` 默认 release profile 调整为 `standard`。
- `release-k3d-cluster.sh` 默认 `--agents 0`，新建 k3d 默认单节点。
- `values-release-base.yaml` 收敛为标准部署：业务组件、PostgreSQL、Pgpool、Redis 均为单副本 / standalone。
- `values-release-ha.yaml` 保留多副本、PostgreSQL 3 实例和 Redis replication，仅在显式选择 `ha` profile 时启用。
- `values-release-base.yaml` 默认启用 `global.o11y.enabled=true`，标准部署也会安装 Grafana / Prometheus / Loki / Promtail。
- 修复 `release-build.sh` 镜像提取逻辑，支持 Helm 渲染中的 `- image: ...` 形式，确保 Prometheus 镜像进入离线 bundle。

随后重新生成 `out/release/aigateway-1.1.0/`，bundle 镜像数为 `13`，同步目标机并导入所有镜像后，执行 Helm upgrade 到 revision `5`。当前目标机工作负载已收敛为 standard profile：

- Console / Portal / Controller / Gateway / Plugin Server：各 `1` 个副本
- PostgreSQL：`1` 个实例
- Pgpool：`1` 个副本
- Redis：standalone `redis-server-master-0`
- O11y：Grafana / Prometheus / Loki 各 `1` 个副本，Gateway Pod 内含 Promtail sidecar

## 验证

```bash
helm status aigateway -n aigateway-system
kubectl get pods -n aigateway-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get ingress -n aigateway-system
curl -H 'Host: console.aigateway.io' http://192.168.42.200/
curl -H 'Host: portal.aigateway.io' http://192.168.42.200/
```

验证结果：

- Helm：`STATUS: deployed`，revision `3`
- k3d：单节点 `k3d-aigateway-110-server-0`
- `aigateway-system` 业务 Pod 全部 Running
- `kube-system` 已无默认 `traefik` Service / Deployment
- Console Pod 镜像已更新到本次重建镜像，container imageID 为 `sha256:b5740ee6fc3b30e3666e8d1ccd7346eab388ed368df3414d21d3826908700d23`
- Portal Pod 镜像已更新到本次重建镜像，container imageID 为 `sha256:99aea3a308e16000e1c36574d113cd7ef031e112925ac45e03d2f23bbbb5dea1`
- Console Ingress：HTTP `200 OK`
- Portal Ingress：HTTP `200 OK`
- key-auth 投影修复后，Portal 首次同步会创建非全局认证的 `key-auth.internal`，无 AI 路由时不拦截 Console / Portal 入口，也不再持续打印 `key-auth wasmplugin not found`。
- Console 环境变量已启用内置监控：`AIGATEWAY_CONSOLE_GRAFANA_ENABLED=true`
- Console Pod 内访问 Prometheus readiness 返回 `Prometheus Server is Ready.`
- Console Pod 内访问 Grafana health 返回 `database: ok`
- 使用 `admin/admin` 登录 Console 后访问 `/dashboard/info?type=MAIN` 返回 `builtIn: true`
- 使用 `admin/admin` 登录 Console 后访问 `/dashboard/native?type=MAIN` 已返回 CPU / Memory / Gateway Pod Count 等指标数据
