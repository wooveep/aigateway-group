# P7 端到端验收与文档收尾

- 状态：`doing`
- 依赖：`P2 + P3 + P5 + P6`

## 目标

- 完成端到端验收、任务收尾和发布文档更新。

## 任务

- [x] 补齐根级 `TASK/README.md` 当前进度与最近更新。
- [x] 更新根文档、`helm/README.md`、相关部署文档。
- [x] 输出发布与回归命令清单。
- [x] 收口仓库级测试闸门到 `./start.sh test --stage unit|integration|e2e|acceptance|release`。
- [x] 为 Chrome DevTools 页面验收补模板与校验脚本，并纳入发布阻断。
- [ ] 完成 `fresh bundle -> k3d 部署 -> k8s 部署 -> 上游多副本请求验证`。
- [x] 明确已知限制：本次不包含 MySQL 到 PostgreSQL 的存量迁移工具。
- [x] 形成最终 smoke / 回归记录，便于后续版本继续迭代。

## 验收点

- [x] 文档、脚本、values、TASK 台账一致。
- [ ] 新人按文档能完成构建 bundle 和部署。
- [x] 已知限制和未覆盖项有明确记录。

## 测试

- [x] 仓库级 test gate 入口与 acceptance 模板。
- [ ] 端到端安装回归。
- [ ] 多副本入口访问验证。
- [ ] 上游 API 多 endpoint 负载验证。
- [ ] PostgreSQL / Redis HA Ready 与基本读写验证。

## 当前 smoke / 回归记录

- 已通过：
  - `./start.sh show`
  - `./start.sh sync --check`
  - `bash -n start.sh scripts/test.sh`
  - `python3 -m py_compile scripts/validate-acceptance.py plugin-server/generate_metadata.py plugin-server/pull_plugins.py plugin-server/tests/test_plugin_scripts.py`
  - `cd plugin-server && python3 -m unittest discover -s tests -p 'test_*.py'`
  - `./start.sh release-build --dry-run`
  - `helm template aigateway ./helm/higress -f ./higress/helm/higress/values-release-base.yaml -f ./higress/helm/higress/values-release-ha.yaml -f ./higress/helm/higress/values-release-upstreams.yaml`
  - `./start.sh release-deploy --target k8s --bundle-dir out/release/p7-smoke-20260417 --registry registry.example.com/team --skip-import --dry-run`
  - `GOTOOLCHAIN=auto go test ./utility/clients/portaldb -run TestEnsureSchemaAndMigrateLegacyDataAgainstPostgres -count=1`
  - `GOTOOLCHAIN=auto go test ./internal/service/portal -run TestPortalReadsConsoleWrittenSharedSchemaRowsOnPostgres -count=1`
- 已记录的真实行为：
  - `./start.sh test --stage acceptance` 若未填写 `out/test-acceptance/latest/summary.json` 会生成模板并阻断发布，符合 Chrome DevTools 手工验收闸门预期。
  - `./start.sh release-build --skip-build --bundle-name p7-smoke-20260417` 已成功生成 `charts/`、`values/`、`metadata/` 与 `deploy.sh`。
  - 同一次 bundle 构建在导出 `images/*.tar` 时失败，原因是 `aigateway/console:2.2.0-dev-20260416215530` 不在本机，且远端仓库不可拉取。
- 当前未覆盖：
  - 本机缺少 `k3d`，因此 `k3d` 目标 deploy dry-run / 实装未执行。
  - 尚未在真实集群完成多副本入口访问、上游多 endpoint 负载和 `PostgreSQL / Redis HA Ready` 验证。
