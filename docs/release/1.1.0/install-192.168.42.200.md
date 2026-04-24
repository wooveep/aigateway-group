# AIGateway 1.1.0 安装记录：192.168.42.200

日期：2026-04-24  
目标机：Ubuntu 24.04.3 LTS / root / `192.168.42.200`  
部署方式：`k3d + Helm + out/release/aigateway-1.1.0`

## 结果

- k3d 集群：`aigateway-110`
- Helm release：`aigateway`，最终 revision `3`
- Namespace：`aigateway-system`
- Console Ingress：`console.aigateway.io`
- Portal Ingress：`portal.aigateway.io`
- 集群域名定义：`aigateway-system/aigateway-cluster-domain`，`baseDomain=aigateway.io`
- 安装目录：`/opt/aigateway-install/1.1.0/`
- release bundle：`/opt/aigateway-install/1.1.0/bundle/aigateway-1.1.0/`
- 运行时离线包：
  - `/opt/aigateway-install/1.1.0/offline-packages/aigateway-runtime-ubuntu24.04-amd64-20260424.tar.gz`
  - `/opt/aigateway-install/1.1.0/offline-packages/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-20260424.tar.gz`
- 过程日志：`/opt/aigateway-install/1.1.0/logs/`

## 已安装运行时

- Docker：Ubuntu `docker.io`，实测 `29.1.3`
- k3d：`v5.8.3`
- k3s image：`rancher/k3s:v1.31.5-k3s1`
- kubectl：`v1.32.3`
- Helm：`v3.17.3`

## 关键步骤

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

- Helm：`STATUS: deployed`
- `aigateway-system` 业务 Pod 全部 Running
- `kube-system` 已无默认 `traefik` Service / Deployment
- Portal Pod 镜像已更新到本次重建镜像，container imageID 为 `sha256:99aea3a308e16000e1c36574d113cd7ef031e112925ac45e03d2f23bbbb5dea1`
- Console Ingress：HTTP `200 OK`
- Portal Ingress：HTTP `200 OK`
