#!/bin/bash
# ── opencode 健康检查 ──
# 启动宽容期：无就绪标记 → 永远健康（apt 恢复中不误杀）
# 运行期：就绪标记存在 → curl 检测 opencode 端口

READY_FILE="/tmp/.opencode-ready"
PORT="${OPENCODE_PORT:-4096}"

if [ ! -f "$READY_FILE" ]; then
    exit 0
fi

# 直接 curl 检测（open code serve 启动后监听此端口）
curl -s --max-time 5 "http://localhost:${PORT}/" > /dev/null 2>&1
exit $?
