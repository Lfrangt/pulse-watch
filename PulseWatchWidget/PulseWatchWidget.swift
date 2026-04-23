import WidgetKit
import SwiftUI

// MARK: - Widget 数据读取

/// 从 App Group UserDefaults 读取 OpenClawBridge 写入的健康数据
enum WidgetDataProvider {
    static let appGroupID = "group.com.hallidai.pulse.shared"

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

        // 计算心率趋势方向
        let hrTrend = computeHeartRateTrend(from: status)

        return WidgetHealthData(
            score: status.recoveryScore,
            headline: headlineForScore(status.recoveryScore),
            heartRate: Int(status.latestVitals.heartRate ?? 0),
            hrv: Int(status.latestVitals.hrv ?? 0),
            sleepHours: status.todaySummary.sleepHours ?? 0,
            steps: status.todaySummary.totalSteps ?? 0,
            activeCalories: Int(status.todaySummary.activeCalories ?? 0),
            insight: status.trainingAdvice,
            lastUpdated: status.timestamp,
            heartRateTrend: hrTrend,
            dailyScores: status.weekTrend.dailyScores
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

    /// 根据 weekTrend 中的 HRV 趋势推算心率趋势箭头
    private static func computeHeartRateTrend(from status: SharedHealthStatus) -> HeartRateTrend {
        let scores = status.weekTrend.dailyScores
        guard scores.count >= 2 else { return .stable }
        let recent = scores.suffix(2).map(\.score)
        let last = recent.last ?? 0
        let prev = recent.first ?? 0
        if last > prev + 5 { return .up }
        if last < prev - 5 { return .down }
        return .stable
    }
}

// MARK: - 心率趋势方向

enum HeartRateTrend {
    case up, down, stable

    var arrow: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .stable: return "→"
        }
    }

    var systemImage: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
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
    let activeCalories: Int
    let insight: String
    let lastUpdated: Date
    let heartRateTrend: HeartRateTrend
    let dailyScores: [SharedDayScore]

    static let placeholder = WidgetHealthData(
        score: 72,
        headline: "Good",
        heartRate: 68,
        hrv: 45,
        sleepHours: 7.5,
        steps: 6500,
        activeCalories: 320,
        insight: "Ready for moderate-high intensity",
        lastUpdated: .now,
        heartRateTrend: .stable,
        dailyScores: [
            SharedDayScore(date: "2026-03-09", score: 65),
            SharedDayScore(date: "2026-03-10", score: 70),
            SharedDayScore(date: "2026-03-11", score: 68),
            SharedDayScore(date: "2026-03-12", score: 74),
            SharedDayScore(date: "2026-03-13", score: 71),
            SharedDayScore(date: "2026-03-14", score: 76),
            SharedDayScore(date: "2026-03-15", score: 72),
        ]
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
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? Date().addingTimeInterval(1800)
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

// ╔════════════════════════════════════════════════════════════╗
// ║  LOCK SCREEN WIDGETS                                      ║
// ╚════════════════════════════════════════════════════════════╝

// MARK: - Lock Screen — accessoryCircular（心率 + 趋势箭头）

struct PulseLockScreenCircular: View {
    let data: WidgetHealthData

    var body: some View {
        ZStack {
            // 评分进度环
            AccessoryWidgetBackground()

            Gauge(value: Double(data.score), in: 0...100) {
                // Label (不在 circular 显示)
            } currentValueLabel: {
                VStack(spacing: -1) {
                    if data.heartRate > 0 {
                        Text("\(data.heartRate)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    } else {
                        Text("--")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    HStack(spacing: 1) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 6))
                        Image(systemName: data.heartRateTrend.systemImage)
                            .font(.system(size: 6, weight: .bold))
                    }
                }
            }
            .gaugeStyle(.accessoryCircular)
        }
        .widgetURL(URL(string: "pulse://dashboard"))
    }
}

// MARK: - Lock Screen — accessoryRectangular（评分 + HR + HRV + 睡眠）

struct PulseLockScreenRectangular: View {
    let data: WidgetHealthData

