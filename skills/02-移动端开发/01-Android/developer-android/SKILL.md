---
name: developer-android
description: 进行 Android、Java、Kotlin、Gradle 开发，修改 Android 项目代码，做日志优化，排查 Android 报错，或处理组件化、JSAPI、comp-demo、comp-platform-api、Maven 发布、jiangxi 渠道构建时使用。要求统一 YLog.i/YLog.e 和 YLogTag，遵循项目架构、最小验证、Gradle 模块编译、adb 日志过滤、RecyclerView、JSAPI 测试、docs 同步和脚本规范。
---

# Android 开发规范

## 适用场景

- 修改 Android、Java、Kotlin、Gradle、卡片、JSAPI、组件化相关代码。
- 排查 Android 构建、运行、测试、文档同步问题。
- 用户提到 Android 项目、`guilinTest`、`jiangxi` 渠道、`comp-platform-api`、Maven 发布机制时。

## 编码规范

- 优先阅读当前模块已有实现，沿用项目既有架构、命名、封装方式和错误处理风格。
- `RecyclerView` 必须设置 `LayoutManager`，默认使用 `LinearLayoutManager`。
- 单独的功能模块应尽可能复用并封装为工具类，例如 `FileUtil`、`PermissionUtil`。
- 新增或修改 JSAPI 时，需要在 `guilinTest` 这张卡片下增加测试用例。
- JSAPI 测试用例必须覆盖多个测试场景，命名或说明可使用 `1.1`、`1.2`、`1.3` 这类编号。
- 新功能增加时，应在 `comp-demo` 模块下创建对应测试二级页面。
- `comp-demo` 模块下 Activity 主色调统一使用蓝色，测试结果类反馈优先用弹窗展示，新增 Activity 继承 `BaseActivity`。
- Java/Android 代码需要标注空值语义时，统一使用 `androidx.annotation.NonNull` 或 `androidx.annotation.Nullable` 修饰全局变量、成员变量、局部变量、参数和返回值，禁止新增 `org.jetbrains.annotations` 包。
- Java/Android 中表示枚举语义的字符串参数、返回值或配置项，必须使用 `@StringDef` 配合常量进行强约束；不要只暴露裸 `String` 或散落字符串字面量。
- 新增 Android 页面默认需要做沉浸式状态栏适配，除非宿主已有统一基类或主题自动处理。
- 沉浸式业务页头优先由页面根 `ConstraintLayout` 延伸到状态栏后方，状态栏高度作为顶部约束或显式 inset 参与测量；背景、标题、输入框和右侧操作分别锚定，禁止额外叠加一块固定高度的“状态栏颜色 View”。这样状态栏、页头背景和正文在不同设备上仍保持连续，设计稿中的顶部留白只计算一次。
- 可复用 View 的外部间距由父容器通过 `layout_margin*` 控制；组件内部 `padding` 只表达内容与自身边界的内间距，禁止用内部 padding 模拟它与上一个或下一个组件的距离。
- 同时包含图标和文字的业务按钮、胶囊或操作项，默认使用容器 + `ImageView` + `TextView` 复合布局，分别控制图标尺寸、文字基线和点击热区；禁止用单个 `TextView`、Unicode 图标或 compoundDrawable 近似设计稿，除非现有组件规范明确要求富文本或行内图标。
- 可复用组件的根高度和内容区高度优先使用 `wrap_content`，让真实文字、列表和子组件完成测量；只有设计明确固定尺寸的图标、触摸热区、图表视口等才使用固定高度。禁止为了对齐单张截图给整段业务内容写死高度，导致长文案被裁切或短文案留下大块空白。
- 自定义组件只要包含两个及以上稳定子元素，默认使用 XML + ViewBinding（或 `inflate + findViewById`）定义和加载层级，再由自定义 View 负责模型绑定、状态切换或必要绘图；禁止在初始化代码中完全依赖 `new View + addView` 拼装整棵稳定视图树，也不要在 Fragment/Activity 中用 `new TextView`、`repeat` 等方式拼装可复用业务组件。`addView` 仅用于服务端节点、可变条目等运行时数量确实不固定的内容；迁移已有组件时保持公开回调和状态协议不变。内容驱动的 XML 根容器使用 `wrap_content`，Canvas 只绘制折线、路径、波形等图形，文字由原生 `TextView` 排版。
- 多元素覆盖、剩余空间分配和相互锚定优先使用 `ConstraintLayout` 表达。例如底部导航中，导航组使用 `0dp` 宽度约束到右侧助手，助手同时约束导航组上下边界实现垂直居中，角标约束助手右上角，说明文字约束导航组下方和父容器底部。优先通过约束和 `layout_margin*` 表达组件关系，禁止依赖固定根高度、大块 padding 或运行时坐标推算。
- 组件需要“仅顶部圆角”“仅底部圆角”或父子两层不同背景时，分别创建 shape drawable 并设置对应 `corners`；不要用纯色背景替代局部圆角，也不要让子组件通过 padding 模拟父容器圆角区域。
- 轮询、WebSocket、行情推送和重复接口刷新默认采用差量更新。领域层先把响应转换为稳定、不可变且可结构比较的 UI Model；新旧 Model 完全相等时不发射新状态、不调用 `notifyDataSetChanged()`、不重复绑定文字或触发自定义 View 重绘。
- 列表使用稳定 ID 与 `ListAdapter + DiffUtil`（或等价的细粒度差分）；只更新发生变化的 item/字段。多区块页面按区块分别比较和提交，禁止一个行情字段变化就清空并重建整页、整个 RecyclerView 或所有图表。
- 页面已有可用内容时，后台刷新继续展示旧内容，不重新切到全屏 Loading、清空态或骨架屏；失败只更新对应区块的错误/过期状态。首次无内容时才显示首次加载态。
- 差量刷新不得重置 RecyclerView/NestedScrollView 位置、ViewPager 当前页、输入焦点、展开状态、动画进度、图表视口或用户当前十字光标；只有业务身份或用户主动操作明确要求重置时才允许重建这些状态。
- 自定义图表、波形和复杂 View 在 `setModel` 内先比较绘制所需字段；字段未变化时直接返回。变化时只失效受影响的绘制层，耗时路径计算可按稳定 key 缓存，但缓存必须在尺寸、数据、主题或配置变化时准确失效。
- 生命周期刷新任务只在宿主达到 `STARTED` 且 View 有效时运行，离开可见状态或销毁 View 后取消；恢复时只启动一个任务。验收至少覆盖连续三轮相同响应不闪烁、不重绑、不丢滚动位置，以及单项变化只刷新目标项。

