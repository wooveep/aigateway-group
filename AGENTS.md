# Repository Guidelines

## Root Document System

根目录文档按两条主线管理，避免同一事实在多个文件中漂移：

- 研发 / 产品主控
  - `Project.md`：稳定架构边界、协作规则、正式技术约束、统一入口
  - `roadmap.md`：阶段路线图、里程碑、默认实施假设
  - `task.md`：当前进行中事项、阻塞项、最近验证
  - `TODO.md`：执行清单与完成项账本
  - `Memory.md`：历史决策、已验证事实、重要 caveat
- 发布 / 部署主控
  - `TASK/README.md` 与 `TASK/P0~P7`：release bundle、部署目标、HA、回归与发布验收台账
- 正式交付文档
  - `docs/overview/`：项目介绍白皮书
  - `docs/release/1.0.0/`：发布说明、镜像包说明、K8S/K3D&Helm 部署说明
  - `docs/manual/1.0.0/`：用户手册

读取优先级固定为：

1. 先看 `Project.md` 判断边界和正式约束
2. 再看 `task.md` 判断当前在做什么
3. 再看 `TODO.md` 找执行项和完成状态
4. 追原因和历史时看 `Memory.md`
5. 涉及发布 / 部署 / bundle 时看 `TASK/` 和 `docs/release/1.0.0/`

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

## Formal Constraints

- 当前正式发布口径固定为 `1.0.0`
- 本仓库管理的一方镜像在正式发布时统一使用 `1.0.0`
  - `aigateway`
  - `aigateway/controller`
  - `aigateway/gateway`
  - `aigateway/pilot`
  - `aigateway/console`
  - `aigateway/portal`
  - `aigateway/plugin-server`
- 第三方依赖镜像保持上游版本，不强行改成 `1.0.0`
  - 通过 `images.lock`、Helm values 和 release bundle 锁定
- 数据库主线固定为 PostgreSQL-only
  - Portal / Console 共用 Portal PostgreSQL
  - Helm 统一入口为 `higress-core.postgresql.*`
- 正式发布与部署链路保持纯 shell
  - `./start.sh release-build`
  - `./start.sh release-deploy --target k3d|k8s`
- `helm/image-versions.yaml` 是镜像仓库 / 标签和默认发布参数的单一事实源
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
  - `helm/README.md`
  - `docs/release/1.0.0/`
- 需要正式对外说明时，优先更新 `docs/overview/`、`docs/release/1.0.0/`、`docs/manual/1.0.0/`

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
