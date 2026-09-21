---
name: download-network-proxy
description: 非 Node 下载或已授权的远程拉取发生网络故障时，验证直连与本地代理并临时重试。Node 包与 Playwright 下载使用 npm-proxy-download。
---

# 下载网络代理

## 核心流程

遇到下载或远程拉取失败时，先确认失败类型和目标地址，再尝试使用本机代理 `127.0.0.1:7890` 重试。

优先使用一次短超时直连检查，避免把非网络问题误判成代理问题：

```bash
curl -I --connect-timeout 5 --max-time 15 --noproxy '*' <url>
```

已有日志足以确认直连网络故障时可复用结果。出现超时、连接重置、TLS/SSL 或 DNS 故障后，先用现场配置的代理协议对同一目标做短超时探测：

```bash
curl -I --connect-timeout 5 --max-time 15 --noproxy "" \
  --proxy http://127.0.0.1:7890 <url>
```

对单条命令优先使用临时环境变量，减少对用户 shell 的持久影响：

```bash
HTTPS_PROXY="http://127.0.0.1:7890" HTTP_PROXY="http://127.0.0.1:7890" <command>
```

## 常用场景

Git 命令可临时增加代理配置，保留原先已授权的操作、仓库和参数，不因网络重试新增拉取或切换分支：

```bash
git -c http.proxy=http://127.0.0.1:7890 <原已授权的子命令与参数>
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

- `nc -z 127.0.0.1 7890` 只能筛选开放端口；代理协议与目标访问仍须通过短超时探测，不假设同一端口同时支持 HTTP 与 SOCKS。
- 不要把代理配置永久写入用户 shell 配置，除非用户明确要求。
- 如果代理失败，结合已有直连结果说明故障；条件未变化时不重复失败的完整下载。认证、权限或资源错误不通过切换代理反复重试。
- 下载完成后验证制品完整性或版本；只有任务本身需要时才继续构建或测试。
