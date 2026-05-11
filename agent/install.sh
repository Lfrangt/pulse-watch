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

# 安装 pulse-health CLI 工具
CLI_SOURCE="$SCRIPT_DIR/pulse-health"
if [ -f "$CLI_SOURCE" ]; then
  cp "$CLI_SOURCE" /usr/local/bin/pulse-health 2>/dev/null || {
    mkdir -p "$HOME/.local/bin"
    cp "$CLI_SOURCE" "$HOME/.local/bin/pulse-health"
    echo "⚠️  无 /usr/local/bin 写权限，已安装到 ~/.local/bin/pulse-health"
    echo "   请确保 ~/.local/bin 在 PATH 中"
  }
  chmod +x /usr/local/bin/pulse-health 2>/dev/null || chmod +x "$HOME/.local/bin/pulse-health"
fi

# 创建数据目录
mkdir -p "$HOME/.pulse"

echo "✅ Pulse Coach 已安装到: $SKILL_DIR"
echo "✅ pulse-health CLI 已安装"
echo ""
echo "📋 下一步："
echo "   1. 重启 OpenClaw 或等待下一次 heartbeat"
echo "   2. 对你的 agent 说: '今天练什么？'"
echo "   3. Agent 会读取 Pulse Watch 数据，给你个性化训练计划"
echo ""
echo "📊 CLI 用法："
echo "   pulse-health status    — 查看健康状态"
echo "   pulse-health json      — 原始 JSON 数据"
echo "   pulse-health history   — 7 天历史"
echo ""
echo "⚡ Powered by Abundra × Pulse Watch"
