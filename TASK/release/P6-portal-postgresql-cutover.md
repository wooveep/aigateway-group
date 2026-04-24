# P6 Portal PostgreSQL 切换

- 状态：`done`
- 依赖：`P4`

## 目标

- Portal 后端与 Helm 注入切到 PostgreSQL。

## 任务

- [x] 将 portal 配置从 `PORTAL_MYSQL_*` 收口到 PostgreSQL 路径。
- [x] 修改 Helm backend deployment 注入逻辑。
- [x] 调整后端驱动、DSN 解析、初始化、健康检查。
- [x] 清理 bundled MySQL chart 在发布路径中的依赖。
- [x] 更新 portal README / 部署示例。
- [x] 对齐 portal 与 console 的数据库 secret 和连接配置命名。

## 验收点

- [x] Portal 在 PostgreSQL 驱动下完成 shared schema 读取、模型目录查询与 scope user 烟测。
- [x] 发布环境不再依赖 portal 内置 MySQL。
- [x] 发布数据库配置命名在 console / portal / chart 三处保持一致。

## 测试

- [x] Portal 配置包与服务包可以按 PostgreSQL 驱动编译。
- [x] Portal PostgreSQL 容器集成烟测已补齐。
- [x] Portal 配置与服务包已通过 PostgreSQL 编译与 runtime smoke。
