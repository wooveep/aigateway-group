# AIGateway 项目介绍白皮书（1.0.0）

## 1. 项目定位

AIGateway 是一个围绕 AI Gateway 场景构建的平台化项目，目标是把模型接入、路由治理、计费、开放平台、智能体接入和插件分发收敛到同一套工程体系中。  
项目以 Higress 作为网关核心与运行时基座，在其上叠加控制面、用户门户和插件分发能力。

## 2. 四大子项目职责

### Portal

- 路径：`aigateway-portal`
- 面向最终用户和业务接入方
- 提供登录、API Key、账单、发票、模型广场、智能体广场、开放平台与 AI 对话能力

### Console

- 路径：`aigateway-console`
- 面向管理员和平台运维
- 提供组织管理、用户等级、模型资产、AI Route、MCP、运行时策略和配置下发

### Higress

- 路径：`higress`
- 提供网关核心、控制面 / 数据面、插件运行时、Helm 基座和 K8S 接入能力

### Plugin Server

- 路径：`plugin-server`
- 提供 Wasm 插件分发与插件下载地址管理

## 3. 核心能力矩阵

- AI 网关
  - 模型接入、AI Route、fallback、运行时鉴权、限流与路由治理
- 控制面
  - 组织、账号、用户等级、模型资产、智能体目录、MCP 配置、系统任务
- 门户
  - 账单、充值、消费明细、模型广场、智能体广场、开放平台
- 插件体系
  - Plugin Server 分发、内置 Wasm 插件、MCP Server 托管
- 发布与部署
  - Helm 父 Chart、release bundle、`k3d` 与通用 `k8s` 双目标部署

## 4. 典型使用场景

- 平台团队统一接入多个模型供应商，并通过 Console 管理 AI Route 和模型资产
- 业务用户通过 Portal 申请 API Key、查看模型价格、查看账单和开放平台调用统计
- 平台将 MCP Server 资产化，通过智能体目录向用户开放工具调用入口
- 运维团队通过 release bundle 在 `k3d` 或通用 `k8s` 中完成正式部署与验收

## 5. 部署架构

AIGateway 采用父 Chart 统一编排的方式部署：

- `higress-core`
  - 网关核心、Controller、Pilot、Gateway、Plugin Server、共享基础设施
- `aigateway-console`
  - 控制面服务
- `aigateway-portal`
  - 门户服务

共享基础设施基线：

- PostgreSQL
  - 当前正式口径为 PostgreSQL-only
  - Portal 与 Console 共享 Portal PostgreSQL
- Redis
  - 作为共享运行时缓存、流控和事件通道

## 6. 版本与发布策略

- 当前正式发布版本：`1.0.0`
- 仓库管理的一方镜像统一使用 `1.0.0`
- 第三方依赖镜像保持上游版本，通过 release bundle 的 `images.lock` 与 Helm values 锁定
- 正式发布接口固定为：
  - `./start.sh release-build`
  - `./start.sh release-deploy --target k3d|k8s`

发布 bundle 默认目录：

```text
out/release/aigateway-1.0.0/
```

## 7. 已知边界

- 当前数据库口径已固定为 PostgreSQL-only，不再以 MySQL 作为正式开发或部署口径
- release / deploy 入口保持纯 shell，不新增 Python 作为正式发布入口依赖
- 正式发布版本 `1.0.0` 是平台交付版本，不要求把所有第三方依赖镜像标签改写成 `1.0.0`
- 用户手册截图以 `1.0.0` 环境为准，历史截图仅作补拍对照，不作为正式交付真相源
