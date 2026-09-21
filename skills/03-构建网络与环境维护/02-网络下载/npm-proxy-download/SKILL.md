---
name: npm-proxy-download
description: npm、pnpm、yarn 或 Playwright 等 Node 下载因网络超时、断连而失败时，验证本地代理并对原命令临时重试。
---

# NPM 代理下载

## 目标

当 Node 下载出现网络故障时，验证本机代理后重试原下载命令；不把依赖冲突、权限错误当成网络问题。已知失败日志可直接作为依据，不重复等待同一次超时。

## 操作流程

1. 优先读取现场代理配置；配置未知时，按 `7890`、`7891`、`7892` 探测候选端口：

```bash
# 下载代理的候选本地端口；开放不代表代理协议可用。
for p in 7890 7891 7892; do
  nc -z 127.0.0.1 "$p" >/dev/null 2>&1 && echo "$p open" || echo "$p closed"
done
```

2. 对开放端口使用现场配置对应的协议，探测实际失败的下载地址。以下是 HTTP 代理示例；用实际端口和 URL 替换占位符：

```bash
curl -I --connect-timeout 5 --max-time 15 --noproxy "" \
  --proxy http://127.0.0.1:<port> <实际下载URL>
```

现场配置无法确认协议时，对候选端口分别以 `http://`、`socks5h://` 做上述短超时探测，找到可用协议后停止探测；不把猜测的协议直接用于完整安装。不能仅凭端口开放或配置值存在判定成功。确认目标响应允许下载；若返回认证、权限或资源错误，转而处理对应问题。服务不支持 HEAD 时用小范围 GET 验证，不重下整个文件。

3. 用已验证的协议为原命令临时注入代理；npm 配置环境变量兼容 npm 自身，HTTP 环境变量供 Playwright、node-gyp 等下载器使用：

```bash
npm_config_proxy=http://127.0.0.1:<port> \
npm_config_https_proxy=http://127.0.0.1:<port> \
HTTP_PROXY=http://127.0.0.1:<port> \
HTTPS_PROXY=http://127.0.0.1:<port> \
<download-command>
```

示例：

```bash
npm_config_proxy=http://127.0.0.1:7890 \
npm_config_https_proxy=http://127.0.0.1:7890 \
HTTP_PROXY=http://127.0.0.1:7890 \
HTTPS_PROXY=http://127.0.0.1:7890 \
npx playwright install chromium
```

## 注意事项

- 只设置已验证的协议；不要假设同一端口同时支持 HTTP 与 SOCKS。仅有 SOCKS 时先确认下载器支持对应配置。
- 候选代理均不可用时报告探测结果；相同故障且没有改变网络条件时，不循环重跑完整安装。
- 默认不写用户 `.npmrc` 或 shell 配置；只有用户明确要求持久化时才修改，并保留无关配置。
- 本次临时变量随命令结束失效，不删除或覆盖用户原有代理配置。下载后验证实际制品或版本，不为代理调整额外运行无关构建。
