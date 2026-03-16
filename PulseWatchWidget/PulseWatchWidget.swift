import WidgetKit
import SwiftUI

// MARK: - Widget 数据读取

/// 从 App Group UserDefaults 读取 OpenClawBridge 写入的健康数据
enum WidgetDataProvider {
    static let appGroupID = "group.com.abundra.pulse.shared"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// 从共享 UserDefaults 解码完整健康状态
    static func loadHealthStatus() -> WidgetHealthData {
        guard let defaults = defaults,
              let data = defaults.data(forKey: "pulse.healthStatus") else {
            return .placeholder
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate

        guard let status = try? decoder.decode(SharedHealthStatus.self, from: data) else {
            return .placeholder
        }

        return WidgetHealthData(
            score: status.recoveryScore,
            headline: headlineForScore(status.recoveryScore),
            heartRate: Int(status.latestVitals.heartRate ?? 0),
            hrv: Int(status.latestVitals.hrv ?? 0),
            sleepHours: status.todaySummary.sleepHours ?? 0,
            steps: status.todaySummary.totalSteps ?? 0,
            insight: status.trainingAdvice,
            lastUpdated: status.timestamp
        )
    }

    private static func headlineForScore(_ score: Int) -> String {
        switch score {
        case 0..<30: return String(localized: "Rest")
        case 30..<50: return String(localized: "Average")
        case 50..<70: return String(localized: "Fair")
        case 70..<85: return String(localized: "Good")
        default: return String(localized: "Peak")
        }
    }
}

// MARK: - 共享数据模型（匹配 OpenClawBridge.HealthStatus）

struct SharedHealthStatus: Codable {
    let timestamp: Date
    let todaySummary: SharedTodaySummary
    let latestVitals: SharedVitals
    let weekTrend: SharedWeekTrend
    let recoveryScore: Int
    let trainingAdvice: String
}

struct SharedTodaySummary: Codable {
    let date: String
    let dailyScore: Int?
    let sleepHours: Double?
    let deepSleepMinutes: Int?
    let remSleepMinutes: Int?
    let totalSteps: Int?
    let activeCalories: Double?
}

struct SharedVitals: Codable {
    let heartRate: Double?
    let hrv: Double?
    let restingHeartRate: Double?
    let bloodOxygen: Double?
    let lastUpdated: Date?
}

struct SharedWeekTrend: Codable {
    let averageScore: Int?
    let scoreTrend: String
    let hrvTrend: String
    let sleepTrend: String
    let dailyScores: [SharedDayScore]
}

struct SharedDayScore: Codable {
    let date: String
    let score: Int
}

// MARK: - Widget 内部数据

struct WidgetHealthData {
    let score: Int
    let headline: String
    let heartRate: Int
    let hrv: Int
    let sleepHours: Double
    let steps: Int
    let insight: String
    let lastUpdated: Date

    static let placeholder = WidgetHealthData(
        score: 72,
        headline: "Good",
        heartRate: 68,
        hrv: 45,
        sleepHours: 7.5,
        steps: 6500,
        insight: "Ready for moderate-high intensity",
        lastUpdated: .now
    )
}

// MARK: - Timeline Entry

struct PulseWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetHealthData
}

// MARK: - Timeline Provider

