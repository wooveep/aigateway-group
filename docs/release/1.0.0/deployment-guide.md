# AIGateway 1.0.0 K8S / K3D&Helm 部署说明

## 1. 推荐顺序

1. 查看当前发布入口配置
2. 生成 release bundle
3. 先做 dry-run
4. 优先在 `k3d` 完成正式验收
5. 再按 registry override 路径部署到通用 `k8s`

## 2. 先看当前配置

```bash
./start.sh show
./start.sh sync --check
```

## 3. 生成 bundle

```bash
./start.sh release-build --bundle-name aigateway-1.0.0
```

## 4. K3D 部署

`k3d` 是首选正式验收环境。

Dry-run：

```bash
./start.sh release-deploy \
  --target k3d \
  --bundle-dir out/release/aigateway-1.0.0 \
  --cluster <k3d-cluster> \
  --dry-run
```

实际部署：

```bash
./start.sh release-deploy \
  --target k3d \
  --bundle-dir out/release/aigateway-1.0.0 \
  --cluster <k3d-cluster>
```

## 5. 通用 K8S 部署

Dry-run：

```bash
./start.sh release-deploy \
  --target k8s \
  --bundle-dir out/release/aigateway-1.0.0 \
  --registry registry.example.com/team \
  --dry-run
```

实际部署：

```bash
./start.sh release-deploy \
  --target k8s \
  --bundle-dir out/release/aigateway-1.0.0 \
  --registry registry.example.com/team
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

## 8. 已知边界

- 如果本机未准备好对应一方镜像，`release-build` 在 `docker save` 阶段会失败
- 如果缺少可推送 registry，通用 `k8s` 目标无法完成实际部署
- 正式发布依旧要求共享 PostgreSQL 与 Redis 链路保持可用
