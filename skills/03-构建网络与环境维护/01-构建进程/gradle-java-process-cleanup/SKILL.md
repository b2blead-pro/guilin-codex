---
name: gradle-java-process-cleanup
description: 排查 Gradle、Kotlin 或 Java 构建进程占用资源，以及按用户要求清理这些进程。诊断默认只读；清理仅针对已核实归属和闲置状态的目标 PID，全 Java 清理需用户明确要求。
---

# Gradle/Java 进程检查与清理

## 只读诊断

编译后变卡、怀疑 daemon 残留或仅需确认进程时，先运行随 skill 提供的脚本；默认不会终止进程，也不会调用 `gradlew --stop`：

```bash
bash /Users/guilin/.codex/skills/03-构建网络与环境维护/01-构建进程/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh
```

结合进程命令、工作目录、项目构建日志及可用的 `./gradlew --status` 判断归属与状态。CPU 较低、运行时间较长或名称含 Gradle 不代表闲置。仅询问诊断时，报告发现即结束，不自动转入清理。

## 定向清理

- 用户已明确要求清理时，无需重复询问同一授权；先确认目标 PID 属于所要求的项目且当前闲置。BUSY、其他工程、归属不明或仍参与构建的进程不清理；需要中止正在运行的构建时另行取得针对该构建的授权。
- 先预览核实的 PID；每个目标单独传一个 `--pid`：

  ```bash
  bash /Users/guilin/.codex/skills/03-构建网络与环境维护/01-构建进程/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh --pid <已核实的PID>
  ```

- 核实后添加 `--execute` 执行。脚本会检查目标是否为当前用户的构建进程，并在发信号前复核启动时间和命令；它不能替代项目归属与闲置状态的人工或日志核实。
- 脚本仅对选定 PID 发送 `TERM`，等待 3 秒后复查。仍存活或身份变化时报告并停止，不自动重试、不升级为 `KILL`，也不清理新出现的进程。

## 全 Java 清理

仅当用户明确要求“清理所有 Java 进程”时使用。此范围包含其他项目、IDE 和后台 Java 服务，应在执行前说明影响；普通项目清理授权不覆盖此模式。

```bash
# 默认仅预览 jps 可见的当前用户 Java 进程。
bash /Users/guilin/.codex/skills/03-构建网络与环境维护/01-构建进程/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh --all-java
# 已明确获得全 Java 清理授权后执行。
bash /Users/guilin/.codex/skills/03-构建网络与环境维护/01-构建进程/gradle-java-process-cleanup/scripts/cleanup-java-gradle.sh --all-java --execute
```

`--dry-run` 与默认预览等价，不能与 `--execute` 同时使用。`--all-java` 不能与 `--pid` 混用。
