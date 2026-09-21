#!/usr/bin/env bash

# 检测并解锁当前 1260×2720 鸿蒙真机。
# 用法：harmony-device-unlock.sh [--check] [--device <serial>]
set -euo pipefail

# 默认设备和 PIN 由用户明确指定，仅保存在本地用户级 Skill 中。
DEFAULT_DEVICE_ID="23E0223C23008299"
DEVICE_PIN="000000"
# 锁屏控件树用于确认解锁前后状态。
LOCK_LAYOUT="/data/local/tmp/codex-harmony-unlock-layout.json"
MAX_ATTEMPTS=3
WAIT_SECONDS=10
# 解锁期间临时延长息屏时间，退出时恢复原设置。
SCREEN_TIMEOUT_MS=300000

DEVICE_ID="${HARMONY_DEVICE_ID:-$DEFAULT_DEVICE_ID}"
CHECK_ONLY=0
HDC_BIN=""
TIMEOUT_OVERRIDDEN=0

# usage 输出脚本参数说明。
usage() {
    printf '%s\n' "用法：$0 [--check] [--device <serial>]"
}

# find_hdc 从环境变量、PATH 和 DevEco 默认目录查找 hdc。
find_hdc() {
    if [ -n "${HARMONY_HDC_BIN:-}" ] && [ -x "$HARMONY_HDC_BIN" ]; then
        printf '%s\n' "$HARMONY_HDC_BIN"
        return 0
    fi
    if command -v hdc >/dev/null 2>&1; then
        command -v hdc
        return 0
    fi

    local candidate
    for candidate in \
        "/Users/guilin/.local/openharmony/toolchains/hdc" \
        "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc" \
        "/Applications/DevEco_Testing_for_App.app/Contents/Resources/app/resources/bin/hdc" \
        "/Volumes/Western_2T/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
    do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

# dump_lock_layout 刷新设备锁屏控件树。
dump_lock_layout() {
    "$HDC_BIN" -t "$DEVICE_ID" shell uitest dumpLayout -p "$LOCK_LAYOUT" >/dev/null 2>&1
}

# read_lock_layout 读取最近一次锁屏控件树。
read_lock_layout() {
    "$HDC_BIN" -t "$DEVICE_ID" shell cat "$LOCK_LAYOUT" 2>/dev/null
}

# is_device_locked 返回 0 表示已锁定，1 表示已解锁，2 表示状态未知。
is_device_locked() {
    if ! dump_lock_layout; then
        return 2
    fi
    if read_lock_layout | grep -q 'ScreenLockRootComponent'; then
        return 0
    fi
    return 1
}

# wait_for_pin_keypad 等待密码键盘；返回 2 表示等待期间已解锁。
wait_for_pin_keypad() {
    local waited=0
    local layout_text
    while [ "$waited" -lt "$WAIT_SECONDS" ]; do
        if dump_lock_layout; then
            layout_text=$(read_lock_layout)
            if ! printf '%s\n' "$layout_text" | grep -q 'ScreenLockRootComponent'; then
                return 2
            fi
            if printf '%s\n' "$layout_text" | grep -q 'screenLock_Text_enterPsd'; then
                return 0
            fi
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}

# wait_until_unlocked 轮询锁屏根控件，确认页面已经解锁。
wait_until_unlocked() {
    local waited=0
    local lock_state
    while [ "$waited" -lt "$WAIT_SECONDS" ]; do
        if is_device_locked; then
            lock_state=0
        else
            lock_state=$?
        fi
        if [ "$lock_state" -eq 1 ]; then
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}

# tap_pin_digit 按当前设备的数字键盘布局点击一位数字。
tap_pin_digit() {
    local pin_x
    local pin_y
    case "$1" in
        1) pin_x=318; pin_y=1320 ;;
        2) pin_x=630; pin_y=1320 ;;
        3) pin_x=942; pin_y=1320 ;;
        4) pin_x=318; pin_y=1605 ;;
        5) pin_x=630; pin_y=1605 ;;
        6) pin_x=942; pin_y=1605 ;;
        7) pin_x=318; pin_y=1890 ;;
        8) pin_x=630; pin_y=1890 ;;
        9) pin_x=942; pin_y=1890 ;;
        0) pin_x=630; pin_y=2177 ;;
        *) return 1 ;;
    esac
    "$HDC_BIN" -t "$DEVICE_ID" shell uinput -T -c "$pin_x" "$pin_y" >/dev/null
}

