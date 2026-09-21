---
name: npm-proxy-download
description: Configure and use a local proxy for npm-related downloads. Use when npm, npx, pnpm, yarn, Playwright browser install, or other Node package download/install commands fail, hang, timeout, or appear blocked by network access; prefer probing 127.0.0.1 ports 7890, 7891, and 7892 before retrying.
---

# NPM 代理下载

## 目标

当 npm 相关下载失败、卡住或超时时，先尝试本机代理再重试。默认优先使用 `127.0.0.1:7890`，如果不可用再检查 `7891`、`7892`。

## 操作流程

1. 探测代理端口：

```bash
for p in 7890 7891 7892; do
  nc -z 127.0.0.1 "$p" >/dev/null 2>&1 && echo "$p open" || echo "$p closed"
done
```

2. 选择第一个 open 端口，配置 npm 用户级代理：

```bash
npm config set proxy http://127.0.0.1:<port>
npm config set https-proxy http://127.0.0.1:<port>
npm config get proxy
npm config get https-proxy
```

3. 对下载命令同时注入环境变量。Playwright、node-gyp 或部分安装脚本不一定读取 npm config，环境变量更稳：

```bash
HTTP_PROXY=http://127.0.0.1:<port> \
HTTPS_PROXY=http://127.0.0.1:<port> \
ALL_PROXY=socks5://127.0.0.1:<port> \
<download-command>
```

示例：

```bash
HTTP_PROXY=http://127.0.0.1:7890 \
HTTPS_PROXY=http://127.0.0.1:7890 \
ALL_PROXY=socks5://127.0.0.1:7890 \
npx playwright install chromium
```

## 注意事项

- 不要直接假设代理已生效；配置后用 `npm config get proxy` 和 `npm config get https-proxy` 确认。
- 如果 `7890` 不可用，自动尝试 `7891`、`7892`；三个端口都不可用时，再报告代理不可用。
- 需要持久化 npm 配置时使用用户级 `.npmrc`，通常位于 `~/.npmrc`。
- 下载完成后不要主动清除代理，除非用户明确要求。
