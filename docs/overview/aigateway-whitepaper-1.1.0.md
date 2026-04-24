# AIGateway 项目介绍白皮书（1.1.0）

## 1. 项目定位

AIGateway 是围绕 AI Gateway 场景构建的平台化产品，目标是把模型接入、路由治理、计费、开放平台、智能体接入、MCP 能力和插件分发收敛到同一套工程体系中。

项目以 Higress 作为网关核心与运行时基座，在其上叠加 Console 控制面、Portal 用户门户和 Plugin Server 插件分发服务，形成“网关运行时 + 控制面治理 + 用户自助服务 + 发布交付”的完整闭环。

## 2. 四大子项目职责

### Portal

- 路径：`aigateway-portal`
- 面向最终用户和业务接入方
- 提供登录、企业 SSO 入口、API Key、账单、发票、模型广场、智能体广场、开放平台与 AI 对话能力

### Console

- 路径：`aigateway-console`
- 面向管理员和平台运维
- 提供组织管理、用户等级、模型资产、AI Route、MCP、智能体目录、运行时策略和配置下发

### Higress

- 路径：`higress`
- 提供网关核心、控制面 / 数据面、插件运行时、Helm 基座和 K8S 接入能力

### Plugin Server

- 路径：`plugin-server`
- 提供 Wasm 插件分发、插件元数据和插件下载地址管理

## 3. 核心能力矩阵

- AI 网关
  - 模型接入、AI Route、fallback、运行时鉴权、额度、限流、脱敏与路由治理
- 控制面
  - 组织、账号、用户等级、模型资产、智能体目录、MCP 配置、系统任务
- 门户
  - 账单、充值、消费明细、模型广场、智能体广场、AI 对话、开放平台
- 插件体系
  - Plugin Server 分发、内置 Wasm 插件、MCP Server 托管与授权投影
- 发布与部署
  - Helm 父 Chart、release bundle、`k3d` 与通用 `k8s` 双目标部署

## 4. 1.1.0 发布重点

- 正式版本源统一推进到 `1.1.0`
- 仓库管理的一方镜像统一使用 `1.1.0`
- release bundle 默认目录为 `out/release/aigateway-1.1.0/`
- 发布文档新增 `docs/release/1.1.0/`
- 项目介绍文档新增 `docs/overview/aigateway-whitepaper-1.1.0.md`
- 项目介绍 PPT 输出到 `out/docs/1.1.0/aigateway-project-introduction-1.1.0.pptx`

## 5. 部署架构

AIGateway 采用父 Chart 统一编排：

- `higress-core`
  - Gateway、Controller、Pilot、Plugin Server、Redis、PostgreSQL 等核心组件
- `aigateway-console`
  - 控制面服务，负责资产、组织、策略和运行时配置
- `aigateway-portal`
  - 用户门户服务，负责自助接入、账务、模型和智能体入口

共享基础设施基线：

- PostgreSQL
  - 当前正式口径为 PostgreSQL-only
  - Portal 与 Console 共用 Portal PostgreSQL
- Redis
  - 作为共享运行时缓存、流控和事件通道

## 6. 典型业务流

1. 管理员在 Console 接入模型 Provider，并发布模型资产。
2. Console 将模型资产、价格、授权和路由策略投影到共享库与 Higress 运行时。
3. 用户在 Portal 查看模型广场和智能体广场，申请 API Key 并发起调用。
4. Gateway 执行鉴权、额度、限流、脱敏、模型路由和供应商协议适配。
5. Portal 聚合账务、消费明细和开放平台调用统计，形成用户侧闭环。

## 7. 发布策略

- 当前正式发布版本：`1.1.0`
- 仓库管理的一方镜像统一使用 `1.1.0`
- 第三方依赖镜像保持上游版本，通过 release bundle 的 `images.lock` 与 Helm values 锁定
- 正式发布入口固定为：
  - `./start.sh release-build`
  - `./start.sh release-deploy --target k3d|k8s`

发布 bundle 默认目录：

```text
out/release/aigateway-1.1.0/
```

## 8. 已知边界

- 当前数据库口径固定为 PostgreSQL-only，不再以 MySQL 作为正式开发或部署口径
- release / deploy 入口保持纯 shell，不新增 Python 作为正式发布入口依赖
- 第三方依赖镜像不强行改写为 `1.1.0`
- 完整端到端部署验收仍依赖本机具备 Docker、Helm、kubectl、k3d 或可推送 registry
