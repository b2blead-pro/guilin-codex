---
name: frontend-playwright-validation
description: Verify frontend UI, interaction, routing, animation, and browser behavior changes with Playwright. Use when Codex modifies or reviews frontend pages, visual states, click flows, menus, forms, search, drag/resize behavior, export/download actions, login flows, or any user-visible browser interaction; prefer real browser validation before reporting completion.
---

# 前端 Playwright 验证

## 核心偏好

涉及前端页面、交互、UI 状态、路由跳转、动画、菜单、搜索、表单、下载、拖拽、登录态等改动时，完成代码修改和构建后，优先使用 Playwright 做真实浏览器验证。不要只依赖源码推断。

## 验证流程

1. 先确认应用已启动，并记录访问地址，例如 `http://localhost:8097/`。
2. 使用 Playwright 打开真实页面，必要时完成登录。
3. 按用户描述的操作路径点击、输入、悬浮、失焦、拖拽或切换路由。
4. 断言关键 DOM、样式、URL、可见性、尺寸、下载、接口提示或动画状态。
5. 最终回复中说明验证过哪些操作，以及是否通过。

## 执行建议

- 优先复用项目已有 Playwright 依赖；没有浏览器内核时可执行 `npx playwright install chromium`。
- 如果下载卡住或失败，使用 `$npm-proxy-download` 的代理流程后重试。
- 如果系统已有 Chrome，可用 Playwright 的 `executablePath` 指向本机 Chrome 作为兜底。
- 验证前端闪烁、动画或过渡时，使用截图、时间等待、样式读取或多帧状态检查。
- 对登录页面，优先从项目环境变量、`.env.example` 或后端配置中确认默认账号，不凭空猜测。

## 结果要求

- 验证失败时继续修复，不要把显然可继续处理的问题交还给用户。
- 如果确实无法运行 Playwright，需要说明原因，并提供已完成的替代验证。
- 最终用中文简洁说明：改了什么、Playwright 验证了什么、还有什么风险。
