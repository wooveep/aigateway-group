# AIGateway 1.0.0 发布说明

## 1. 发布定位

`1.0.0` 是当前仓库的正式平台发布版本。  
该版本统一收口了根级文档体系、发布 / 部署主线、正式文档目录以及 release bundle 交付口径。

## 2. 正式版本合同

- 仓库管理的一方镜像统一使用 `1.0.0`
- 第三方依赖镜像保持上游版本，通过 `images.lock` 与 Helm values 锁定
- 正式发布接口保持为：
  - `./start.sh release-build`
  - `./start.sh release-deploy --target k3d|k8s`

## 3. 交付物

- release bundle
  - `out/release/aigateway-1.0.0/`
- 项目介绍白皮书
  - `docs/overview/aigateway-whitepaper-1.0.0.md`
- 发布与部署文档
  - `docs/release/1.0.0/`
- 用户手册
  - `docs/manual/1.0.0/user-manual.md`

## 4. 验证要求

- `./start.sh help`
- `./start.sh show`
- `./start.sh sync --check`
- `./start.sh release-build --dry-run`
- `./start.sh release-deploy --target k8s --registry registry.example.com/team --dry-run`
- release values 的 `helm template`

## 5. 已知说明

- `k3d` 是首选正式验收环境
- 通用 `k8s` 部署要求提供可推送 registry
- Docx / PDF 为正式交付件，Markdown 仍是仓库内真相源