struct PulseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseWidgetEntry {
        PulseWidgetEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseWidgetEntry) -> Void) {
        let data = WidgetDataProvider.loadHealthStatus()
        completion(PulseWidgetEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseWidgetEntry>) -> Void) {
        let data = WidgetDataProvider.loadHealthStatus()
        let entry = PulseWidgetEntry(date: .now, data: data)
        // 每 30 分钟刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - 颜色工具（Widget 独立，不依赖主 app PulseTheme）

enum WidgetColors {
    static let background = Color(hex: "0D0C0B")
    static let surface = Color(hex: "161412")
    static let cardBackground = Color(hex: "1A1816")
    static let border = Color(hex: "2A2623")
    static let textPrimary = Color(hex: "F5F0EB")
    static let textSecondary = Color(hex: "9A938C")
    static let textTertiary = Color(hex: "5C564F")
    static let accent = Color(hex: "C9A96E")
    static let statusGood = Color(hex: "7FB069")
    static let statusModerate = Color(hex: "D4A056")
    static let statusPoor = Color(hex: "C75C5C")
    static let sleepPurple = Color(hex: "8B7EC8")

    static func statusColor(for score: Int) -> Color {
        switch score {
        case 0..<40: return statusPoor
        case 40..<70: return statusModerate
        default: return statusGood
        }
    }
}

// MARK: - Color hex 扩展

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

// MARK: - Small Widget — 评分圆环 + 数值

struct PulseWidgetSmall: View {
    let data: WidgetHealthData

    private var statusColor: Color { WidgetColors.statusColor(for: data.score) }

    var body: some View {
        ZStack {
            // 背景光晕
            RadialGradient(
                colors: [statusColor.opacity(0.12), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 80
            )

            VStack(spacing: 6) {
                // 评分圆环
                ZStack {
                    Circle()
                        .stroke(WidgetColors.border, lineWidth: 5)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: CGFloat(data.score) / 100)
                        .stroke(
                            statusColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(data.score)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetColors.textPrimary)

                        Text("pts")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(WidgetColors.textTertiary)
                    }
                }

                Text(data.headline)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(statusColor)
            }
        }
        .widgetURL(URL(string: "pulse://dashboard"))
    }
}

// MARK: - Medium Widget — 评分圆环 + 四格指标

struct PulseWidgetMedium: View {
    let data: WidgetHealthData

    private var statusColor: Color { WidgetColors.statusColor(for: data.score) }

    var body: some View {
        HStack(spacing: 14) {
            // 左侧：评分圆环
            ZStack {
                // 光晕
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 88, height: 88)
                    .blur(radius: 8)

                Circle()
                    .stroke(WidgetColors.border, lineWidth: 5)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(data.score) / 100)
                    .stroke(
                        statusColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(data.score)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.textPrimary)

                    Text(data.headline)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(statusColor)
                }
            }
            .frame(width: 90)

            // 右侧：四格指标
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    WidgetMetricTile(
                        icon: "heart.fill",
                        label: "HR",
                        value: data.heartRate > 0 ? "\(data.heartRate)" : "--",
                        unit: "bpm",
                        color: WidgetColors.statusPoor
                    )
                    WidgetMetricTile(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        value: data.hrv > 0 ? "\(data.hrv)" : "--",
                        unit: "ms",
                        color: WidgetColors.accent
                    )
                }
                HStack(spacing: 6) {
                    WidgetMetricTile(
                        icon: "moon.fill",
                        label: "Sleep",
                        value: formatSleep(data.sleepHours),
                        unit: "",
                        color: WidgetColors.sleepPurple
                    )
                    WidgetMetricTile(
                        icon: "figure.walk",
                        label: "Steps",
                        value: formatSteps(data.steps),
                        unit: "",
                        color: WidgetColors.statusGood
                    )
                }
            }
        }
        .widgetURL(URL(string: "pulse://dashboard"))
    }

    private func formatSleep(_ hours: Double) -> String {
        guard hours > 0 else { return "--" }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h\(m)m"
    }

    private func formatSteps(_ steps: Int) -> String {
        guard steps > 0 else { return "--" }
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }
}

// MARK: - 指标小格子

struct WidgetMetricTile: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetColors.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                        .foregroundStyle(WidgetColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(WidgetColors.cardBackground)
        )
    }
}

// MARK: - Large Widget — 评分圆环 + 指标 + 今日洞察

struct PulseWidgetLarge: View {
    let data: WidgetHealthData

    private var statusColor: Color { WidgetColors.statusColor(for: data.score) }

    var body: some View {
        VStack(spacing: 12) {
            // 顶部：评分圆环 + 状态
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.1))
                        .frame(width: 78, height: 78)
                        .blur(radius: 6)

