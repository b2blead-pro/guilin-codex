#!/usr/bin/env bash
# 作用：清理当前机器上的 Gradle/Kotlin/Java 构建相关进程，缓解编译后系统卡顿。
# 用法：
#   .codex/skills/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh
#   .codex/skills/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh --dry-run
#   .codex/skills/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh --all-java

set -euo pipefail

DRY_RUN=0
ALL_JAVA=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    --all-java)
      ALL_JAVA=1
      ;;
    *)
      echo "未知参数：$arg" >&2
      exit 2
      ;;
  esac
done

echo "开始检查 Gradle 状态..."
if [[ -x "./gradlew" ]]; then
  ./gradlew --status || true
  if [[ "$DRY_RUN" -eq 0 ]]; then
    ./gradlew --stop || true
  fi
else
  echo "未找到可执行 ./gradlew，跳过 Gradle stop。"
fi

collect_pids() {
  if [[ "$ALL_JAVA" -eq 1 ]]; then
    jps -lv 2>/dev/null | awk -v self="$$" '$1 != self {print $1}' | tr '\n' ' '
    return
  fi

  {
    jps -lv 2>/dev/null | awk '/GradleDaemon|KotlinCompileDaemon|GradleWorkerMain|org\.gradle|kotlin\.daemon|javac/ {print $1}'
    ps -axo pid,ppid,command | awk -v self="$$" -v parent="$PPID" '
      /GradleDaemon|KotlinCompileDaemon|GradleWorkerMain|org\.gradle|kotlin\.daemon|javac/ &&
      !/awk/ &&
      !/cleanup-java-gradle\.sh/ &&
      !/rtk proxy/ &&
      $1 != self &&
      $1 != parent &&
      $2 != self {
        print $1
      }
    '
  } | sort -u | tr '\n' ' '
}

PIDS="$(collect_pids)"
if [[ -z "${PIDS// }" ]]; then
  echo "没有发现需要清理的 Java/Gradle 构建进程。"
  exit 0
fi

echo "准备清理进程：$PIDS"
ps -o pid,ppid,stat,etime,%cpu,%mem,command -p $PIDS || true

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "dry-run 模式，不执行 kill。"
  exit 0
fi

kill $PIDS 2>/dev/null || true
sleep 3

ALIVE=""
for pid in $PIDS; do
  if kill -0 "$pid" 2>/dev/null; then
    ALIVE="$ALIVE $pid"
  fi
done

if [[ -n "${ALIVE// }" ]]; then
  echo "以下进程仍存活，执行强制清理：$ALIVE"
  kill -9 $ALIVE 2>/dev/null || true
fi

echo "清理完成，剩余相关进程："
ps -axo pid,ppid,stat,etime,%cpu,%mem,command | grep -Ei "gradle|kotlin.*daemon|java|javac" | grep -v grep || true
