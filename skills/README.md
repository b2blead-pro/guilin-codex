# 用户级 Skill 分类说明

当前用户级 skill 已按大类和小类整理，真实 skill 目录不再直接平铺在本目录根部。

## 01-工程开发规范

### 01-通用规范

- `developer-coding-standards`：通用编码、Git、修 bug、补测试和工程协作规范。
- `fullstack-product-standards`：前后端一体 Web 产品开发、设计、交互、部署和联调规范。

### 02-代码治理

- `code-simplification`：代码精简、删除冗余、降低复杂度和小步重构。

### 03-前端验证

- `frontend-playwright-validation`：前端 UI、交互、路由、动画和浏览器行为的 Playwright 验证。

## 02-移动端开发

### 01-Android

- `developer-android`：Android、Java、Kotlin、Gradle、组件化和渠道构建开发规范。

### 02-HarmonyOS

- `developer-harmony`：HarmonyOS、ArkTS、ArkUI、Hvigor 和鸿蒙项目开发规范。

### 03-iOS

- `developer-ios`：iOS、Xcode、Swift、Objective-C、签名、证书和打包排查规范。

## 03-构建网络与环境维护

### 01-构建进程

- `gradle-java-process-cleanup`：Gradle、Kotlin Daemon、Java 构建进程占用排查和清理。

### 02-网络下载

- `download-network-proxy`：通用下载、GitHub、包管理器和脚本安装网络代理重试流程。
- `npm-proxy-download`：npm、npx、pnpm、yarn 和 Playwright 下载网络代理流程。

## 04-内容创作与知识沉淀

### 01-演示文稿

- `ppt-master`：PPT 生成、模板、图表、动画、素材处理和演示文稿工作流。

## 兼容入口

`.skill-links/` 目录里保留了到真实 skill 目录的隐藏链接，用于尽量兼容 Codex 对用户级 skill 的发现逻辑。这个目录默认不会干扰日常浏览。

如果重启 Codex 后发现某个 skill 没有被识别，可以把对应 skill 从分类目录移回本目录根部，或改用顶层链接兼容模式。
