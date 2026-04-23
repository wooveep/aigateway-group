# AIGateway 正式文档索引

本目录用于维护仓库内正式交付文档的 Markdown 真相源。

## 目录

- `overview/`
  - 项目介绍白皮书
- `release/1.0.0/`
  - 发布说明
  - 镜像包说明
  - K8S / K3D&Helm 部署说明
- `manual/1.0.0/`
  - 用户手册
  - 页面截图引用

## 当前正式版本

- 正式发布版本：`1.0.0`
- 仓库管理的一方镜像：统一使用 `1.0.0`
- 第三方依赖镜像：保持上游版本，通过 bundle 元数据与 Helm values 锁定

## 关联入口

- 架构与规则：[`../Project.md`](../Project.md)
- 发布台账：[`../TASK/README.md`](../TASK/README.md)
- Helm 入口：[`../helm/README.md`](../helm/README.md)

## 导出方式

- Markdown 真相源导出到正式交付件：
  - `python3 -m venv .venv-docs`
  - `.venv-docs/bin/pip install python-docx`
  - `.venv-docs/bin/python scripts/export-formal-docs.py`
- 默认输出目录：
  - `out/docs/1.0.0/`
