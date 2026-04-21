# P5 Console PostgreSQL 切换

- 状态：`done`
- 依赖：`P4`

## 目标

- Console 运行时和 Helm 注入切到 PostgreSQL。

## 任务

- [x] 将 console 发布默认 DB driver 改为 PostgreSQL。
- [x] 调整 Helm deployment 中的数据库环境变量、DSN 和 secret 读取。
- [x] 更新连接初始化、健康检查、配置默认值。
- [x] 保证 console 对 portal/core DB 的访问都走 PostgreSQL 路径。
- [x] 清理发布文档里的 MySQL 入口。
- [x] 评估并更新 console 相关 DB 测试样例与集成测试依赖。

## 验收点

- [x] Console 在 PostgreSQL 驱动下完成 schema / legacy migration / runtime SQL 烟测。
- [x] 发布环境不再注入 MySQL 专用变量。
- [x] 与发布 values 和 deploy 脚本的数据库入口保持一致。

## 测试

- [x] Console DB 配置解析测试覆盖 PostgreSQL 路径。
- [x] Console DB 相关 PostgreSQL 集成烟测已补齐。
- [x] Console portaldb PostgreSQL smoke 已验证 `EnsureSchema + MigrateLegacyData`。
