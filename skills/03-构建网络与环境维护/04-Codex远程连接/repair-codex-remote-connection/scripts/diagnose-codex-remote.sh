#!/usr/bin/env bash
# 只读诊断 macOS 上的 Codex Remote Control、桌面 app-server 与本地代理链路。
# 用法：bash scripts/diagnose-codex-remote.sh [--minutes N] [--network]

set -u
set -o pipefail

# 最近日志查询窗口，单位为分钟。
lookback_minutes=30
# 是否执行直连与代理网络探测。
probe_network=false
# Codex 用户状态目录。
codex_home_dir="${CODEX_HOME:-$HOME/.codex}"
# Codex SQLite 日志数据库，初始化后从现有版本中选择编号最大的文件。
log_db_path=""
# Codex SQLite 状态数据库，初始化后从现有版本中选择编号最大的文件。
state_db_path=""
# 从 macOS 系统代理中解析出的 HTTPS 代理主机。
proxy_host=""
# 从 macOS 系统代理中解析出的 HTTPS 代理端口。
proxy_port=""

# 从带数字版本后缀的 SQLite 文件中选择编号最大的一个。
select_latest_db() {
  # 数据库文件名前缀，例如 logs 或 state。
  local db_prefix="$1"
  # 当前找到的数据库路径。
  local selected_path=""
  # 当前找到的最大数字版本。
  local selected_version=-1
  # 候选数据库路径。
  local candidate_path=""
  # 从候选文件名中解析出的数字版本。
  local candidate_version=""

  for candidate_path in "$codex_home_dir"/"${db_prefix}"_*.sqlite; do
    [[ -e "$candidate_path" ]] || continue
    candidate_version="${candidate_path##*_}"
    candidate_version="${candidate_version%.sqlite}"
    [[ "$candidate_version" =~ ^[0-9]+$ ]] || continue
    if (( candidate_version > selected_version )); then
      selected_version="$candidate_version"
      selected_path="$candidate_path"
    fi
  done

  printf '%s' "$selected_path"
}

# 打印脚本使用说明。
usage() {
  echo "用法：$0 [--minutes N] [--network]"
}

# 打印诊断分区标题。
section() {
  echo
  echo "=== $1 ==="
}

# 遮盖日志中的认证信息和远程环境标识。
redact() {
  sed -E \
    -e 's/(Bearer|token|authorization|api[_-]?key)[=: ]+[^ ,}\"]+/\1=[REDACTED]/Ig' \
    -e 's/(account_id|server_id|environment_id|installation_id)=([^ ,}]+)/\1=[REDACTED]/Ig' \
    -e 's/(srv_e|env_e)_[a-zA-Z0-9]+/[REDACTED]/g'
}