## 日志规范

- 能依赖 `com.ynet.finmall.base.log.YLog` 的模块，日志统一使用 `YLog.i` 和 `YLog.e`。
- 替换 `Logger`、`System.out`、`android.util.Log` 和其他日志系统；如果当前模块找不到或不应依赖 `com.ynet.finmall.base.log.YLog`，不要强行引入跨层依赖。
- 禁止输出 `SSS`、`===` 这类无意义字符；需要格式美观时统一使用制表符 `\t`。
- 日志内容要简明扼要，尽量使用中文，避免重复输出同一信息。
- 会改变核心执行路径、失败原因、降级策略或提前结束的 `if`、`switch`、`catch`、`return` 分支要打印日志；普通空值保护和低价值循环分支不要制造噪声。
- 日志 tag 统一从 `com.ynet.finmall.base.api.YLogTag` 获取，不在业务代码里散落字符串 tag。
- 在 `comp-api` 或 `base-api` 对应包下集中维护 `YLogTag` 静态变量，例如 `TAG_H5`、`TAG_CARD`、`TAG_ANALYSIS`。
- tag 字符串使用稳定命名，例如 `YLog.h5`、`YLog.card`、`YLog.analysis`；JSAPI 按模块划分，日志量大的模块可使用二级 tag，例如 `YLog.h5.jsapi`。
- 修改日志时要同步删除替换后不再使用的 import。

