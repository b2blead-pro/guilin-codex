---
name: gradle-java-process-cleanup
description: 清理内存，在当前 Android 项目中排查编译变卡、Gradle Daemon/Kotlin Daemon/Java 构建进程残留、CPU 或内存被构建进程占用时使用。用于先检查进程，再安全清理 Gradle/Kotlin 构建相关 Java 进程；只有用户明确要求时才清理所有 Java 进程。
---

# Gradle/Java 进程清理

## 适用场景

- 编译后系统变卡，怀疑 Gradle 或 Kotlin daemon 占用资源。
- 需要确认是否存在多余 Gradle、Kotlin、Java 编译进程。
- 用户明确要求清理 Java/Gradle 进程，恢复系统流畅。

## 操作流程

1. 先检查进程：

```bash
./gradlew --status
jps -lv
ps -axo pid,ppid,stat,etime,%cpu,%mem,command | rg -i "gradle|kotlin.*daemon|java|javac"
```

2. 默认优先安全清理构建相关进程：

```bash
.codex/skills/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh
```

3. 如果只想预览将要清理的进程：

```bash
.codex/skills/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh --dry-run
```

4. 只有用户明确要求“清理所有 Java 进程”时才使用：

```bash
.codex/skills/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh --all-java
```

## 注意事项

- 默认模式只清理 GradleDaemon、KotlinCompileDaemon、Gradle Worker、javac 等构建相关 Java 进程。
- `--all-java` 会清理所有 `jps` 能看到的 Java 进程，可能影响 Android Studio、IDE 插件、后台 Java 服务。
- 清理后必须再次检查进程，确认没有残留。
- 不要使用 `kill -9` 作为第一选择；脚本会先 `TERM`，仍存活时再 `KILL`。
