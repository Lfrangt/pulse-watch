# Pulse — AI Health Agent for Apple Watch

## Vision
Turn Apple Watch into an AI-powered health agent. Not a dashboard — an agent that understands your body and tells you what to do.

## Core Principles
- **Buy-once, no subscription**
- **Data stays on device** (local-first)
- **Action over information** — don't show charts, give advice
- **Minimal UI** — glance and go
- **小而美** — App does data collection + display, OpenClaw does AI

## Architecture

```
Apple Watch (Sensors + Complications + Training)
    ↓ WatchConnectivity
iPhone App (Data Hub)
    ├── HealthKit data collection
    ├── HealthAnalyzer (local scoring, no AI)
    ├── SwiftData local storage
    ├── Beautiful data visualization
    └── OpenClaw Bridge (App Group → Agent)
         ↕
OpenClaw (User's own)
    └── Pulse Coach Agent Skill
         ├── Reads health data from App Group
         ├── AI-powered training advice
         ├── Conversational coaching
         └── Memory (tracks progress)
```

## Current State (v1.0.0)

### iPhone App
- 3-Tab: 今日 | 趋势 | 设置
- Dashboard: 评分圆环(弹性动画) + 洞察 + 指标(趋势箭头) + 恢复时间线
- History: Swift Charts + 训练日历 + 周报
- Settings: OpenClaw连接引导 + Morning Brief配置 + 演示模式
- Home Screen Widget (small/medium/large)
- Onboarding Flow

### Apple Watch
- Complication (圆形+矩形)
- SummaryView (评分+指标)
- WorkoutTracking (HKWorkoutSession + 实时心率)
- TrainingPlanView (PPL轮换)
- Haptic Feedback

### Agent Skill (Pulse Coach)
- 读取 App Group 健康数据
- PPL 训练推荐
- 渐进超载追踪
- 营养建议
- 异常预警

## Tech Stack
- SwiftUI + SwiftData (iOS 17+ / watchOS 10+)
- HealthKit + CoreLocation
- WidgetKit
- WatchConnectivity
- Swift Charts

## Stats
- 39 Swift files, ~13K lines
- 19 commits
- 5 hours from zero to real device
- iPhone real device tested ✅