# clear_pin_input 清除键盘里可能残留的密码输入。
clear_pin_input() {
    local count=0
    while [ "$count" -lt 8 ]; do
        "$HDC_BIN" -t "$DEVICE_ID" shell uinput -T -c 942 2177 >/dev/null
        sleep 0.12
        count=$((count + 1))
    done
}

# unlock_once 完成单次唤醒、上滑、输入 PIN 和结果确认。
unlock_once() {
    local current_attempt="$1"
    local lock_state
    local keypad_state
    local remaining
    local digit

    if [ "$TIMEOUT_OVERRIDDEN" -eq 0 ]; then
        if "$HDC_BIN" -t "$DEVICE_ID" shell power-shell timeout -o "$SCREEN_TIMEOUT_MS" 2>&1 |
            grep -q "Override screen off time to $SCREEN_TIMEOUT_MS"; then
            TIMEOUT_OVERRIDDEN=1
        fi
    fi
    "$HDC_BIN" -t "$DEVICE_ID" shell power-shell wakeup >/dev/null
    sleep 1
    if is_device_locked; then
        lock_state=0
    else
        lock_state=$?
    fi
    if [ "$lock_state" -eq 1 ]; then
        return 0
    fi
    if [ "$lock_state" -ne 0 ]; then
        return 1
    fi

    "$HDC_BIN" -t "$DEVICE_ID" shell uitest uiInput swipe 630 2380 630 620 1200 >/dev/null
    if wait_for_pin_keypad; then
        keypad_state=0
    else
        keypad_state=$?
    fi
    if [ "$keypad_state" -eq 2 ]; then
        return 0
    fi
    if [ "$keypad_state" -ne 0 ]; then
        return 1
    fi

    if [ "$current_attempt" -gt 1 ]; then
        clear_pin_input
    fi
    remaining="$DEVICE_PIN"
    while [ -n "$remaining" ]; do
        digit="${remaining:0:1}"
        remaining="${remaining:1}"
        tap_pin_digit "$digit"
        sleep 0.25
    done
    wait_until_unlocked
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check)
            CHECK_ONLY=1
            shift
            ;;
        --device)
            if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                echo "缺少 --device 的设备序列号" >&2
                exit 2
            fi
            DEVICE_ID="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "未知参数：$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! HDC_BIN=$(find_hdc); then
    echo "未找到可用 hdc，请确认 DevEco Studio 已安装" >&2
    exit 1
fi
if ! "$HDC_BIN" list targets 2>/dev/null | tr -d '\r' | grep -Fxq "$DEVICE_ID"; then
    echo "鸿蒙设备未连接：$DEVICE_ID" >&2
    exit 1
fi

# cleanup 恢复息屏时间，并删除本次生成的设备端临时控件树。
cleanup() {
    if [ "$TIMEOUT_OVERRIDDEN" -eq 1 ]; then
        "$HDC_BIN" -t "$DEVICE_ID" shell power-shell timeout -r "$SCREEN_TIMEOUT_MS" >/dev/null 2>&1 || true
    fi
    "$HDC_BIN" -t "$DEVICE_ID" shell rm "$LOCK_LAYOUT" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if is_device_locked; then
    initial_state=0
else
    initial_state=$?
fi
if [ "$CHECK_ONLY" -eq 1 ]; then
    case "$initial_state" in
        0) echo "设备已锁定：$DEVICE_ID" ;;
        1) echo "设备已解锁：$DEVICE_ID" ;;
        *) echo "无法读取设备锁屏状态：$DEVICE_ID" >&2; exit 1 ;;
    esac
    exit 0
fi
if [ "$initial_state" -eq 1 ]; then
    echo "设备已经处于解锁状态：$DEVICE_ID"
    exit 0
fi
if [ "$initial_state" -ne 0 ]; then
    echo "无法读取设备锁屏状态：$DEVICE_ID" >&2
    exit 1
fi

attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    if unlock_once "$attempt"; then
        echo "设备解锁成功：$DEVICE_ID"
        exit 0
    fi
    echo "第 $attempt/$MAX_ATTEMPTS 次解锁未成功" >&2
    attempt=$((attempt + 1))
    sleep 2
done

echo "连续三次无法解锁设备，已停止重试" >&2
exit 1
