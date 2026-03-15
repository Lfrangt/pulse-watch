#!/bin/bash
# Pulse Coach — AI 健身教练安装脚本
# 将 Pulse Coach skill 安装到用户的 OpenClaw workspace

set -e

SKILL_DIR="$HOME/.openclaw/workspace/skills/pulse-coach"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/pulse-coach"

echo "💪 安装 Pulse Coach — AI 健身教练"
echo ""

# 检查源文件
if [ ! -f "$SOURCE/SKILL.md" ]; then
  echo "❌ 找不到 SKILL.md，请在 agent/ 目录下运行此脚本"
  exit 1
fi

# 创建 skills 目录
mkdir -p "$SKILL_DIR"

# 复制 skill 文件
cp -r "$SOURCE/"* "$SKILL_DIR/"

echo "✅ Pulse Coach 已安装到: $SKILL_DIR"
echo ""
echo "📋 下一步："
echo "   1. 重启 OpenClaw 或等待下一次 heartbeat"
echo "   2. 对你的 agent 说: '今天练什么？'"
echo "   3. Agent 会读取 Pulse Watch 数据，给你个性化训练计划"
echo ""
echo "⚡ Powered by Abundra × Pulse Watch"
