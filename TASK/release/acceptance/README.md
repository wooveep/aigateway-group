# Chrome DevTools 验收说明

该目录用于发布前 `chrome-devtools` 页面点击验收。

执行方式：

1. 运行 `./start.sh test --stage acceptance`
2. 首次运行会在 `out/test-acceptance/latest/` 生成模板文件
3. 使用 `chrome-devtools` 按 `console-checklist.md` 与 `portal-checklist.md` 完成点击验收
4. 将结果写入 `summary.json`，并把截图放到 `screenshots/`
5. 再次运行 `./start.sh test --stage acceptance`，校验通过后才能进入 release gate

校验要求：

- `summary.json.tool` 必须是 `chrome-devtools`
- 所有必验页面与关键业务流都必须标记为 `pass`
- `consoleErrors` 与 `networkFailures` 必须清空
- `notes.md` 记录额外说明、截图名和人工判断
