---
name: repair-codex-remote-connection
description: 诊断并修复 macOS 上 Codex Remote Control、手机远程连接、Remote 页面或远程主机离线问题。用户提到 Codex 远程连接失败、Remote Control 一直 Connecting/Errored、WebSocket 30 秒超时、蜂窝加速器/Clash/Surge 等本地代理下 Codex 普通请求可用但远程不可用、重启后仍失败、remote app server already online、409 Conflict，或要求检查 Codex 与代理日志时使用。
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

如果用户明确需要无桌面应用的常驻 CLI 主机，才保留 daemon，并用显式代理启动：

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

如果当前任务就在 Codex 桌面应用中，不要直接退出应用，否则会中断当前对话。完成配置后，让用户执行 `⌘Q` 完全退出 `/Applications/ChatGPT.app`，再重新打开；关闭窗口不算完整退出。

重启后必须同时满足：

1. 新桌面 app-server PID 的环境中存在正确的 `HTTP_PROXY`、`HTTPS_PROXY`。
2. 目标是桌面 Remote 时，托管 daemon 未运行。
3. 新 PID 的日志出现：

   ```text
   remote control websocket status changed ... next_status=Connected
   connected to app-server remote control websocket
   ```

4. 新 PID 启动后的远程模块没有新的 `WARN` 或 `ERROR`。
5. 能看到该 PID 到本地代理端口的 `ESTABLISHED` 连接。
6. 手机端刷新 Remote 页面后能重新选择主机。

观察至少 60 秒，避免把一次瞬时连接当作修复完成。

## 安全边界

- 日志输出必须遮盖 token、authorization、account ID、server ID、environment ID 和 installation ID。
- 不因一次超时就覆盖代理订阅、节点数据库或 Codex 认证。
- 不创建全局 LaunchAgent、不写 shell 启动文件，也不启用 TUN，除非用户明确要求持久化并理解对其他应用的影响。
- `launchctl setenv` 通常只在当前 GUI 登录周期有效；注销或重启系统后可能需要重新应用。先向用户说明，再决定是否做更持久的系统改动。
- 蜂窝加速器等应用可能没有独立文本日志；可以结合运行配置、进程、监听端口、套接字和 Codex 端错误完成证据闭环。
