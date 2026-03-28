# Pulse — App Store Listing

## App Name
Pulse — AI Fitness Coach

## Subtitle (30 chars max)
Recovery Score for Apple Watch

## Category
Primary: Health & Fitness
Secondary: Lifestyle

---

## Description (English)

Turn your Apple Watch into an intelligent health agent.

Pulse collects your HealthKit data — heart rate, HRV, sleep, steps, blood oxygen — and distills it into a single daily score. No dashboards to decipher. No charts to interpret. Just a clear number that tells you how your body is doing today.

**Key Features:**

- Daily Health Score (0-100) based on sleep, HRV, resting heart rate, and activity
- Morning Brief notification with personalized health summary
- Real-time workout tracking on Apple Watch with heart rate zones
- Weekly trend reports with actionable insights
- Gym arrival detection with automatic training suggestions (PPL rotation)
- Home Screen & Lock Screen widgets
- Apple Watch complications
- Social share cards — generate shareable workout achievement images

**Privacy First:**
All data stays on your device. No accounts. No cloud uploads. No subscriptions. Buy once, use forever.

**Optional AI Coaching:**
Connect to your own OpenClaw instance for AI-powered training advice, anomaly alerts, and conversational coaching. Your data, your AI, your server.

**Requirements:**
- iPhone with iOS 17.0+
- Apple Watch with watchOS 10.0+ (recommended)
- HealthKit data (Apple Watch or compatible sensors)

---

## Description (Chinese / 中文描述)

把你的 Apple Watch 变成智能健康代理。

Pulse 采集你的 HealthKit 数据 — 心率、HRV、睡眠、步数、血氧 — 提炼成一个每日评分。不需要解读仪表盘，不需要分析图表，只需要一个清晰的数字告诉你今天身体状态如何。

**核心功能：**

- 每日健康评分 (0-100)，基于睡眠、HRV、静息心率和活动量
- 晨间简报通知，个性化健康摘要
- Apple Watch 实时训练追踪，心率区间可视化
- 每周趋势报告，可执行的健康建议
- 到达健身房自动检测，智能推荐训练计划 (PPL 轮换)
- 主屏幕 & 锁屏小组件
- Apple Watch 表盘复杂功能
- 社交分享卡片 — 生成可分享的训练成就图片

**隐私优先：**
所有数据留在设备上。无需账号。不上传云端。无订阅。一次购买，永久使用。

**可选 AI 教练：**
连接你自己的 OpenClaw 实例，获得 AI 驱动的训练建议、异常预警和对话式教练。你的数据，你的 AI，你的服务器。

---

## Promotional Text (170 chars max, can update without review)
Your body talks. Pulse listens. Get daily recovery scores, AI-powered training advice, and smart workout plans — all from your Apple Watch. One-time purchase, no subscription.

## Keywords

health,fitness,heart rate,HRV,sleep,Apple Watch,workout,training,score,recovery,wellness,HealthKit

## What's New (v1.0.0)

Initial release of Pulse — your AI fitness coach for Apple Watch.
- Daily recovery score (0-100) based on your personal baseline
- Smart Push/Pull/Legs training plans
- Apple Watch complications & real-time workout tracking
- Gym arrival auto-detection
- Sleep analysis with regularity tracking
- Optional AI coaching via OpenClaw
- Home Screen & Lock Screen widgets

---

## App Review Notes

This app uses HealthKit to read health data (heart rate, HRV, sleep analysis, steps, blood oxygen, calories) and write workout data. All data is stored locally on the device using SwiftData. No data is transmitted to external servers unless the user explicitly configures an OpenClaw connection (optional AI coaching feature).

The app uses location services for gym detection (geofencing) to suggest training plans. Location data is processed on-device and never uploaded.

The app uses local network discovery (Bonjour) to find OpenClaw gateway instances on the user's local network. This is an optional feature for AI coaching integration.

**Demo Mode:** To test without an Apple Watch, launch the app with demo data by going to Settings tab → scroll to bottom → enable "Demo Mode". This populates the app with sample health data for review purposes.

Demo/test account is not required — the app works with real HealthKit data from the user's Apple Watch, or with Demo Mode enabled.

---

## App Store Connect Privacy Nutrition Labels

**Data Types Collected:**

| Data Type | Collected | Linked to User | Tracking | Purpose |
|-----------|-----------|----------------|----------|---------|
| Health & Fitness (Heart Rate, HRV, Sleep, Steps, SpO2, Calories) | Yes | No | No | App Functionality |
| Precise Location | Yes | No | No | App Functionality (gym detection) |
| Diagnostics (Crash Data, Performance) | Yes | No | No | Analytics (via TelemetryDeck, anonymous) |
| Usage Data (Feature Interaction) | Yes | No | No | Analytics (via TelemetryDeck, anonymous) |

**Data NOT collected:** Name, Email, Phone, Payment, Contacts, User Content, Search History, Browsing History, Identifiers, Purchases, Photos/Videos.

**Notes:**
- All health data is processed and stored on-device only
- TelemetryDeck analytics are anonymous and privacy-preserving (no user ID, GDPR compliant)
- Location data is never transmitted off-device
- No third-party advertising or tracking SDKs
