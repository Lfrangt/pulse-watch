# Pulse Coach — AI 健身教练

**你的 AI 教练，懂你的身体。**

Pulse Coach 是一个 OpenClaw Agent Skill，与 Pulse Watch app 深度集成。它读取你的实时健康数据（恢复评分、HRV、睡眠、心率），给你真正个性化的训练建议。

## 安装

```bash
# 方式 1: 脚本安装（推荐）
cd agent && ./install.sh

# 方式 2: 手动复制
cp -r pulse-coach ~/.openclaw/workspace/skills/
```

## 使用

安装后，直接和你的 OpenClaw agent 对话：

- **"今天练什么？"** — 根据恢复评分 + PPL 轮换推荐训练计划
- **"我身体状态怎么样？"** — 分析 HRV、心率、睡眠趋势
- **"刚练完卧推 80kg×5×3"** — 记录训练，追踪渐进超载
- **"需要 deload 吗？"** — 分析过去 2 周训练量和恢复趋势

## 需要

- [Pulse Watch](https://github.com/Lfrangt/pulse-watch) app 已安装
- OpenClaw 已配置
- Pulse Watch 的 OpenClaw 数据共享已开启（设置 → OpenClaw）

## 开源

MIT License. 由 [Abundra](https://github.com/Lfrangt) 出品。
