# AIGateway 1.1.0 发布说明

## 1. 发布定位

`1.1.0` 是当前仓库的正式平台发布版本。该版本在 `1.0.0` 发布基线之上，继续收口正式版本源、镜像标签、发布 bundle、项目介绍文档和项目介绍 PPT 交付件。

## 2. 正式版本合同

- 仓库管理的一方镜像统一使用 `1.1.0`
- 第三方依赖镜像保持上游版本，通过 `metadata/images.lock` 与 Helm values 锁定
- 正式发布接口保持为：
  - `./start.sh test --stage unit|integration|e2e|acceptance|release`
  - `./start.sh release-build`
  - `./start.sh release-deploy --target k3d|k8s`

## 3. 交付物

- release bundle
  - `out/release/aigateway-1.1.0/`
- 发布文档
  - `docs/release/1.1.0/release-notes.md`
  - `docs/release/1.1.0/image-bundle.md`
  - `docs/release/1.1.0/deployment-guide.md`
- 项目介绍文档
  - `docs/overview/aigateway-whitepaper-1.1.0.md`
- 项目介绍 PPT
  - `out/docs/1.1.0/aigateway-project-introduction-1.1.0.pptx`

## 4. 1.1.0 范围摘要

- 版本源：`helm/image-versions.yaml` 默认发布 bundle 切到 `aigateway-1.1.0`
- Chart：父 Chart、Console Chart、Portal Chart 版本切到 `1.1.0`
- 镜像：`aigateway/*` 一方镜像 tag 统一为 `1.1.0`
- 文档：新增 1.1.0 发布文档、镜像包说明、部署说明和项目介绍白皮书
- 演示材料：新增项目介绍 PPT，包含项目架构图和业务逻辑图

## 5. 验证要求

- `./start.sh help`
- `./start.sh show`
- `./start.sh sync --check`
- `./start.sh release-build --dry-run`
- `./start.sh release-deploy --target k8s --registry registry.example.com/team --dry-run`
- release values 的 `helm template`

## 6. 已知说明

- `k3d` 是首选正式验收环境
- 通用 `k8s` 部署要求提供可推送 registry
- Markdown 是仓库内正式文档真相源，Docx / PDF / PPTX 为导出交付件