## 文档规范

- `comp-platform-api` 下代码发生变更时，需要同步更新 `docs` 文档。
- 文档应放在 `docs` 下对应的文档目录中。
- 组件化依赖与 Maven 发布机制说明见 `docs/dev/组件化依赖与 Maven 发布机制说明.md`。

## 目录和依赖规范

- 创建新的module应该增加 .gitignore 文件，参考根目录的 .gitignore
- 与组件自身能力无强绑定的大资源，优先放在壳工程 `assets`，不要放在组件 `assets`；组件文档需说明资源路径，运行期缺失时要主动报错或打印清晰日志。
- 新建 Android 空 application 工程后，需要配置 `local.properties` 的 Android SDK 路径：`sdk.dir=/Volumes/Western_2T/Library/Android/sdk`；如果该路径不可用，先在本机查找实际 SDK 路径并同步更新本条规范。

## 构建验证

默认不要自动执行完整 Gradle 构建。新增或修改代码后优先对当前模块做最小化编译；修改 Gradle 文件后，必须验证当前 Gradle 模块编译是否成功。
如果修改了 Android `styles.xml`、`values-v*` 下的样式资源，或在 `AndroidManifest.xml` 中新增/修改 Activity 的 `android:theme`、新增 Activity 样式，不能只做 library 模块资源校验；必须按项目约定编译宿主主工程，确认最终 Manifest 合并与资源链接通过。

执行完整构建前先检查：

```bash
./gradlew --status
jps -lv
```

如果存在 BUSY 的 Gradle daemon、Android Studio 正在 Build/Run，或多个 Gradle/Kotlin daemon 明显占用资源，暂停构建并提示用户确认。Gradle 构建优先使用 `--no-daemon`，没有明确缓存问题时禁止执行 `./gradlew clean`。当前项目凡是涉及构建、测试、安装或真机验证，统一使用 `uat` 渠道，除非用户明确指定其他渠道。完整构建优先使用：

```bash
./gradlew :app-flame:assembleUatDebug --stacktrace --no-daemon
```

如果构建命令已包含 `--no-daemon`，完成后不需要再执行 `./gradlew --stop`；只有未使用 `--no-daemon` 或发现后台存在异常 Gradle daemon 时才执行 `./gradlew --stop`。

## 排查日志

- Android 报错优先用 `adb` 抓日志分析。
- 如果 `adb devices` 没有可用模拟器或开发任务需要 Android 模拟器，先执行 `mobile-emulator ensure android` 自动启动本机默认 AVD，不要每次临时推导 emulator 启动命令。
- 为节省上下文，先清空日志，再复现问题，然后按包名、tag、异常关键词过滤并限制行数。
- 常用流程是 `adb logcat -c`，复现后执行 `adb logcat -d -v time | rg "YLog|AndroidRuntime|FATAL EXCEPTION|Exception|<包名或关键词>" | tail -200`。



## **Android 设备测试规范**

- Android 开发后的安装、运行和测试优先使用 **ADB 已连接的真机**；有真机时不为本轮验证另启模拟器。
- 没有已连接真机时，优先复用**已在线的 Android 模拟器**；也没有在线模拟器时，调用 `mobile-emulator ensure android` 自动启动一个本机已有实例，等待 ADB 连接并进入 `device` 状态后继续验证，不能仅因没有在线模拟器就结束任务。
- 真机锁屏时优先使用已有的 **Android 设备解锁脚本/自动化能力**检测屏幕与锁屏状态并完成解锁，不复制、不记录、不回显 PIN、密码等敏感信息。
- 多个 Android 真机或模拟器同时连接、无法确定测试对象时，先明确目标设备或 `serial`，后续 ADB、安装、启动、日志和 UI 测试均固定指定该设备，不擅自批量执行单设备 UI 测试。
