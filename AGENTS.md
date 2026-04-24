# Repository Guidelines

## Root Document System

根目录文档是 AI Agent 理解整个仓库的第一入口，避免同一事实在多个子项目中漂移。

- 研发 / 产品主控
  - `Project.md`：稳定架构边界、项目逻辑、正式技术约束、统一入口
  - `roadmap.md`：阶段路线图、里程碑、默认实施假设
  - `task.md`：当前进行中事项、阻塞项、最近验证
  - `TODO.md`：执行清单与完成项账本
  - `Memory.md`：历史决策、已验证事实、重要 caveat
- 根级 TASK 索引
  - `TASK/README.md`：根级 TASK 总索引
  - `TASK/release/README.md` 与 `TASK/release/P0~P7`：release bundle、部署目标、HA、回归与发布验收台账
  - `TASK/projects/README.md` 与 `TASK/projects/<subproject>/`：子项目专项材料、迁移记录、协议文档、矩阵和 AI Agent 需要统一索引的补充文档
- 正式交付文档
  - `docs/overview/`：项目介绍白皮书
  - `docs/release/<current-release>/`：发布说明、镜像包说明、K8S/K3D&Helm 部署说明
  - `docs/manual/<current-release>/`：用户手册

子项目根目录只保留该项目自身的轻量入口文档：

- `README.md`
- `project.md`
- `TODO.md`
- `TASK.md`

如子项目还存在 `memory.md` 等历史材料，根级 `TASK/projects/<subproject>/README.md` 必须给出索引，帮助 AI Agent 避免漏读。

读取优先级固定为：

1. 先看 `Project.md` 判断边界和正式约束
2. 再看 `task.md` 判断当前在做什么
3. 再看 `TODO.md` 找执行项和完成状态
4. 追原因和历史时看 `Memory.md`
5. 涉及发布 / 部署 / bundle 时看 `TASK/release/`
6. 涉及某个子项目的专项材料时看 `TASK/projects/`
7. 回到子项目根目录看该项目自身的 `README.md` / `project.md` / `TODO.md` / `TASK.md`

## Project Structure

本仓库协调四个主产品：

- `aigateway-portal`
  - 用户门户，GoFrame 后端 + Vue/Vite 前端
  - 负责登录、API Key、账单、发票、模型广场、智能体广场、开放平台
- `aigateway-console`
  - 控制面，GoFrame 后端 + Vue/Vite 前端
  - 负责组织、用户等级、模型资产、AI Route、MCP、运行时配置
- `higress`
  - 网关核心、控制 / 数据面、插件与 Helm 基座
- `plugin-server`
  - Wasm 插件分发

共享部署与开发入口在：

- `./start.sh`
- `./helm/`
- `./scripts/`

AI Agent 在跨子项目工作时，先判断主落点：

- 用户门户、账单、模型广场、开放平台：优先 `aigateway-portal`
- 控制面、组织、模型资产、AI Route、MCP、运行时配置：优先 `aigateway-console`
- 网关运行时、CRD、Helm、Wasm 插件、provider 协议转换：优先 `higress`
- 插件分发与下载地址模式：优先 `plugin-server`

## Formal Constraints

- 当前正式发布口径以显式版本源为准，不在本文件写死具体版本号
- 开发阶段可以读取当前 Git 分支理解当前工作上下文，但不要从分支名直接推导正式版本号
  - 分支名可能是 `dev`、功能分支，也可能是版本分支
  - Git 分支只用于辅助理解当前处于哪个工作流，不是正式版本真相源
  - 正式版本、镜像标签、bundle 名称、发布文档路径，优先以显式版本源为准，而不是以分支名猜测
  - 若当前任务不是 release / bundle / 对外交付 / 正式部署，就不要把任意历史发布版本默认套用到当前开发任务上
- 本仓库管理的一方镜像在正式发布时统一使用“当前正式发布版本”
  - `aigateway`
  - `aigateway/controller`
  - `aigateway/gateway`
  - `aigateway/pilot`
  - `aigateway/console`
  - `aigateway/portal`
  - `aigateway/plugin-server`
