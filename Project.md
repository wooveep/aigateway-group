# AIGateway Group 协作基线

最后更新：2026-04-22

## 1. 文档主控体系

根目录文档明确分成两条主线：

### 1.1 研发 / 产品主控

- `Project.md`
  - 记录稳定架构边界、仓库协作规则、正式技术约束
- `roadmap.md`
  - 记录阶段路线图、里程碑与默认实施假设
- `task.md`
  - 记录当前正在进行、阻塞项、最近更新与验证
- `TODO.md`
  - 记录执行清单、完成状态、待办账本
- `Memory.md`
  - 记录历史决策、验证事实、排障结论和注意事项

### 1.2 发布 / 部署主控

- `TASK/README.md`
- `TASK/P0-release-baseline.md` ~ `TASK/P7-e2e-validation-and-docs.md`

这组文档只负责 release bundle、部署目标、HA、发布验收，不承担日常产品研发状态记录。

### 1.3 正式交付文档

- `docs/overview/`
  - 对外 / 对管理层 / 对新同学的项目介绍与白皮书
- `docs/release/1.0.0/`
  - 发布说明、镜像包说明、K8S/K3D&Helm 部署说明
- `docs/manual/1.0.0/`
  - 用户手册、页面截图、访问入口说明

## 2. 子项目职责边界

| 子项目 | 路径 | 主要职责 |
| --- | --- | --- |
| Portal | `aigateway-portal` | 门户前后端、登录、API Key、账单、发票、模型广场、智能体广场 |
| Console | `aigateway-console` | 控制面前后端、组织与用户、模型资产、AI Route、MCP、运行时配置 |
| Higress | `higress` | 网关核心、控制面 / 数据面、插件与 Helm 基座 |
| Plugin Server | `plugin-server` | Wasm 插件分发与插件元数据服务 |

跨项目改动时，必须先判断“主落点”与“联动触点”，不能在多个项目里并行发散实现同一能力。

## 3. 正式技术约束

### 3.1 数据库与共享资源

- 当前项目数据库基线固定为 PostgreSQL-only
- Portal 与 Console 共享同一 Portal PostgreSQL
- Helm 中共享数据库入口固定为 `higress-core.postgresql.*`
- Redis 继续作为共享运行时缓存 / 流控 / 事件通道

### 3.2 版本与发布口径

- 当前正式发布版本固定为 `1.0.0`
- 本仓库管理的一方镜像在正式发布时统一打 `1.0.0`
- 第三方依赖镜像保持上游版本，通过 bundle 元数据和 Helm values 锁定
- 正式发布接口固定为：
  - `./start.sh release-build`
  - `./start.sh release-deploy --target k3d|k8s`

### 3.3 开发与部署统一入口

- `./start.sh`
  - 仓库统一高层入口
- `./helm/image-versions.yaml`
  - 仓库管理镜像 repository / tag、bundle 默认参数、namespace / releaseName 的单一事实源
- `./helm/dev-mode.yaml`
  - 开发模式服务开关与端口暴露真相源
- `./helm/higress`
  - 父 Chart 入口

## 4. 发布与部署基线

### 4.1 release bundle

正式 release bundle 默认目录命名为：

```text
out/release/aigateway-1.0.0/
```

bundle 结构固定包含：

```text
charts/
images/
values/
metadata/
deploy.sh
```

### 4.2 部署目标

- `k3d`
  - 作为首选正式验收环境
  - 用于本地完整 bundle 验收和 smoke
- 通用 `k8s`
  - 作为 registry override 部署路径
  - 通过 `docker load + retag/push + helm upgrade --install` 部署

### 4.3 发布文档落点

所有正式发布口径统一写入：

- `docs/release/1.0.0/release-notes.md`
- `docs/release/1.0.0/image-bundle.md`
- `docs/release/1.0.0/deployment-guide.md`

## 5. 协作规则

- 稳定边界或正式约束变化时更新 `Project.md`
- 当前进行中和阻塞变化时更新 `task.md`
- 执行状态变化时更新 `TODO.md`
- 历史结论、验证结果和重要 caveat 写入 `Memory.md`
- 发布链路、bundle 契约、部署命令变化时同步更新：
  - `TASK/README.md`
  - `helm/README.md`
  - `docs/release/1.0.0/`
- 不允许只改脚本 / values / Chart 而不改文档

## 6. 关联文档

- 路线图：[`roadmap.md`](./roadmap.md)
- 当前工作台：[`task.md`](./task.md)
- 执行清单：[`TODO.md`](./TODO.md)
- 历史记录：[`Memory.md`](./Memory.md)
- 发布台账：[`TASK/README.md`](./TASK/README.md)
- Helm 与开发入口：[`helm/README.md`](./helm/README.md)
- 正式文档索引：[`docs/README.md`](./docs/README.md)
