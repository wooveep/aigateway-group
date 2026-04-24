# P4 Redis HA 与 PostgreSQL 平台层

- 状态：`done`
- 依赖：`P0`

## 目标

- 用 vendored 成熟 chart 替换轻量 Redis/数据库子图。
- 发布平台层正式切到 `Redis HA + PostgreSQL HA + pgvector`。

## 任务

- [ ] vendored Redis HA chart，采用 replication + Sentinel。
- [ ] vendored PostgreSQL HA chart，默认启用 pgvector-capable 镜像。
- [ ] 将父 chart 顶层值接口改为 `redis.* / postgresql.*`。
- [ ] 默认初始化 `vector` 扩展。
- [ ] 调整父 chart 与依赖 values 透传关系。
- [ ] 清理发布环境下旧 MySQL 兼容入口。
- [ ] 补齐 HA 模式下的 secret、persistence、service 和 readiness 配置入口。

## 验收点

- [ ] 发布包不再渲染单实例 Redis/旧数据库入口。
- [ ] PostgreSQL HA 与 Redis HA 均可从父 chart 一键启用。
- [ ] pgvector 作为发布默认能力可用。

## 测试

- [ ] `helm dependency build`。
- [ ] `helm template` 验证 Redis HA 与 PostgreSQL HA 渲染结果。
- [ ] pgvector 初始化与扩展可用性 smoke。