                    Circle()
                        .stroke(WidgetColors.border, lineWidth: 5)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: CGFloat(data.score) / 100)
                        .stroke(
                            statusColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    Text("\(data.score)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetColors.textTertiary)

                    Text(data.headline)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)

                    Text("Updated \(timeAgoString(data.lastUpdated))")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(WidgetColors.textTertiary)
                }

                Spacer()
            }

            // 中部：四格指标
            HStack(spacing: 8) {
                LargeWidgetMetric(
                    icon: "heart.fill",
                    label: "HR",
                    value: data.heartRate > 0 ? "\(data.heartRate)" : "--",
                    unit: "bpm",
                    color: WidgetColors.statusPoor
                )
                LargeWidgetMetric(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: data.hrv > 0 ? "\(data.hrv)" : "--",
                    unit: "ms",
                    color: WidgetColors.accent
                )
                LargeWidgetMetric(
                    icon: "moon.fill",
                    label: "Sleep",
                    value: formatSleep(data.sleepHours),
                    unit: "",
                    color: WidgetColors.sleepPurple
                )
                LargeWidgetMetric(
                    icon: "figure.walk",
                    label: "Steps",
                    value: formatSteps(data.steps),
                    unit: "",
                    color: WidgetColors.statusGood
                )
            }

            // 底部：今日洞察卡片
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetColors.accent)
                    Text("Insights")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetColors.accent)
                }

                Text(insightText)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(WidgetColors.textPrimary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(WidgetColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(WidgetColors.border.opacity(0.5), lineWidth: 0.5)
            )
        }
        .widgetURL(URL(string: "pulse://dashboard"))
    }

    /// 根据评分和数据生成洞察文本
    private var insightText: String {
        let advice = translateAdvice(data.insight)

        if data.sleepHours > 0 && data.sleepHours < 6 {
            return "Under 6h sleep — focus on recovery today. \(advice)"
        } else if data.score >= 80 {
            return "Great shape! \(advice) — seize the window."
        } else if data.score >= 60 {
            return "\(advice). Stay hydrated and refuel with protein."
        } else {
            return "Recovery needed. \(advice). Sleep is the best recovery."
        }
    }

    /// 将英文训练建议翻译为中文
    private func translateAdvice(_ advice: String) -> String {
        switch advice.lowercased() {
        case "intense": return "High intensity"
        case "moderate": return "Moderate intensity"
        case "light": return "Light activity"
        case "rest": return "Rest recommended"
        default: return advice
        }
    }

    private func timeAgoString(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return ">1 day ago"
    }

    private func formatSleep(_ hours: Double) -> String {
        guard hours > 0 else { return "--" }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h\(m)m"
    }

    private func formatSteps(_ steps: Int) -> String {
        guard steps > 0 else { return "--" }
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }
}

// MARK: - Large Widget 指标条

struct LargeWidgetMetric: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetColors.textPrimary)

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 8, weight: .regular, design: .rounded))
                    .foregroundStyle(WidgetColors.textTertiary)
            } else {
                Text(label)
                    .font(.system(size: 8, weight: .regular, design: .rounded))
                    .foregroundStyle(WidgetColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(WidgetColors.cardBackground)
        )
    }
}

// MARK: - Widget Entry View（分发三种尺寸）

struct PulseWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PulseWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                PulseWidgetSmall(data: entry.data)
            case .systemMedium:
                PulseWidgetMedium(data: entry.data)
            case .systemLarge:
                PulseWidgetLarge(data: entry.data)
            default:
                PulseWidgetSmall(data: entry.data)
            }
        }
        .containerBackground(for: .widget) {
            WidgetColors.background
        }
    }
}

// MARK: - Widget 定义

struct PulseHomeWidget: Widget {
    let kind = "PulseHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWidgetProvider()) { entry in
            PulseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pulse Status")
        .description("Today's health score, heart rate, HRV, sleep and steps")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Bundle

@main
struct PulseWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        PulseHomeWidget()
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    PulseHomeWidget()
} timeline: {
    PulseWidgetEntry(date: .now, data: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    PulseHomeWidget()
} timeline: {
    PulseWidgetEntry(date: .now, data: .placeholder)
}

#Preview("Large", as: .systemLarge) {
    PulseHomeWidget()
} timeline: {
    PulseWidgetEntry(date: .now, data: .placeholder)
}