- 第三方依赖镜像保持上游版本，不强行改成仓库正式发布版本
  - 通过 `images.lock`、Helm values 和 release bundle 锁定
- 数据库主线固定为 PostgreSQL-only
  - Portal / Console 共用 Portal PostgreSQL
  - Helm 统一入口为 `higress-core.postgresql.*`
- 正式发布与部署链路保持纯 shell
  - `./start.sh release-build`
  - `./start.sh release-deploy --target k3d|k8s`
- `helm/image-versions.yaml` 是镜像仓库 / 标签和默认发布参数的单一事实源
  - release 版本判断优先参考这里的显式配置、release bundle 元数据和 `docs/release/<version>/`
- `docs/` 下 Markdown 是正式文档真相源，Docx / PDF 是导出件

## Build, Test, And Release Commands

优先使用仓库级入口，不手工拼接 ad hoc Helm / Docker / kubectl 命令：

- `./start.sh show`
- `./start.sh sync --check`
- `./start.sh build --components console,portal`
- `./start.sh minikube-dev`
- `./start.sh release-build`
- `./start.sh release-deploy --target k3d --cluster <name>`
- `./start.sh release-deploy --target k8s --registry <registry>`
- `helm template aigateway ./helm/higress -f ./higress/helm/higress/values-release-base.yaml -f ./higress/helm/higress/values-release-ha.yaml -f ./higress/helm/higress/values-release-upstreams.yaml`
- `cd aigateway-console/backend && go test ./...`
- `cd aigateway-portal/backend && go test ./...`
- `cd aigateway-console/frontend && npm run build`
- `cd aigateway-portal/frontend && npm run build`

## Coding Style And Naming

- Go 代码遵循 `gofmt` 与标准 `_test.go`
- Vue / TypeScript 使用 2 空格缩进
- 页面 / 组件文件使用 PascalCase，例如 `BillingPage.vue`
- service / interface 模块使用 kebab-case，例如 `services/model-asset.ts`
- GoFrame 分层约束：
  - Controller：参数绑定、鉴权入口、统一响应
  - Service：业务编排、事务控制、错误语义
  - DAO / Model：数据访问与对象映射
  - Client：Prometheus、外部系统与协议适配

## Documentation Update Rules

- 改动以下内容时，必须同步根文档：
  - `start.sh`
  - `scripts/release-build.sh`
  - `scripts/release-deploy.sh`
  - `helm/image-versions.yaml`
  - release values / Chart / 部署口径
- 稳定规则变更更新 `Project.md`
- 当前进行中和阻塞更新 `task.md`
- 执行项完成状态更新 `TODO.md`
- 已做事实与原因更新 `Memory.md`
- 发布链路、bundle 契约、部署命令变化时同步更新：
  - `TASK/README.md`
  - `TASK/release/README.md`
  - `helm/README.md`
  - `docs/release/<current-release>/`
- 子项目专项文档迁移、索引变化或 AI Agent 阅读入口变化时同步更新：
  - `TASK/projects/README.md`
  - `TASK/projects/<subproject>/README.md`
- 需要正式对外说明时，优先更新 `docs/overview/`、`docs/release/<current-release>/`、`docs/manual/<current-release>/`

## Testing Guidelines

- 先跑改动相关的最小测试，再跑更大范围验证
- 文档交付至少做：
  - `./start.sh help`
  - `./start.sh show`
  - `./start.sh sync --check`
  - `./start.sh release-build --dry-run`
  - `./start.sh release-deploy --target k8s --registry registry.example.com/team --dry-run`
  - release values 的 `helm template`
- 文档一致性用 `rg` 检查：
  - 旧版本号
  - 过期命令
  - MySQL 旧口径
  - 旧 chart 路径

## Commit And Pull Request Guidelines

- 提交信息保持短小、祈使句，可使用 `docs:`、`chore:` 等前缀
- 按子项目或文档主题分组，不要把无关改动混在一起
- PR 需要说明：
  - 触达模块
  - 验证命令
  - UI 截图或文档产物
  - API / 数据库 / Helm / 配置契约变化