    var body: some View {
        HStack(spacing: 8) {
            // 左侧：评分 gauge
            Gauge(value: Double(data.score), in: 0...100) {
                Text("")
            } currentValueLabel: {
                Text("\(data.score)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
            .frame(width: 40)

            // 右侧：指标列表
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                    Text(data.heartRate > 0 ? "\(data.heartRate) bpm" : "-- bpm")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                    Text(data.heartRateTrend.arrow)
                        .font(.system(size: 9, weight: .bold))
                }

                HStack(spacing: 3) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 8))
                    Text(data.hrv > 0 ? "HRV \(data.hrv)ms" : "HRV --")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }

                HStack(spacing: 3) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 8))
                    Text(data.sleepHours > 0 ? formatSleepCompact(data.sleepHours) : "--")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
            }
        }
        .widgetURL(URL(string: "pulse://dashboard"))
    }

    private func formatSleepCompact(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h\(m)m"
    }
}

// MARK: - Lock Screen — accessoryInline（简洁一行文字）

struct PulseLockScreenInline: View {
    let data: WidgetHealthData

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
            if data.heartRate > 0 {
                Text("\(data.heartRate)bpm")
            }
            Text("·")
            Text("Score \(data.score)")
        }
    }
}

// ╔════════════════════════════════════════════════════════════╗
// ║  HOME SCREEN WIDGETS                                      ║
// ╚════════════════════════════════════════════════════════════╝

// MARK: - Small Widget — 今日摘要（评分环 + HR/步数/卡路里）

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

            VStack(spacing: 8) {
                // 评分圆环 + 心率
                HStack(spacing: 10) {
                    // 迷你评分环
                    ZStack {
                        Circle()
                            .stroke(WidgetColors.border, lineWidth: 4)
                            .frame(width: 50, height: 50)

                        Circle()
                            .trim(from: 0, to: CGFloat(data.score) / 100)
                            .stroke(
                                statusColor,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: -2) {
                            Text("\(data.score)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(WidgetColors.textPrimary)
                            Text("pts")
                                .font(.system(size: 7, weight: .medium, design: .rounded))
                                .foregroundStyle(WidgetColors.textTertiary)
                        }
                    }

                    // 心率 + 状态
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.headline)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(statusColor)

                        if data.heartRate > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(WidgetColors.statusPoor)
                                Text("\(data.heartRate)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(WidgetColors.textPrimary)
                                Image(systemName: data.heartRateTrend.systemImage)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(WidgetColors.textSecondary)
                            }
                        }
                    }
                }

                // 底部三格指标
                HStack(spacing: 6) {
                    SmallMetricPill(
                        icon: "figure.walk",
                        value: formatSteps(data.steps),
                        color: WidgetColors.statusGood
                    )
                    SmallMetricPill(
                        icon: "flame.fill",
                        value: data.activeCalories > 0 ? "\(data.activeCalories)" : "--",
                        color: WidgetColors.statusModerate
                    )
                    SmallMetricPill(
                        icon: "moon.fill",
                        value: formatSleepShort(data.sleepHours),
                        color: WidgetColors.sleepPurple
                    )
                }
            }
        }
        .widgetURL(URL(string: "pulse://dashboard"))
    }

    private func formatSteps(_ steps: Int) -> String {
        guard steps > 0 else { return "--" }
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }

    private func formatSleepShort(_ hours: Double) -> String {
        guard hours > 0 else { return "--" }
        return String(format: "%.1f", hours)
    }
}

/// 迷你指标药丸（Small Widget 底部用）
struct SmallMetricPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(WidgetColors.cardBackground)
        )
    }
}

// MARK: - Medium Widget — 评分圆环 + 四格指标 + 7天迷你趋势线

struct PulseWidgetMedium: View {
    let data: WidgetHealthData

    private var statusColor: Color { WidgetColors.statusColor(for: data.score) }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧：评分圆环
            VStack(spacing: 6) {
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

                    VStack(spacing: 0) {
                        Text("\(data.score)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetColors.textPrimary)

                        Text(data.headline)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(statusColor)
                    }
                }

                // 迷你 7 天趋势线
                if !data.dailyScores.isEmpty {
                    MiniSparkline(scores: data.dailyScores.map(\.score), color: statusColor)
                        .frame(width: 64, height: 20)
                }
            }
            .frame(width: 86)