# 探测远程控制 WebSocket 的传输可达性，不携带认证信息。
probe_websocket() {
  # 当前探测路径的显示名称。
  local label="$1"
  # 显式代理地址；空值表示强制直连。
  local proxy_url="$2"
  # 传给 curl 的代理控制参数。
  local proxy_args=()

  if [[ -n "$proxy_url" ]]; then
    proxy_args=(--proxy "$proxy_url")
  else
    proxy_args=(--proxy "")
  fi

  echo "$label"
  curl "${proxy_args[@]}" \
    --http1.1 \
    --silent \
    --show-error \
    --output /dev/null \
    --write-out 'http=%{http_code} proxy=%{proxy_used} remote=%{remote_ip} time=%{time_total}\n' \
    --connect-timeout 6 \
    --max-time 10 \
    -H 'Connection: Upgrade' \
    -H 'Upgrade: websocket' \
    -H 'Sec-WebSocket-Version: 13' \
    -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
    'https://chatgpt.com/backend-api/wham/remote/control/server' 2>&1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --minutes)
      if [[ $# -lt 2 || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        echo "--minutes 需要正整数。" >&2
        usage
        exit 2
      fi
      lookback_minutes="$2"
      shift 2
      ;;
    --network)
      probe_network=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      usage
      exit 2
      ;;
  esac
done

log_db_path="$(select_latest_db logs)"
state_db_path="$(select_latest_db state)"

section "时间与版本"
date '+%Y-%m-%d %H:%M:%S %z'
codex --version 2>/dev/null || echo "未找到 codex 命令。"

section "Codex 与本地代理进程"
ps axo pid,ppid,lstart,command |
  rg '/Applications/ChatGPT.app/Contents/(MacOS/ChatGPT|Resources/codex .*app-server)|app-server --remote-control|cellularCore|蜂窝加速器|clash|surge|mihomo|sing-box' |
  rg -v 'rg ' || true

section "桌面 app-server 代理环境"
# 当前桌面 app-server 的进程列表。
desktop_pids="$(pgrep -f '/Applications/ChatGPT.app/Contents/Resources/codex.*app-server' || true)"
if [[ -z "$desktop_pids" ]]; then
  echo "未发现 ChatGPT/Codex 桌面 app-server。"
else
  # 遍历每个桌面 app-server PID，避免遗漏重复实例。
  for desktop_pid in $desktop_pids; do
    echo "PID=$desktop_pid"
    ps eww -p "$desktop_pid" |
      tr ' ' '\n' |
      rg -i '^(http|https|all|no)_proxy=' |
      sort || echo "未发现代理环境变量。"
  done
fi

section "macOS 系统代理"
scutil --proxy |
  awk '/HTTPEnable|HTTPPort|HTTPProxy|HTTPSEnable|HTTPSPort|HTTPSProxy|SOCKSEnable|SOCKSPort|SOCKSProxy|ProxyAutoConfigEnable/ {print}'
proxy_host="$(scutil --proxy | awk '/HTTPSProxy/{print $3; exit}')"
proxy_port="$(scutil --proxy | awk '/HTTPSPort/{print $3; exit}')"
if [[ -n "$proxy_host" && -n "$proxy_port" ]]; then
  echo "解析出的 HTTPS 代理：http://$proxy_host:$proxy_port"
fi

section "本地代理监听"
netstat -anv -p tcp |
  rg '127\.0\.0\.1\.(7890|7891|7892|1080|8080).*(LISTEN|ESTABLISHED)' |
  rg 'LISTEN|Codex|ChatGPT|codex' |
  head -40 || echo "未发现常见本地代理端口或 Codex 代理连接。"

section "Codex 托管 daemon"
codex doctor --json 2>/dev/null |
  sed -n '/"app_server.status"/,/"auth.credentials"/p' || true

section "远程控制登记"
if [[ -f "$state_db_path" ]] && command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 -header -column "$state_db_path" \
    "select app_server_client_name,server_name,datetime(updated_at,'unixepoch','localtime') updated_local,remote_control_enabled from remote_control_enrollments;" 2>/dev/null || true
else
  echo "未找到状态数据库或 sqlite3。"
fi

section "最近远程控制日志"
if [[ -f "$log_db_path" ]] && command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 -separator ' | ' "$log_db_path" \
    "select datetime(ts,'unixepoch','localtime'),level,process_uuid,feedback_log_body
     from logs
     where target like '%remote_control%'
       and ts > strftime('%s','now','-${lookback_minutes} minutes')
       and (
         level in ('WARN','ERROR')
         or feedback_log_body like '%status changed%'
         or feedback_log_body like '%connected to%'
         or feedback_log_body like '%connecting to%'
       )
     order by ts desc,ts_nanos desc
     limit 80;" 2>/dev/null |
    redact
else
  echo "未找到日志数据库或 sqlite3。"
fi

if [[ "$probe_network" == true ]]; then
  section "HTTPS/WSS 网络探测"
  probe_websocket "直连" ""
  if [[ -n "$proxy_host" && -n "$proxy_port" ]]; then
    probe_websocket "系统 HTTPS 代理" "http://$proxy_host:$proxy_port"
  else
    echo "没有可用于探测的系统 HTTPS 代理。"
  fi
fi
