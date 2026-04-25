# 全局 TASK 文档索引

> 文档职责：根目录 `TASK/` 是全仓库统一任务与专项文档索引入口。  
> 子项目目录内只保留该项目自身的说明与轻量执行文档；跨子项目、专项分析、发布部署和 AI Agent 需要统一理解的索引，一律收口到根目录。

## 目录结构

### 1. 发布 / 部署主线

- `TASK/release/README.md`
- `TASK/release/P0-release-baseline.md` ~ `TASK/release/P7-e2e-validation-and-docs.md`

这组文档只负责 release bundle、部署目标、HA、发布回归和正式验收。

### 2. 子项目专项索引主线

- `TASK/projects/README.md`
- `TASK/projects/aigateway-console/`
- `TASK/projects/aigateway-portal/`
- `TASK/projects/higress/`
- `TASK/projects/plugin-server/`

这组文档负责：

- 跨子项目阅读时的专项文档索引
- AI Agent 需要理解的项目特有补充材料
- 迁移记录、专项矩阵、协议文档、对齐分析等不适合散落在子项目根目录的内容

## 子项目本地文档约束

每个子项目根目录只保留本项目自身的轻量入口文档：

- `README.md`
- `project.md`
- `TODO.md`
- `TASK.md`

如项目已存在 `memory.md` 等历史材料，可暂时保留，但根目录 `TASK/projects/<subproject>/README.md` 必须给出索引，避免 AI Agent 漏读。

## AI Agent 读取顺序

1. 先看根目录 `Project.md`
2. 再看根目录 `task.md`
3. 再看根目录 `TODO.md`
4. 再看根目录 `Memory.md`
5. 根据任务类型进入：
   - 发布 / 部署：`TASK/release/README.md`
   - 子项目专项材料：`TASK/projects/README.md`
6. 最后回到对应子项目根目录的 `README.md` / `project.md` / `TODO.md` / `TASK.md`

## 当前索引重点

- 发布与部署：见 `TASK/release/`
- Console GoFrame 重写 / Java parity / provider 协议专项：见 `TASK/projects/aigateway-console/`
- Portal / Higress / Plugin Server 当前先以项目根目录轻量文档为主，根目录 `TASK/projects/` 负责统一入口索引
- 新环境数据库初始化以 release 主线文档为准：`release-deploy` 现已包含显式 Portal/Console DB init 阶段
- release 首启稳定性以 release 主线文档为准：Console / Portal Pod 当前会先等待 PostgreSQL ready，再由应用内部重试 schema/bootstrap，不再依赖删 Pod 恢复
- release 监控与用量统计口径以 release 主线文档为准：`standard` profile 必须显式给 Portal 注入 `corePrometheusURL`
- release Redis / quota 运行态口径以 release 主线文档为准：`global.onlyPushRouteCluster` 必须为 `false`