            // 右侧：四格指标
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    WidgetMetricTile(
                        icon: "heart.fill",
                        label: String(localized: "HR"),
                        value: data.heartRate > 0 ? "\(data.heartRate)" : "--",
                        unit: "bpm",
                        color: WidgetColors.statusPoor,
                        trendImage: data.heartRateTrend.systemImage
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
                        label: String(localized: "Sleep"),
                        value: formatSleep(data.sleepHours),
                        unit: "",
                        color: WidgetColors.sleepPurple
                    )
                    WidgetMetricTile(
                        icon: "flame.fill",
                        label: String(localized: "Cal"),
                        value: data.activeCalories > 0 ? "\(data.activeCalories)" : "--",
                        unit: "kcal",
                        color: WidgetColors.statusModerate
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
}

// MARK: - 迷你 7 天趋势 Sparkline

struct MiniSparkline: View {
    let scores: [Int]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let count = scores.count
            guard count >= 2 else { return AnyView(EmptyView()) }

            let minVal = Double(scores.min() ?? 0) - 5
            let maxVal = Double(scores.max() ?? 100) + 5
            let range = max(maxVal - minVal, 1)
            let stepX = geo.size.width / CGFloat(count - 1)

            let points: [CGPoint] = scores.enumerated().map { i, score in
                let x = CGFloat(i) * stepX
                let y = geo.size.height - (CGFloat(Double(score) - minVal) / CGFloat(range)) * geo.size.height
                return CGPoint(x: x, y: y)
            }

            return AnyView(
                ZStack {
                    // 面积填充
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        for pt in points {
                            path.addLine(to: pt)
                        }
                        if let lastPoint = points.last {
                            path.addLine(to: CGPoint(x: lastPoint.x, y: geo.size.height))
                        }
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.25), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // 折线
                    Path { path in
                        path.move(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                    // 最后一个点高亮
                    if let last = points.last {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .position(last)
                    }
                }
            )
        }
    }
}

// MARK: - 指标小格子（带可选趋势箭头）

struct WidgetMetricTile: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color
    var trendImage: String? = nil

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
                if let trend = trendImage {
                    Image(systemName: trend)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(WidgetColors.textSecondary)
                } else if !unit.isEmpty {
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

// MARK: - Large Widget — 评分圆环 + 指标 + 7天趋势 + 今日洞察

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
                    Text(String(localized: "Today"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetColors.textTertiary)

                    Text(data.headline)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)

                    Text(String(localized: "Updated \(timeAgoString(data.lastUpdated))"))
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(WidgetColors.textTertiary)
                }

                Spacer()
            }

            // 中部：四格指标
            HStack(spacing: 8) {
                LargeWidgetMetric(
                    icon: "heart.fill",
                    label: String(localized: "HR"),
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
                    label: String(localized: "Sleep"),
                    value: formatSleep(data.sleepHours),
                    unit: "",
                    color: WidgetColors.sleepPurple
                )
                LargeWidgetMetric(
                    icon: "flame.fill",
                    label: String(localized: "Cal"),
                    value: data.activeCalories > 0 ? "\(data.activeCalories)" : "--",
                    unit: "kcal",
                    color: WidgetColors.statusModerate
                )
            }

            // 7天趋势图
            if data.dailyScores.count >= 2 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10))
                            .foregroundStyle(WidgetColors.accent)
                        Text(String(localized: "7-Day Trend"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(WidgetColors.textSecondary)
                    }

                    LargeSparkline(scores: data.dailyScores, color: statusColor)
                        .frame(height: 36)
                }
                .padding(.horizontal, 4)
            }

            // 底部：今日洞察卡片
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetColors.accent)
                    Text(String(localized: "Insights"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetColors.accent)
                }

                Text(insightText)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(WidgetColors.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
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

    private var insightText: String {
        let advice = translateAdvice(data.insight)
        if data.sleepHours > 0 && data.sleepHours < 6 {
            return String(localized: "Under 6h sleep — focus on recovery today. \(advice)")
        } else if data.score >= 80 {
            return String(localized: "Great shape! \(advice) — seize the window.")
        } else if data.score >= 60 {
            return String(localized: "\(advice). Stay hydrated and refuel with protein.")
        } else {
            return String(localized: "Recovery needed. \(advice). Sleep is the best recovery.")
        }
    }

    private func translateAdvice(_ advice: String) -> String {
        switch advice.lowercased() {
        case "intense": return String(localized: "High intensity")
        case "moderate": return String(localized: "Moderate intensity")
        case "light": return String(localized: "Light activity")
        case "rest": return String(localized: "Rest recommended")
        default: return advice
        }
    }

    private func timeAgoString(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return String(localized: "Just now") }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return String(localized: ">1 day ago")
    }

    private func formatSleep(_ hours: Double) -> String {
        guard hours > 0 else { return "--" }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h\(m)m"
    }
}

