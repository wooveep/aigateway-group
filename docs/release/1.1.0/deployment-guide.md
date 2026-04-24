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

`k3d` 是首选正式验收环境。

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
  --base-domain example.com \
  --dry-run
```

实际部署：

```bash
./start.sh release-deploy \
  --target k3d \
  --bundle-dir out/release/aigateway-1.1.0 \
  --cluster <k3d-cluster> \
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

## 8. 已知边界

- 访问 Console / Portal 前，需要将上述域名解析到集群 Ingress / Gateway 入口地址
- 若启用 Portal OIDC SSO，需额外把 `aigateway-portal.backend.publicBaseURL` 配置为用户真实访问的 Portal 外部基地址
- Console `/system` 页面保存的 OIDC 配置会落到共享 PostgreSQL，因此正式部署时仍要求 Portal/Console 共用同一套 Portal PostgreSQL
- 如果本机未准备好对应一方镜像，`release-build` 在 `docker save` 阶段会失败
- 如果缺少可推送 registry，通用 `k8s` 目标无法完成实际部署
