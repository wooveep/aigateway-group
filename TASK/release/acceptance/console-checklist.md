# Console Chrome DevTools Checklist

必验页面：

- `/login`
- `/dashboard`
- `/consumer`
- `/ai/model-assets`
- `/ai/provider`
- `/ai/route`
- `/ai/quota`
- `/ai/agent-catalog`
- `/mcp/list`
- `/system/jobs`

每页执行：

- 首屏加载，无白屏或崩溃
- 点击主入口、抽屉、Tab、下拉、提交按钮至少一次
- 检查 Console 面板无未处理错误
- 检查 Network 面板无非预期 4xx/5xx
- 记录成功路径与失败提示各 1 次

关键业务流：

- 创建或编辑 AI Route
- 发布模型绑定
- 发布或下架智能体目录