// MARK: - Large Widget 趋势图（带日期标签）

struct LargeSparkline: View {
    let scores: [SharedDayScore]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let values = scores.map(\.score)
            let count = values.count
            guard count >= 2 else { return AnyView(EmptyView()) }

            let minVal = Double(values.min() ?? 0) - 5
            let maxVal = Double(values.max() ?? 100) + 5
            let range = max(maxVal - minVal, 1)
            let stepX = geo.size.width / CGFloat(count - 1)

            let points: [CGPoint] = values.enumerated().map { i, score in
                let x = CGFloat(i) * stepX
                let y = geo.size.height - (CGFloat(Double(score) - minVal) / CGFloat(range)) * geo.size.height
                return CGPoint(x: x, y: y)
            }

            return AnyView(
                ZStack {
                    // 面积填充
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        for pt in points {
                            path.addLine(to: pt)
                        }
                        if let lastPoint = points.last {
                            path.addLine(to: CGPoint(x: lastPoint.x, y: geo.size.height))
                        }
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // 折线
                    Path { path in
                        path.move(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // 数据点
                    ForEach(Array(points.enumerated()), id: \.offset) { i, pt in
                        Circle()
                            .fill(i == points.count - 1 ? color : color.opacity(0.6))
                            .frame(width: i == points.count - 1 ? 5 : 3, height: i == points.count - 1 ? 5 : 3)
                            .position(pt)
                    }
                }
            )
        }
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

// ╔════════════════════════════════════════════════════════════╗
// ║  WIDGET ENTRY VIEW + DEFINITIONS                          ║
// ╚════════════════════════════════════════════════════════════╝

// MARK: - Home Screen Widget Entry View

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

// MARK: - Lock Screen Widget Entry View

struct PulseLockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PulseWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            PulseLockScreenCircular(data: entry.data)
        case .accessoryRectangular:
            PulseLockScreenRectangular(data: entry.data)
        case .accessoryInline:
            PulseLockScreenInline(data: entry.data)
        default:
            PulseLockScreenCircular(data: entry.data)
        }
    }
}

// MARK: - Home Screen Widget 定义

struct PulseHomeWidget: Widget {
    let kind = "PulseHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWidgetProvider()) { entry in
            PulseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Pulse Status"))
        .description(String(localized: "Today's health score, heart rate, HRV, sleep and steps"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Lock Screen Widget 定义

struct PulseLockScreenWidget: Widget {
    let kind = "PulseLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWidgetProvider()) { entry in
            PulseLockScreenEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Pulse Lock Screen"))
        .description(String(localized: "Heart rate and recovery score at a glance"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Widget Bundle

@main
struct PulseWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        PulseHomeWidget()
        PulseLockScreenWidget()
    }
}

// MARK: - Previews

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

#Preview("Lock Circular", as: .accessoryCircular) {
    PulseLockScreenWidget()
} timeline: {
    PulseWidgetEntry(date: .now, data: .placeholder)
}

#Preview("Lock Rectangular", as: .accessoryRectangular) {
    PulseLockScreenWidget()
} timeline: {
    PulseWidgetEntry(date: .now, data: .placeholder)
}

#Preview("Lock Inline", as: .accessoryInline) {
    PulseLockScreenWidget()
} timeline: {
    PulseWidgetEntry(date: .now, data: .placeholder)
}
