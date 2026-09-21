---
name: harmony-device-unlock
description: 检测并解锁当前用户的 HarmonyOS/鸿蒙真机。Use when 鸿蒙开发、安装、运行、抓日志或 UI 自动化期间遇到锁屏、指纹锁屏、启动失败 10106102、无法操作页面，或需要先唤醒并解锁设备时；要求统一调用随 Skill 提供的本地脚本，不临时拼接密码输入命令。
---

# 鸿蒙设备解锁

## 执行流程

1. 先运行无副作用状态检查：

   ```bash
   bash /Users/guilin/.codex/skills/02-移动端开发/04-模拟器与设备/harmony-device-unlock/scripts/harmony-device-unlock.sh --check
   ```

2. 状态为已锁定，或业务命令明确提示设备锁屏时，运行：

   ```bash
   bash /Users/guilin/.codex/skills/02-移动端开发/04-模拟器与设备/harmony-device-unlock/scripts/harmony-device-unlock.sh
   ```

3. 脚本成功后重试原安装、启动或测试命令。不要重复实现唤醒、上滑、数字键盘点击逻辑。

4. 需要指定其他设备时传入 `--device <serial>`。脚本默认适配当前 1260×2720 鸿蒙真机 `23E0223C23008299`；其他分辨率不得直接沿用坐标，应先校准脚本。

## 安全约束

- 用户已明确授权将当前设备 PIN 明文保存在本地脚本中；不要把它复制到项目仓库、命令行参数、构建日志或最终回复。
- 脚本不得开启 `set -x`，不得回显 PIN，也不会在完成后重新锁屏。
- 不要直接运行参考用的钉钉自动化脚本来解锁，因为它还会启动钉钉、执行页面操作并再次锁屏。
- 连续三次解锁失败时停止重试，保留设备现状并报告关键错误，避免触发设备安全限制。
