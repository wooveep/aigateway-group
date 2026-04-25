# AIGateway 1.1.0 K8S / K3D&Helm 部署说明

## 1. 推荐顺序

1. 查看当前发布入口配置
2. 检查 manifest 与 Helm values 是否一致
3. 生成 release bundle
4. 先做 dry-run
5. 优先在 `k3d` 完成正式验收
6. 再按 registry override 路径部署到通用 `k8s`

## 2. 先看当前配置

```bash
./start.sh show
./start.sh sync --check
```

## 3. 生成 bundle

```bash
./start.sh release-build --bundle-name aigateway-1.1.0
```

## 4. K3D 部署

`k3d` 是首选正式验收环境。新建 k3d 默认按单节点标准部署，不启用 HA profile。

### 4.1 离线一键安装

无互联网环境优先使用 bundle 中的 `install-k3d-offline.sh`。把 release bundle 和运行时离线包放到目标机后执行：

```bash
cd /opt/aigateway-install/1.1.0/bundle/aigateway-1.1.0
./install-k3d-offline.sh \
  --runtime-package /opt/aigateway-install/1.1.0/offline-packages/aigateway-runtime-with-k3d-images-ubuntu24.04-amd64-20260424.tar.gz \
  --install-root /opt/aigateway-install/1.1.0 \
  --cluster aigateway-110 \
  --base-domain aigateway.io \
  --profile standard
```

该脚本会完成：

- 安装 Docker / k3d / kubectl / Helm
- 加载 k3d / k3s 系统镜像并逐节点导入 k3d containerd
- 创建单节点 k3d 集群，默认禁用 k3s Traefik
- 校验 bundle `metadata/SHA256SUMS`
- 加载并逐节点导入 release 镜像
- 执行 Helm 部署

如需重建已有测试集群，增加 `--recreate-cluster`。

### 4.2 在线 / 已安装运行时部署

新建验收集群时先指定本次部署域名。脚本会禁用 k3s 默认 Traefik，并在集群内写入 `aigateway-system/aigateway-cluster-domain`：

```bash
./start.sh release-k3d-cluster \
  --cluster <k3d-cluster> \
  --base-domain example.com
```

Dry-run：

```bash
./start.sh release-deploy \
  --target k3d \
  --bundle-dir out/release/aigateway-1.1.0 \
  --cluster <k3d-cluster> \
  --profile standard \
  --base-domain example.com \
  --dry-run
```

实际部署：

```bash
./start.sh release-deploy \
  --target k3d \
  --bundle-dir out/release/aigateway-1.1.0 \
  --cluster <k3d-cluster> \
  --profile standard \
  --base-domain example.com
```

## 5. 通用 K8S 部署

Dry-run：

```bash
./start.sh release-deploy \
  --target k8s \
  --bundle-dir out/release/aigateway-1.1.0 \
  --registry registry.example.com/team \
  --base-domain example.com \
  --dry-run
```

实际部署：

```bash
./start.sh release-deploy \
  --target k8s \
  --bundle-dir out/release/aigateway-1.1.0 \
  --registry registry.example.com/team
```

通用 K8S 已有集群建议先由集群管理员提供域名定义；部署脚本会自动读取：

```bash
kubectl -n aigateway-system create configmap aigateway-cluster-domain \
  --from-literal=baseDomain=example.com \
  --from-literal=consoleHost=console.example.com \
  --from-literal=portalHost=portal.example.com \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate namespace aigateway-system \
  aigateway.io/ingress-base-domain=example.com \
  --overwrite
```

## 6. 渲染检查

```bash
helm template aigateway ./helm/higress \
  -f ./higress/helm/higress/values-release-base.yaml \
  -f ./higress/helm/higress/values-release-ha.yaml \
  -f ./higress/helm/higress/values-release-upstreams.yaml
```

## 7. 部署说明

- `k3d`
  - 使用 `docker load + k3d image import + helm upgrade --install`
