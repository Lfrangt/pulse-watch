# Privacy Policy — Pulse Watch

**Last updated:** March 15, 2026
**Effective date:** March 15, 2026

## Overview

Pulse Watch ("Pulse", "the App") is developed by Abundra. We believe your health data is deeply personal. That's why Pulse is designed from the ground up to keep your data on your device.

**The short version: We don't collect, store, or transmit any of your personal or health data. Period.**

## Data We Collect

**None.**

Pulse does not collect, store, or transmit any personal information to our servers. We don't have servers for user data. We don't have user accounts. We don't have analytics that track individual users.

## Health Data

Pulse reads the following data from Apple HealthKit with your explicit permission:

- Heart rate and resting heart rate
- Heart rate variability (HRV)
- Blood oxygen saturation (SpO2)
- Sleep analysis (duration, stages)
- Step count
- Active energy burned
- Workout records

**All health data processing happens locally on your device.** Your recovery scores, training suggestions, sleep analysis, and anomaly detection are computed by algorithms running on your iPhone and Apple Watch. No health data is ever sent to any external server.

## Local Network

Pulse may use local network discovery (Bonjour) to find OpenClaw gateway instances on your local network. This is an optional feature. No network scan data is transmitted externally.

## OpenClaw Integration (Optional)

Pulse offers an optional connection to OpenClaw, a local-first AI agent framework. When enabled:

- Health summary data (scores, not raw readings) may be sent to YOUR OpenClaw instance running on YOUR device or personal server
- This connection is entirely under your control
- No data is sent to Abundra or any third party
- You can disable this at any time in Settings

## Analytics

Pulse uses [TelemetryDeck](https://telemetrydeck.com/privacy) for anonymous, privacy-preserving usage analytics (e.g., feature adoption, crash-free rates). TelemetryDeck does not collect personal information and complies with GDPR without requiring user consent. No health data is included in analytics.

## Third-Party Services

Pulse does not integrate with any advertising or tracking services. The only third-party service is TelemetryDeck for anonymous analytics as described above.

## Data Storage

All data is stored locally using:
- **SwiftData** — on-device database
- **Apple Keychain** — for secure token storage (OpenClaw connection only)
- **App Group shared container** — for widget and watch app data sharing (on-device only)

## Data Sharing

We do not share any data with any third party. We don't have your data to share.

## Children's Privacy

Pulse does not knowingly collect information from children under 13. The App requires an Apple Watch and iPhone, which have their own age restrictions.

## Changes to This Policy

If we ever change this policy, we will update this page and the "Last updated" date. Given our architecture (no servers, no data collection), material changes are unlikely.

## Contact

If you have questions about this privacy policy:

- Email: abundra.dev@gmail.com
- GitHub: https://github.com/Lfrangt/pulse-watch/issues

## Your Rights

Since we don't collect your data, there's nothing to request access to, correct, or delete. Your data lives on your device — you have full control.

---

**隐私政策 — 中文摘要**

Pulse 不收集任何个人数据。所有健康数据处理在你的设备本地完成。没有服务器，没有账号，没有追踪。OpenClaw 连接是可选的，数据只发送到你自己的 Agent，不经过任何第三方。

完整英文版本见上方。

---

*© 2026 Abundra. All rights reserved.*
