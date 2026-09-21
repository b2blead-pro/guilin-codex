---
name: download-network-proxy
description: 下载、安装脚本、git clone/fetch、GitHub/raw.githubusercontent.com、包管理器或依赖拉取遇到连接超时、连接重置、TLS/SSL、DNS、速度极慢等网络问题时使用；指导 Codex 优先验证直连状态，必要时尝试通过本机代理 127.0.0.1:7890 重试下载访问，并在成功后验证结果。
---

# 下载网络代理

## 核心流程

遇到下载或远程拉取失败时，先确认失败类型和目标地址，再尝试使用本机代理 `127.0.0.1:7890` 重试。

优先使用一次短超时直连检查，避免把非网络问题误判成代理问题：

```bash
curl -I --max-time 15 <url>
```

如果出现连接超时、连接重置、TLS/SSL 握手失败、DNS 失败、速度极慢，或 GitHub/raw.githubusercontent.com 访问不稳定，使用代理环境变量重试：

```bash
export HTTP_PROXY="http://127.0.0.1:7890"
export HTTPS_PROXY="http://127.0.0.1:7890"
export ALL_PROXY="socks5://127.0.0.1:7890"
```

对单条命令优先使用临时环境变量，减少对用户 shell 的持久影响：

```bash
HTTPS_PROXY="http://127.0.0.1:7890" HTTP_PROXY="http://127.0.0.1:7890" <command>
```

## 常用场景

Git 命令可直接带代理配置重试：

```bash
git -c http.proxy=http://127.0.0.1:7890 -c https.proxy=http://127.0.0.1:7890 fetch --depth=1 origin main
```

curl 下载可显式指定代理：

```bash
curl -L --proxy http://127.0.0.1:7890 -o <file> <url>
```

Homebrew 等包管理器可用临时环境变量重试：

```bash
HTTP_PROXY="http://127.0.0.1:7890" HTTPS_PROXY="http://127.0.0.1:7890" brew update
```

## 注意事项

- 先判断代理端口是否可用：`nc -z 127.0.0.1 7890`。
- 不要把代理配置永久写入用户 shell 配置，除非用户明确要求。
- 如果代理失败，回退到直连结果并说明当前网络现象。
- 下载完成后执行可行的验证，例如版本检查、校验命令、构建或测试。
