---
name: developer-harmony
description: 进行 HarmonyOS、ArkTS、ArkUI、Hvigor 开发，修改鸿蒙项目代码，排查鸿蒙报错，处理 oh-package.json5、module、Stage 模型、资源、路由、状态管理或 hdc 日志分析时使用。要求遵循项目既有架构和组件风格，保持 ArkTS 类型约束，遵守 new Object() 对象创建、@Builder function 限制和鸿蒙日志规范。
---

# HarmonyOS / ArkTS 开发规范

## 适用场景

- 修改 HarmonyOS、ArkTS、ArkUI、ets、module、Hvigor、oh-package 相关代码。
- 处理页面、组件、路由、状态管理、资源、权限、网络、构建配置等问题。
- 用户提到鸿蒙、HarmonyOS、ArkTS、ArkUI、Stage 模型、Hvigor 时。

## 编码规范

- 优先阅读当前模块已有实现，沿用项目既有目录结构、组件拆分、命名、状态管理和错误处理风格。
- ArkTS 代码保持明确类型约束，避免无必要的 `any`、隐式动态结构和跨层透传未定义字段。
- ArkTS 创建对象时不要使用 `{}`，按项目约束使用 `new Object()`。
- `@Builder function` 方法体里不能单独一行定义变量，只能写 UI component syntax。
- UI 组件应保持职责单一；可复用逻辑优先抽到工具类、服务类或独立组件。
- 状态管理要收敛在合适层级，避免无关组件共享可变状态。
- 资源引用优先使用项目既有 `resources`、常量、主题和国际化写法，不硬编码可复用文案、颜色、尺寸。
- 涉及权限、系统能力、生命周期、异步回调时，要处理失败分支和异常分支。
- 接口层统一放在 `ynet-foundation/comp_platform_api` 目录下（如果有的话），不同组件建立不同包。
- 组件间不要互相依赖，使用底层 api 接口通信。

## 日志规范

- 能依赖 `@ynet/comp_platform_api/Index` 的模块，日志统一使用 `YLog.info(tag?: string, message?: string)` 和 `YLog.error(tag: string, message: string, err: Error)`。
- 禁止输出 `SSSSS`、`=======` 这类无意义字符；需要格式美观时统一使用制表符 `\t`。
- 日志内容要简明扼要，尽量使用中文，避免重复输出同一信息。
- 会改变核心执行路径、失败原因、降级策略或提前结束的 `if`、`switch`、`catch`、`return` 分支要打印日志；普通空值保护和低价值循环分支不要制造噪声。
- 日志 tag 统一在 `comp_platform_api` 组件集中导出 `TAG_***` 常量，例如 `export let TAG_H5 = 'YLog.h5'`。
- tag 字符串使用稳定命名，例如 `YLog.h5`、`YLog.card`、`YLog.analysis`；JSAPI 按模块划分，日志量大的模块可使用二级 tag，例如 `YLog.h5.jsapi`。

## 验证规范

- 改完代码后，优先执行项目中已有的 Hvigor 构建、lint、单测或可运行检查。
- 如果仓库提供封装脚本，优先使用项目脚本，而不是临时拼装新命令。
- 默认不要自动执行完整构建；修改涉及依赖、`oh-package.json5`、跨多个 module 或最终确认可编译时，才执行完整构建。
- 完整构建优先使用 `/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleApp --no-daemon -p product=default`。
- 没有明确缓存问题时不要执行 clean。
- 无法执行验证时，在最终回复中说明原因和剩余风险。

## 排查日志

- 鸿蒙报错优先用 `hdc` 抓日志分析。
- 安装、运行和测试先用 `hdc list targets -v` 发现 `Connected` 设备，优先真机（USB 或非回环 TCP）；有真机时不额外启动模拟器。多个真机的单设备测试需先明确目标。
- 没有真机时复用已在线的鸿蒙模拟器（本机回环 TCP）；两者都没有且本轮确需设备验证时，按下方设备测试规范启动已有 HVD。
- 真机锁屏时按 [harmony-device-unlock](../../04-模拟器与设备/harmony-device-unlock/SKILL.md) 调用本地脚本；不要打印 PIN，不自动清空应用数据解决签名问题。
- 使用项目已有构建、安装和测试脚本；若脚本仍强制只用模拟器，应同步修正设备选择。实际验证必须注明真机或模拟器、系统版本、渠道和制品，连接或启动失败不能冒充通过。
- 为节省上下文，先清空或记录复现窗口，再按包名、tag、异常关键词过滤，并限制输出行数。
- 一次性读取复现日志使用 `hdc shell hilog -x | rg "Error|Exception|Fatal|<包名或关键词>" | tail -200`；多个设备时为 `hdc` 指定目标。需要实时采集时先确定截止时间或结束事件，避免将持续日志流直接传给等待输入结束的 `tail`。



## 鸿蒙设备测试规范

- HarmonyOS 开发后的安装、运行和测试优先使用 HDC 已连接的真机；有真机时不为本轮验证另启模拟器。
- 没有已连接真机时，复用在线鸿蒙模拟器；两者都没有且本轮确需设备验证时，若 `mobile-emulator` 可用，调用 `mobile-emulator ensure harmony` 启动已有实例；不可用时使用项目现有启动脚本或 DevEco Studio 的设备管理器启动已有兼容 HVD。以 HDC 显示 `Connected` 为就绪条件，单次启动最多等待 120 秒；超时、缺少兼容 HVD 或启动工具不可用时报告阻塞，并继续可独立完成的验证，不循环重启或自动下载系统镜像。
- 真机锁屏时使用 `harmony-device-unlock` 的本地脚本检测和解锁，不复制或回显 PIN。多个真机无法确定测试对象时先明确目标，不擅自批量执行单设备 UI 测试。
