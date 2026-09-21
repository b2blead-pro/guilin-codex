---
name: repair-codex-remote-connection
description: 排查 macOS Codex Remote Control 或手机远程主机连接失败，包括代理超时、重复登记和桌面与 daemon 冲突；普通下载故障不适用。
---

# 修复 Codex 远程连接

按“进程 → 代理 → Codex 内部日志 → 登记状态 → 修复 → 重启验证”的顺序排查。先证明故障层级，再修改代理或停止进程，不要通过反复重启碰运气。

## 诊断入口

先运行只读脚本：

```bash
bash scripts/diagnose-codex-remote.sh
```

需要同时对比直连与本地代理的 HTTPS/WSS 路径时运行：

```bash
bash scripts/diagnose-codex-remote.sh --network
```

默认检查最近 30 分钟。使用 `--minutes 120` 调整日志窗口。脚本只读，不修改代理、数据库、认证或进程。

如果日志特征与本次案例相同，或需要理解为什么首次 daemon 方案不完整，再读 `references/案例复盘.md`。

## 分层判断

### 1. 本地代理不可用

满足任一条件时，先修复代理应用，不要修改 Codex：

- macOS 系统代理指向本地端口，但端口没有 `LISTEN`。
- 本地代理核心未运行或反复退出。
- 显式 `curl --proxy` 也无法及时得到 HTTP 响应。

检查代理应用当前节点、运行模式和本地端口。蜂窝加速器通常使用 `cellularCore` 与 `127.0.0.1:7890`，但必须以现场配置为准。

### 2. Codex 桌面进程未继承代理

典型证据：

- 普通 Codex 请求部分可用，但 `wss://chatgpt.com/backend-api/wham/remote/control/server` 每次 30 秒超时。
- 显式代理的 WSS 探测快速返回 `400`、`401` 或 `403`；这些状态说明网络传输已到服务器，不代表探测失败。
- `/Applications/ChatGPT.app/Contents/Resources/codex ... app-server` 没有 `HTTP_PROXY`、`HTTPS_PROXY`。
- `scutil --proxy` 已有系统代理。不要据此假设 Rust WebSocket 客户端一定会使用它。

确认后，将当前本地代理写入 macOS GUI 启动环境。代理地址必须来自现场配置：

```bash
launchctl setenv HTTP_PROXY http://127.0.0.1:7890
launchctl setenv HTTPS_PROXY http://127.0.0.1:7890
launchctl setenv http_proxy http://127.0.0.1:7890
launchctl setenv https_proxy http://127.0.0.1:7890
launchctl setenv NO_PROXY localhost,127.0.0.1
launchctl setenv no_proxy localhost,127.0.0.1
```

逐项执行 `launchctl getenv <变量名>` 验证。`launchctl setenv` 只影响之后启动的 GUI 进程，不能改变正在运行进程的环境。

### 3. 桌面 app-server 与托管 daemon 冲突

出现以下证据时只保留用户实际需要的一条远程连接：

- 日志包含 `409 Conflict` 或 `Remote app server already online`。
- `codex doctor` 显示后台 app-server 正在运行，同时桌面应用也启动了内嵌 app-server。
- daemon 与 `Codex Desktop` 复用了同一个远程环境。

以桌面 Remote 页面为目标时，停止托管 daemon：

```bash
codex remote-control stop --json
codex doctor --json
```

停止命令可能超时，但 daemon 已经实际退出。以 `codex doctor` 的 `background server is not running` 和进程检查为准，不要仅凭停止命令退出码判断。

如果用户明确需要无桌面应用的常驻 CLI 主机，保留 daemon；仅已确认需通过代理时才带代理启动，直连正常时使用普通启动命令。代理启动示例：

```bash
HTTP_PROXY=http://127.0.0.1:7890 \
HTTPS_PROXY=http://127.0.0.1:7890 \
codex remote-control start --json
```

不要同时把同一登记交给 daemon 和桌面内嵌 app-server。

### 4. 登记或认证问题

只有网络路径正常且不再存在进程冲突后，才处理登记：

- `remote_control_enabled=1` 且有现有 enrollment 时，不要先删数据库或退出登录。
- `401/403`、账号切换、工作区策略或配对失效时，按官方 Remote 流程重新启用或配对。
- 需要确认当前产品行为时，使用 `openai-docs` skill 获取最新 Codex 手册。

默认不要编辑 `~/.codex/state_*.sqlite`、`auth.json` 或代理应用生成的加密配置。

## 重启与验证

仅在修复需要新进程继承配置时重启。若需要重启当前承载对话的桌面应用，先完成可执行的修复并说明原因，再让用户执行 `⌘Q` 完全退出实际安装的应用后重新打开；关闭窗口不算完整退出。连接已恢复且无需重新加载配置时不额外重启。

按本次故障与目标连接路径选择验收项：

1. 验收实际承载连接的进程：桌面 Remote 检查内嵌 app-server，CLI 主机检查托管 daemon。两者不同时占用同一远程登记，不停止无关主机。
2. 仅修复代理继承或代理路径时，检查该进程的代理环境与到正确代理端口的连接；直连正常或仅修复登记、配对时，不要求代理变量或代理套接字。
3. 当前连接进程在修复后的日志中出现连接成功记录，例如：

   ```text
   remote control websocket status changed ... next_status=Connected
   connected to app-server remote control websocket
   ```

4. 原故障不再复现，没有影响连接的新错误；无关的历史告警不作为重复修复的理由。
5. 手机端刷新 Remote 页面后能重新选择目标主机。

针对原 30 秒超时或反复断线，使用修复后覆盖至少 60 秒的连续连接日志或观察结果验证稳定性；已有足够证据时不重新空等。其他故障使用对应的复现与连接验证。

## 安全边界

- 日志输出必须遮盖 token、authorization、account ID、server ID、environment ID 和 installation ID。
- 不因一次超时就覆盖代理订阅、节点数据库或 Codex 认证。
- 不创建全局 LaunchAgent、不写 shell 启动文件，也不启用 TUN，除非用户明确要求持久化并理解对其他应用的影响。
- `launchctl setenv` 通常只在当前 GUI 登录周期有效；注销或重启系统后可能需要重新应用。先向用户说明，再决定是否做更持久的系统改动。
- 蜂窝加速器等应用可能没有独立文本日志；可以结合运行配置、进程、监听端口、套接字和 Codex 端错误完成证据闭环。
