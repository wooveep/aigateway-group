# AIGateway 1.0.0 镜像包说明

## 1. bundle 目录

正式 bundle 目录默认命名为：

```text
out/release/aigateway-1.0.0/
```

目录结构固定为：

```text
charts/
images/
values/
metadata/
deploy.sh
```

## 2. 目录职责

- `charts/`
  - 父 Chart 打包结果
- `images/`
  - render 后所需镜像的 `tar` 包
- `values/`
  - `release-base.yaml`
  - `release-ha.yaml`
  - `release-upstreams.yaml`
- `metadata/`
  - `images.lock`
  - `release.env`
  - `SHA256SUMS`
- `deploy.sh`
  - 从 bundle 部署到 `k3d` / 通用 `k8s`

## 3. 生成命令

```bash
./start.sh release-build --bundle-name aigateway-1.0.0
```

如果仅做结构验证：

```bash
./start.sh release-build --bundle-name aigateway-1.0.0 --dry-run
```

## 4. 镜像版本规则

- 一方镜像统一使用 `1.0.0`
- 第三方依赖镜像保持上游版本
- 真实部署镜像集合以 `metadata/images.lock` 为准

## 5. 校验建议

- 检查 `metadata/images.lock`
- 检查 `metadata/SHA256SUMS`
- 检查 `values/` 中三个 release values 是否齐全
- 检查 `charts/` 中父 Chart 包与 `deploy.sh` 是否同 bundle 一起生成
