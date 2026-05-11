# Pulse Watch — 前端 UI 审查报告

**日期：** 2026-03-27
**分支：** claude/sync-apple-watch-data-phjbD
**审查范围：** PulseWatch/ 全部视图、资源、无障碍、本地化

---

## 审查发现与修复

### 1. 本地化（严重 — App Store 阻断级）

**问题：** 70+ 个用户可见字符串硬编码在 Swift 文件中，未使用 `String(localized:)` 包裹。涉及 SettingsView（57个）、DashboardView、HistoryView、HomeView 等 12 个文件。另有硬编码中文字符串（"分钟"、"vs 30天前"）和硬编码中文日期格式。

**修复：** 全部包裹 `String(localized:)`；中文硬编码改为本地化键；日期格式改用 `dateStyle/timeStyle` 随系统语言；星期缩写改用 `Calendar.current.veryShortStandaloneWeekdaySymbols`。

**额外发现：** 分钟选择器标签错误显示为 "pts"，已修正为 "min"。

### 2. 资源文件

**问题：** watchOS 资源目录中存在孤立空目录 `AppIcon 1.appiconset/`，可能导致构建警告。

**修复：** 已删除。

### 3. 启动页一致性

**问题：** `LaunchScreenView` 使用硬编码 `Color(hex:)` 和魔法数字字号，未使用设计系统 `PulseTheme`。

**修复：** 全部替换为 `PulseTheme.background`、`accentTeal`、`textPrimary`、`textTertiary`、`spacingS`、`bodyFont`。

### 4. 导航标题不一致

**问题：** 部分详情页使用 `.large` 导航标题（BloodOxygen、Steps、Calories、HealthAge），其余用 `.inline`，视觉不统一。

**修复：** 统一为 `.inline`。

### 5. 文字对比度不达标

**问题：** `PulseTheme.textTertiary`（#849495）在深色背景上对比度仅 3.2:1，低于 WCAG AA 标准 4.5:1。

**修复：** 调整为 #9AABAC（约 4.6:1），保持同色相，亮度提升。

### 6. 空状态不一致

**问题：** RecoveryTimelineView 有完整空状态 UI，但 StepsDetailView/CaloriesDetailView 仅一行文字，TrainingCalendarView/SleepDetailView 完全没有空状态。

**修复：** 新建通用 `EmptyStateView` 组件（图标 + 标题 + 说明），已应用到 Steps 和 Calories 详情页。

### 7. 编译错误修复

**问题：** `OnboardingView.swift:436` 调用了 `LocationManager` 不存在的方法 `requestAlwaysAuthorization()`。

**修复：** 改为正确方法 `requestAuthorization()`。

---

## 未修复（记录在案）

| 问题 | 严重度 | 说明 |
|------|--------|------|
| 546 处硬编码字号 | 中 | 影响 Dynamic Type 无障碍，需大规模重构 |
| 20+ 处 opacity < 0.5 的白色文字 | 中 | ShareCardView 等，需逐一评估设计意图 |
| 部分按钮点击区域 < 44pt | 低 | 多数被父容器 padding 覆盖 |
| BloodOxygen 14 天 SpO2 图表数据未实现 | 低 | 功能缺失，非 UI 问题 |
| Chart 无障碍标签缺失 | 低 | Swift Charts 需额外 accessibility 配置 |
| SleepDetailView/TrainingCalendarView 空状态 | 低 | 可后续用 EmptyStateView 补充 |
| InfoPlist.xcstrings 缺少部分中文翻译 | 低 | CFBundleName、NSLocalNetworkUsageDescription |

---

## 构建验证

**BUILD SUCCEEDED** — iPhone 16 Pro Simulator (iOS 18.5)
