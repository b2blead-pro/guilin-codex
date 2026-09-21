#!/usr/bin/env bash
# 作用：默认只读列出构建进程；经授权后，按已核实归属及闲置状态的 PID 定向清理。
# 用法：bash cleanup-java-gradle.sh [--pid <PID> ...] [--execute]
# 全 Java 模式仅供用户明确要求时使用：bash cleanup-java-gradle.sh --all-java [--execute]

set -euo pipefail

# 执行开关默认关闭；全 Java 模式不得与定向 PID 混用。
EXECUTE=0
ALL_JAVA=0
DRY_RUN=0
# 只接受显式目标，或全 Java 模式本轮发现的进程。
PIDS=()
SNAPSHOTS=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --all-java) ALL_JAVA=1 ;;
    --pid)
      if [[ "$#" -lt 2 || ! "$2" =~ ^[1-9][0-9]*$ || "$2" == 1 ]]; then
        echo "--pid 需要一个大于 1 的正整数 PID。" >&2
        exit 2
      fi
      # 重复 PID 只保留一次，避免目标退出后再次发送信号。
      if [[ " ${PIDS[*]-} " == *" $2 "* ]]; then
        shift 2
        continue
      fi
      PIDS+=("$2")
      shift
      ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "$EXECUTE" -eq 1 && "$DRY_RUN" -eq 1 ]]; then
  echo "--execute 与 --dry-run 不能同时使用。" >&2
  exit 2
fi
if [[ "$ALL_JAVA" -eq 1 && "${#PIDS[@]}" -gt 0 ]]; then
  echo "--all-java 与 --pid 不能同时使用。" >&2
  exit 2
fi
if [[ "$ALL_JAVA" -eq 0 && "${#PIDS[@]}" -eq 0 ]]; then
  if [[ "$EXECUTE" -eq 1 ]]; then
    echo "执行清理必须用 --pid 指定已核实的目标；全 Java 清理需显式 --all-java。" >&2
    exit 2
  fi
  echo "只读检查：以下是待核实的构建进程，不判断归属或闲置状态。"
  ps -axo pid,ppid,stat,etime,%cpu,%mem,command | awk 'NR == 1 || /[G]radleDaemon|[K]otlinCompileDaemon|[G]radleWorkerMain|org[.]gradle|kotlin[.]daemon|[j]avac/'
  exit 0
fi

if [[ "$ALL_JAVA" -eq 1 ]]; then
  # jps 仅用于显式全 Java 模式，排除列举命令自身。
  JAVA_LIST="$(jps -lv)"
  while read -r pid; do
    [[ -n "$pid" ]] && PIDS+=("$pid")
  done < <(printf '%s\n' "$JAVA_LIST" | awk '$1 ~ /^[1-9][0-9]*$/ && $1 > 1 && $0 !~ /(^|[ .])Jps([[:space:]]|$)/ {print $1}')
fi

if [[ "${#PIDS[@]}" -eq 0 ]]; then
  echo "没有发现需要处理的目标 Java 进程。"
  exit 0
fi

# 保存启动时间和命令，执行前复核，避免对已退出或被复用的 PID 发信号。
CURRENT_UID="$(id -u)"
for pid in "${PIDS[@]}"; do
  if [[ "$pid" == "$$" || "$pid" == "$PPID" ]]; then
    echo "拒绝清理脚本自身或父进程：$pid" >&2
    exit 2
  fi
  snapshot="$(ps -p "$pid" -o uid= -o lstart= -o command=)" || {
    echo "目标进程不存在或无法读取：$pid" >&2
    exit 2
  }
  read -r owner _ <<< "$snapshot"
  if [[ "$owner" != "$CURRENT_UID" ]]; then
    echo "拒绝清理其他用户的进程：$pid" >&2
    exit 2
  fi
  if [[ "$ALL_JAVA" -eq 0 ]]; then
    # 用实际可执行文件辅助识别，不能仅因参数里出现构建进程名就放行。
    executable="$(ps -p "$pid" -o comm=)" || executable=""
    if [[ "${executable##*/}" != java && "${executable##*/}" != javac ]] ||
       [[ ! "$snapshot" =~ GradleDaemon|KotlinCompileDaemon|GradleWorkerMain|org\.gradle|kotlin\.daemon|javac ]]; then
      echo "目标不是可识别的构建进程：$pid" >&2
      exit 2
    fi
  fi
  SNAPSHOTS+=("$snapshot")
  printf '目标 PID %s：%s\n' "$pid" "$snapshot"
done

if [[ "$EXECUTE" -eq 0 ]]; then
  echo "预览完成，未发送信号；已获清理授权并核实目标后才可添加 --execute。"
  exit 0
fi

# 任一目标发生变化即停止本次执行；不自动改选其他进程。
for index in "${!PIDS[@]}"; do
  pid="${PIDS[$index]}"
  snapshot="$(ps -p "$pid" -o uid= -o lstart= -o command=)" || snapshot=""
  if [[ "$snapshot" != "${SNAPSHOTS[$index]}" ]]; then
    echo "目标进程已退出或身份变化，停止清理：$pid" >&2
    exit 1
  fi
done

# 仅发送 TERM，不停止所有 Gradle daemon，也不自动升级为 KILL。
FAILED=0
for pid in "${PIDS[@]}"; do
  if ! kill -TERM "$pid"; then
    echo "发送 TERM 失败：$pid" >&2
    FAILED=1
  fi
done
sleep 3
for index in "${!PIDS[@]}"; do
  pid="${PIDS[$index]}"
  snapshot="$(ps -p "$pid" -o uid= -o lstart= -o command=)" || snapshot=""
  if [[ "$snapshot" == "${SNAPSHOTS[$index]}" ]]; then
    echo "目标仍存活，保留现状，不自动强制终止：$pid" >&2
    FAILED=1
  fi
done
if [[ "$FAILED" -eq 0 ]]; then
  echo "指定目标已退出。"
fi
exit "$FAILED"