- 通用 `k8s`
  - 使用 `docker load + retag/push + helm upgrade --install`
- Helm `--wait` 完成后，脚本会继续在集群内显式执行数据库初始化：
  - `kubectl exec deploy/aigateway-portal -- /app/aigateway-portal db-init`
  - `kubectl exec deploy/aigateway-console -- /app/aigateway-console portaldb-init`
  - 该阶段只负责共享表、Portal 自有表、Console 自有表的全量初始化
  - legacy 数据迁移不属于新环境部署阶段；如需升级旧库，使用单独命令 `portal-legacy-migrate`
- Console / Portal Pod 还会在容器级和应用级两层等待共享库：
  - Deployment 增加 `wait-for-portal-db` initContainer，先用 `pg_isready` 等待 PostgreSQL ready
  - Portal 业务进程在数据库 / bootstrap 未就绪时会在容器内持续重试，不再直接退出 Pod
  - Console `portaldb` 健康检查在数据库恢复后会重新探测并清理启动期旧错误，不再把 `portalHealthy=false` 永久锁死
- 真实部署镜像集合以 bundle 中的 `metadata/images.lock` 为准
- Console / Portal 正式访问通过 Kubernetes Ingress 暴露，不使用 port-forward
  - 标准 K8S：默认读取 `aigateway-system/aigateway-cluster-domain` 中的 `baseDomain`
  - 新建 k3d：创建时通过 `./start.sh release-k3d-cluster --base-domain <domain>` 写入域名定义
  - 临时覆盖：部署时传 `--base-domain <domain>`，或传 `--console-host` / `--portal-host`
  - 最终 host：`console.<baseDomain>` 与 `portal.<baseDomain>`
- `k3d` 正式验收集群创建时禁用 k3s 默认 Traefik，避免与 `IngressClass=aigateway` 同时监听 80/443：

```bash
./start.sh release-k3d-cluster \
  --cluster <k3d-cluster> \
  --base-domain example.com
```

`standard` profile 适合单节点 / 资源受限环境：

- Console / Portal / Controller / Gateway / Plugin Server 均为 1 副本
- PostgreSQL 为 1 个实例，pgpool 为 1 副本
- Redis 为 standalone
- 内置监控默认启用，会额外部署 Grafana / Prometheus / Loki / Promtail
- Portal 会显式注入 `corePrometheusURL=http://aigateway-console-prometheus:9090/prometheus`，供 AI 监控面板与用量统计读取指标
- `global.onlyPushRouteCluster=false`，保证 `ai-quota` / `ai-token-ratelimit` / `cluster-key-rate-limit` 可直接访问 `redis-server-master.<namespace>.svc.cluster.local`

`ha` profile 适合多节点集群：

- Gateway 3 副本
- Controller / Console / Portal / Plugin Server 2 副本
- PostgreSQL 3 实例，pgpool 2 副本
- Redis replication + sentinel

后续修改 Console / Portal 域名时，重新执行部署脚本即可；脚本会更新集群域名定义并做 Helm upgrade：

```bash
./start.sh release-deploy \
  --target k8s \
  --bundle-dir out/release/aigateway-1.1.0 \
  --registry registry.example.com/team \
  --skip-import \
  --skip-push \
  --base-domain new.example.com
```

若只想跳过数据库初始化阶段，可显式增加：

```bash
--skip-db-init
```

## 8. 已知边界

- 访问 Console / Portal 前，需要将上述域名解析到集群 Ingress / Gateway 入口地址
- 若启用 Portal OIDC SSO，需额外把 `aigateway-portal.backend.publicBaseURL` 配置为用户真实访问的 Portal 外部基地址
- Console `/system` 页面保存的 OIDC 配置会落到共享 PostgreSQL，因此正式部署时仍要求 Portal/Console 共用同一套 Portal PostgreSQL
- 如果本机未准备好对应一方镜像，`release-build` 在 `docker save` 阶段会失败
- 如果缺少可推送 registry，通用 `k8s` 目标无法完成实际部署
