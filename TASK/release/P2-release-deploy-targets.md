# P2 发布部署目标支持

- 状态：`done`
- 依赖：`P1`

## 目标

- 落下统一部署入口，支持 `k3d` 和通用 `k8s`。

## 任务

- [ ] 新增 `scripts/release-deploy.sh`。
- [ ] 在 `start.sh` 增加 `release-deploy` 兼容入口。
- [ ] 支持 `--target k3d|k8s`。
- [ ] 实现 `k3d` 模式：`docker load + k3d image import + helm upgrade --install`。
- [ ] 实现 `k8s` 模式：`docker load + retag + push + helm upgrade --install`。
- [ ] 支持 `--registry`、`--replicas`、`--image-pull-secret`、`--set`、`--dry-run`。
- [ ] 生成 registry override values，并支持 `--skip-import / --skip-push / --skip-deploy` 便于重试。

## 验收点

- [ ] 同一个 bundle 能部署到 `k3d` 和通用 `k8s`。
- [ ] 重试导镜像、重推镜像、重 Helm 部署可分步执行。
- [ ] `deploy.sh` 可以直接从 bundle 目录运行。

## 测试

- [ ] `--dry-run` 覆盖两种 target。
- [ ] K3D fresh cluster 安装 smoke。
- [ ] K8S registry override 渲染检查。
