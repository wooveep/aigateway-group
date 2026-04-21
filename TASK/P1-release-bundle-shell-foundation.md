# P1 发布打包 Shell 基础

- 状态：`done`
- 依赖：`P0`

## 目标

- 落下纯 Shell 发布构建链路。
- 产出标准 bundle 目录、镜像 tar 与元数据。

## 任务

- [ ] 新增 `scripts/release-build.sh`。
- [ ] 在 `start.sh` 增加 `release-build` 兼容入口。
- [ ] 复用现有镜像构建能力，输出 `images/*.tar`。
- [ ] 打包父 chart，生成 `release-base.yaml / release-ha.yaml / release-upstreams.yaml`。
- [ ] 生成 `metadata/images.lock / release.env / SHA256SUMS`。
- [ ] 将自包含 `deploy.sh` 放入 bundle。
- [ ] 支持 `--bundle-name`、`--output-dir`、`--components`、`--dry-run` 等构建参数。

## 验收点

- [ ] 能从仓库一次产出完整 bundle。
- [ ] bundle 内部自描述，不依赖仓库源码目录运行。
- [ ] bundle 内的镜像、chart、values、元数据能互相对上。

## 测试

- [ ] `release-build --dry-run`。
- [ ] 实际 bundle 结构检查。
- [ ] `SHA256SUMS` 与镜像 tar / chart tgz 一致性检查。
