# Release Notes

## v1.0.0 (Build 1) — Initial Release

### What's New

**Pulse** turns your Apple Watch into an intelligent health agent. Instead of charts and dashboards, you get a single daily score and actionable advice.

**iPhone App:**
- Daily Health Score (0-100) powered by sleep, HRV, resting heart rate, steps, and blood oxygen
- Morning Brief notification with personalized health insights
- Weekly trend reports with score, HRV, and sleep analysis
- Training calendar with workout history
- Home Screen widgets (small, medium, large) and Lock Screen widgets
- OpenClaw AI coaching integration (optional)
- Gym arrival detection with PPL training suggestions

**Apple Watch:**
- Real-time workout tracking with heart rate zones (5-zone)
- Complications (circular + rectangular) showing daily score
- Training plan view with PPL rotation
- Summary view with key health metrics
- Haptic feedback for workout milestones

**Sharing & Social:**
- Social share cards — generate shareable workout achievement images

**Data & Privacy:**
- All health data stored locally on-device (SwiftData)
- Background HealthKit data collection with incremental sync
- WatchConnectivity sync between iPhone and Apple Watch (health snapshots + workout events)
- No accounts, no cloud, no subscriptions

### Known Limitations
- OpenClaw integration requires user's own OpenClaw instance
- Heart rate zone calculation uses estimated max HR (220 - age default 190)
- Gym detection requires location permission (always-on for geofencing)
- Morning Brief notifications require notification permission (provisional delivery available)

### TestFlight Feedback
Please report issues and feedback via TestFlight or GitHub Issues.

---

## 版本说明

## v1.0.0 (Build 1) — 首次发布

**Pulse** 把你的 Apple Watch 变成智能健康代理。用一个每日评分代替复杂的图表和仪表盘。

**iPhone 应用：**
- 每日健康评分 (0-100)，综合睡眠、HRV、静息心率、步数、血氧
- 晨间简报通知
- 每周趋势报告
- 训练日历 + 训练历史
- 主屏幕 & 锁屏小组件
- OpenClaw AI 教练集成（可选）
- 健身房到达检测 + PPL 训练建议

**Apple Watch：**
- 实时训练追踪 + 心率区间
- 表盘复杂功能
- 训练计划视图
- 触觉反馈

**分享：**
- 社交分享卡片 — 训练成就图片生成

**数据隐私：**
所有数据本地存储，无需账号，无云端，无订阅。Watch 健康快照 + 训练数据通过 WatchConnectivity 同步。
