# P0 发布基线冻结

- 状态：`done`
- 依赖：无

## 目标

- 冻结发布包目录结构、CLI 参数、values 分层和镜像锁文件格式。
- 冻结上游负载配置模型与 PostgreSQL/Redis HA 的对外值接口。
- 明确这次发布链路直接切 PostgreSQL，不保留 MySQL 发布入口。

## 任务

- [ ] 梳理当前 `start.sh`、`scripts/`、`higress/helm/*`、父 chart、console/portal Helm 注入点。
- [ ] 输出 bundle 目录结构与 `images.lock` 字段定义。
- [ ] 输出 `release-build.sh` / `release-deploy.sh` CLI 契约。
- [ ] 输出 `release-base.yaml`、`release-ha.yaml`、`release-upstreams.yaml` 的职责边界。
- [ ] 输出 `release.upstreams[]` 与 `higress-core.redis.* / postgresql.*` 值接口契约。
- [ ] 明确发布链路与本地开发链路的边界，不让 `minikube-dev` 与 release 逻辑混用。

## 验收点

- [ ] 实现阶段无需再对发布包结构和接口做决策。
- [ ] 后续阶段只实现既定接口，不再重定义字段。
- [ ] `TASK/README.md` 的当前焦点和本阶段文档保持一致。

## 测试

- [ ] 对照现有脚本和 chart，完成接口与入口基线核对。
- [ ] 核对阶段输出是否覆盖 bundle、deploy、upstream、Redis/PostgreSQL 四类关键接口。
