# Privacy Policy — Pulse

**Last Updated: March 27, 2026**
**Effective Date: March 15, 2026**

Pulse ("the App") is developed by Abundra. This privacy policy explains how we handle your data.

## Summary

Pulse is a privacy-first app. **All your health data stays on your device.** We do not collect, store, or transmit your personal health information to any server.

## Data Collection

### Health Data (HealthKit)

The App reads the following data from Apple HealthKit:
- Heart rate, resting heart rate, heart rate variability (HRV)
- Blood oxygen saturation (SpO2)
- Sleep analysis (duration, stages)
- Step count
- Active and resting energy burned

The App writes workout data (active energy burned) to HealthKit when you complete a workout on Apple Watch.

**All HealthKit data is processed and stored locally on your device using Apple's SwiftData framework. It is never transmitted to external servers.**

### Location Data

The App uses location services to detect when you arrive at a saved gym location, enabling automatic training suggestions. Location data is:
- Processed entirely on-device
- Never uploaded to any server
- Never shared with third parties

### Camera

The App uses the camera solely to scan QR codes for OpenClaw pairing. No images or video are stored or transmitted.

### Local Network

The App may use local network discovery (Bonjour) to find OpenClaw gateway instances on your local network. This is an optional feature for AI coaching integration. No network scan data is transmitted externally.

### Analytics

The App uses TelemetryDeck for anonymous, privacy-preserving usage analytics (e.g., feature adoption, crash-free rates). TelemetryDeck does not collect personal information and complies with GDPR without requiring user consent. No health data is included in analytics.

Learn more: https://telemetrydeck.com/privacy

## Optional: OpenClaw Integration

If you choose to connect the App to your own OpenClaw instance (an optional AI coaching feature), the App will transmit aggregated health summaries to your specified server. This connection is:
- Entirely opt-in
- Configured by you with your own server URL and credentials
- Secured with bearer token authentication over HTTPS
- Controlled by you — you can disconnect at any time

**We do not operate or have access to your OpenClaw server.** You are responsible for the privacy practices of your own OpenClaw instance.

## Data Storage

- Health records: Stored locally via SwiftData (on-device database)
- Preferences: Stored in UserDefaults (on-device)
- OpenClaw token: Stored in iOS Keychain (encrypted, on-device)
- App Group data: Shared between the App and its widgets via App Group container (on-device)

## Data Sharing

We do not sell, share, or transmit your personal data to any third party.

## Children's Privacy

The App is not directed at children under 13. We do not knowingly collect data from children.

## Your Rights

Since all data is stored locally on your device, you have full control:
- **Access:** View all your data in the App at any time
- **Deletion:** Delete the App to remove all data, or clear data from Settings
- **Portability:** Your health data remains in Apple HealthKit, accessible by any HealthKit-compatible app

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be reflected in the "Last Updated" date above.

## Contact

If you have questions about this privacy policy, please contact us at:
- Email: abundra.dev@gmail.com
- GitHub: https://github.com/Lfrangt/pulse-watch/issues

---

# 隐私政策 — Pulse

**最后更新：2026年3月27日**

Pulse（以下简称"本应用"）由 Abundra 开发。本隐私政策说明我们如何处理您的数据。

## 概要

Pulse 是一款隐私优先的应用。**您的所有健康数据均存储在您的设备上。** 我们不会收集、存储或传输您的个人健康信息到任何服务器。

## 数据收集

### 健康数据 (HealthKit)

本应用从 Apple HealthKit 读取以下数据：
- 心率、静息心率、心率变异性 (HRV)
- 血氧饱和度 (SpO2)
- 睡眠分析（时长、阶段）
- 步数
- 活动与静息能量消耗

本应用在您于 Apple Watch 上完成训练时，会将运动数据写入 HealthKit。

**所有 HealthKit 数据均使用 Apple 的 SwiftData 框架在设备本地处理和存储，绝不会传输到外部服务器。**

### 位置数据

本应用使用位置服务检测您是否到达已保存的健身房位置，以提供自动训练建议。位置数据：
- 完全在设备上处理
- 绝不上传到任何服务器
- 绝不与第三方共享

### 相机

本应用仅使用相机扫描 OpenClaw 配对二维码。不存储或传输任何图像或视频。

### 分析

本应用使用 TelemetryDeck 进行匿名、隐私保护的使用分析。TelemetryDeck 不收集个人信息，符合 GDPR 规定。分析数据中不包含任何健康数据。

## 可选：OpenClaw 集成

如果您选择将本应用连接到您自己的 OpenClaw 实例（可选的 AI 教练功能），本应用会将聚合的健康摘要传输到您指定的服务器。此连接：
- 完全由用户选择启用
- 由您使用自己的服务器 URL 和凭据配置
- 通过 HTTPS 的 Bearer Token 认证保护
- 您可以随时断开连接

**我们不运营也无法访问您的 OpenClaw 服务器。**

## 数据存储

所有数据存储在设备本地：健康记录（SwiftData）、偏好设置（UserDefaults）、OpenClaw 令牌（iOS 钥匙串加密存储）、小组件数据（App Group 容器）。

## 数据共享

我们不会向任何第三方出售、共享或传输您的个人数据。

## 联系方式

如有隐私相关问题，请通过邮件 abundra.dev@gmail.com 或 [GitHub Issues](https://github.com/Lfrangt/pulse-watch/issues) 联系我们。
