import WidgetKit
import SwiftUI

// MARK: - Widget data provider

/// Reads OpenClawBridge-written health snapshot from the App Group UserDefaults.
enum WidgetDataProvider {
    static let appGroupID = "group.com.hallidai.pulse.shared"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

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
        case 0..<30:  return String(localized: "Rest")
        case 30..<50: return String(localized: "Average")
        case 50..<70: return String(localized: "Fair")
        case 70..<85: return String(localized: "Good")
        default:      return String(localized: "Peak")
        }
    }

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

// MARK: - HR trend

enum HeartRateTrend {
    case up, down, stable

    var arrow: String {
        switch self {
        case .up:     return "↑"
        case .down:   return "↓"
        case .stable: return "→"
        }
    }

    var systemImage: String {
        switch self {
        case .up:     return "arrow.up.right"
        case .down:   return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var deltaText: String {
        switch self {
        case .up:     return "↑"
        case .down:   return "↓"
        case .stable: return "—"
        }
    }
}

// MARK: - Shared models (mirror OpenClawBridge.HealthStatus)

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

// MARK: - Widget data

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
        score: 78,
        headline: "Good",
        heartRate: 52,
        hrv: 58,
        sleepHours: 7.5,
        steps: 6500,
        activeCalories: 320,
        insight: "Ready for moderate-high intensity",
        lastUpdated: .now,
        heartRateTrend: .up,
        dailyScores: [
            SharedDayScore(date: "2026-04-21", score: 58),
            SharedDayScore(date: "2026-04-22", score: 64),
            SharedDayScore(date: "2026-04-23", score: 71),
            SharedDayScore(date: "2026-04-24", score: 68),
            SharedDayScore(date: "2026-04-25", score: 75),
            SharedDayScore(date: "2026-04-26", score: 72),
            SharedDayScore(date: "2026-04-27", score: 78),
        ]
    )
}

// MARK: - Timeline

struct PulseWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetHealthData
}

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
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Clinical tokens (parallel to PulseTheme — widget target can't import the main module)

enum WidgetColors {
    // Surfaces — light + dark dynamic
    static let background       = dyn(light: 0xF7F6F2, dark: 0x000000)
    static let surface          = dyn(light: 0xFFFFFF, dark: 0x0E0E0E)
    static let cardBackground   = dyn(light: 0xFFFFFF, dark: 0x0E0E0E)
    static let border           = dyn(light: 0xE8E5DC, dark: 0x1F1F1F)
    static let borderStrong     = dyn(light: 0xD4CFC0, dark: 0x2A2A2A)
    static let chart3           = dyn(light: 0xD4CFC0, dark: 0x2A2A2A)

    // Foreground
    static let textPrimary      = dynA(light: (0x17161A, 1.00), dark: (0xF5F5F0, 1.00))
    static let textSecondary    = dynA(light: (0x52504C, 1.00), dark: (0xF5F5F0, 0.60))
    static let textTertiary     = dynA(light: (0x8A867E, 1.00), dark: (0xF5F5F0, 0.40))
    static let textQuaternary   = dynA(light: (0xB7B2A6, 1.00), dark: (0xF5F5F0, 0.20))

    // Accent (medical teal) + status
    static let accent           = dyn(light: 0x0A7E8C, dark: 0x4FD9E6)
    static let accentSoft       = dynA(light: (0x0A7E8C, 0.10), dark: (0x4FD9E6, 0.14))
    static let statusGood       = dyn(light: 0x2F9E5C, dark: 0x6BD393)
    static let statusWarning    = dyn(light: 0xC28A2C, dark: 0xE8B24F)
    static let statusPoor       = dyn(light: 0xC43E28, dark: 0xF07A5F)
    static let sleepViolet      = dyn(light: 0x6B5FC2, dark: 0xA898F5)

    // Legacy aliases used elsewhere
    static let statusModerate   = sleepViolet
    static let sleepPurple      = sleepViolet

    static func statusColor(for score: Int) -> Color {
        switch score {
        case 0..<40:  return statusPoor
        case 40..<70: return sleepViolet
        default:      return statusGood
        }
    }

    // MARK: - Dynamic helpers

    private static func dyn(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        return Color(rgb: dark)
        #endif
    }

    private static func dynA(light: (UInt32, Double), dark: (UInt32, Double)) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            let (hex, alpha) = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(rgb: hex, alpha: alpha)
        })
        #else
        return Color(rgb: dark.0).opacity(dark.1)
        #endif
    }
}

private extension Color {
    init(rgb: UInt32, alpha: Double = 1.0) {
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255,
                  opacity: alpha)
    }
}

#if canImport(UIKit)
import UIKit
private extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1.0) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }
    convenience init(rgb: UInt32, alpha: Double) {
        self.init(rgb: rgb, alpha: CGFloat(alpha))
    }
}
#endif

// MARK: - Eyebrow modifier (mirror of pulseEyebrow on iPhone)

private struct WidgetEyebrow: ViewModifier {
    var size: CGFloat = 10
    var tracking: CGFloat = 0.85
    var color: Color = WidgetColors.textTertiary

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .semibold))
            .tracking(tracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

private extension View {
    func widgetEyebrow(size: CGFloat = 10, color: Color = WidgetColors.textTertiary) -> some View {
        modifier(WidgetEyebrow(size: size, color: color))
    }
}

// MARK: - App glyph (medical instrument-style monogram)

struct WidgetAppGlyph: View {
    let size: CGFloat

    var body: some View {
        Text("P")
            .font(.system(size: size * 0.55, weight: .medium, design: .rounded))
            .kerning(-size * 0.02)
            .foregroundStyle(WidgetColors.background)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(WidgetColors.textPrimary)
            )
    }
}

// ╔════════════════════════════════════════════════════════════╗
// ║  LOCK SCREEN WIDGETS                                      ║
// ╚════════════════════════════════════════════════════════════╝

struct PulseLockScreenCircular: View {
    let data: WidgetHealthData

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Gauge(value: Double(data.score), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: -1) {
                    Text(data.heartRate > 0 ? "\(data.heartRate)" : "--")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
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

struct PulseLockScreenRectangular: View {
    let data: WidgetHealthData

    var body: some View {
        HStack(spacing: 8) {
            Gauge(value: Double(data.score), in: 0...100) {
                Text("")
            } currentValueLabel: {
                Text("\(data.score)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircular)
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                    Text(data.heartRate > 0 ? "\(data.heartRate) bpm" : "-- bpm")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Text(data.heartRateTrend.arrow)
                        .font(.system(size: 9, weight: .bold))
                }
                HStack(spacing: 3) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 8))
                    Text(data.hrv > 0 ? "HRV \(data.hrv)ms" : "HRV --")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                HStack(spacing: 3) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 8))
                    Text(data.sleepHours > 0 ? formatSleepCompact(data.sleepHours) : "--")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
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
// ║  HOME SCREEN WIDGETS — Clinical                           ║
// ╚════════════════════════════════════════════════════════════╝

// MARK: - Small — flat hero metric per Widget.jsx WidgetSmall

struct PulseWidgetSmall: View {
    let data: WidgetHealthData

    private var statusColor: Color { WidgetColors.statusColor(for: data.score) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App glyph + brand eyebrow
            HStack(spacing: 5) {
                WidgetAppGlyph(size: 14)
                Text("Pulse")
                    .widgetEyebrow(size: 10)
            }

            Spacer(minLength: 0)

            // Section eyebrow
            Text("Readiness")
                .widgetEyebrow(size: 9)
                .padding(.bottom, 2)

            // Hero metric
            Text("\(data.score)")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .monospacedDigit()
                .kerning(-1.4)
                .foregroundStyle(WidgetColors.textPrimary)
                .padding(.bottom, 4)

            // Delta vs avg (status color)
            Text(deltaLine)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(statusColor)

            Spacer(minLength: 0)

            // Bottom mono line
            Text(footer)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(WidgetColors.textQuaternary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "pulse://dashboard"))
    }

    private var deltaLine: String {
        let delta = computeDelta(data: data)
        if delta == 0 { return data.headline }
        let sign = delta > 0 ? "+" : ""
        return String(localized: "\(sign)\(delta) vs avg")
    }

    private var footer: String {
        // "06:48 · slept 7h 34m" pattern from Widget.jsx
        let timeStr = timeShortString(data.lastUpdated)
        if data.sleepHours > 0 {
            let h = Int(data.sleepHours)
            let m = Int((data.sleepHours - Double(h)) * 60)
            return "\(timeStr) · slept \(h)h \(m)m"
        }
        return timeStr
    }
}

// MARK: - Medium — hero number + 7-day mini bars per Widget.jsx WidgetMedium

struct PulseWidgetMedium: View {
    let data: WidgetHealthData

    private var statusColor: Color { WidgetColors.statusColor(for: data.score) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top row: glyph + Pulse · Readiness eyebrow … HH:MM
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    WidgetAppGlyph(size: 18)
                    Text(String(localized: "Pulse · Readiness"))
                        .widgetEyebrow(size: 11)
                }
                Spacer()
                Text(timeShortString(data.lastUpdated))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(WidgetColors.textQuaternary)
            }

            // Hero + bar chart row
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(data.score)")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .kerning(-2)
                        .foregroundStyle(WidgetColors.textPrimary)
                    Text(deltaLine)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(statusColor)
                }
                .padding(.top, 4)

                // 7-day mini-bars + day labels (latest day filled solid, others muted)
                if !data.dailyScores.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        WidgetWeekBars(scores: data.dailyScores)
                            .frame(height: 52)
                        WidgetWeekLabels(scores: data.dailyScores)
                    }
                    .padding(.bottom, 4)
                }
            }
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "pulse://dashboard"))
    }

    private var deltaLine: String {
        let delta = computeDelta(data: data)
        if delta == 0 { return data.headline }
        let sign = delta > 0 ? "+" : ""
        return String(localized: "\(sign)\(delta) vs 7-day avg")
    }
}

// MARK: - Large — compact dashboard

struct PulseWidgetLarge: View {
    let data: WidgetHealthData

    private var statusColor: Color { WidgetColors.statusColor(for: data.score) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Top: brand strip
            HStack {
                HStack(spacing: 6) {
                    WidgetAppGlyph(size: 18)
                    Text(String(localized: "Pulse · Today"))
                        .widgetEyebrow(size: 11)
                }
                Spacer()
                Text(timeShortString(data.lastUpdated))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(WidgetColors.textQuaternary)
            }

            // Hero + delta + 7-day bars side-by-side
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Readiness")
                        .widgetEyebrow(size: 10)
                    Text("\(data.score)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .kerning(-2)
                        .foregroundStyle(WidgetColors.textPrimary)
                    Text(deltaLine)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(statusColor)
                }

                if !data.dailyScores.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        WidgetWeekBars(scores: data.dailyScores)
                            .frame(height: 56)
                        WidgetWeekLabels(scores: data.dailyScores)
                    }
                }
            }

            // Hairline divider
            Rectangle()
                .fill(WidgetColors.border)
                .frame(height: 1)

            // Vitals grid — 4 columns of label + value
            HStack(alignment: .top, spacing: 14) {
                LargeVital(label: "HR",    value: data.heartRate > 0 ? "\(data.heartRate)" : "--", unit: "bpm")
                LargeVital(label: "HRV",   value: data.hrv > 0 ? "\(data.hrv)" : "--",            unit: "ms")
                LargeVital(label: "SLEEP", value: formatSleepShort(data.sleepHours),              unit: "")
                LargeVital(label: "KCAL",  value: data.activeCalories > 0 ? "\(data.activeCalories)" : "--", unit: "")
            }

            // Hairline divider
            Rectangle()
                .fill(WidgetColors.border)
                .frame(height: 1)

            // Insight footer
            VStack(alignment: .leading, spacing: 4) {
                Text("Insight")
                    .widgetEyebrow(size: 9)
                Text(insightText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(WidgetColors.textPrimary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "pulse://dashboard"))
    }

    private var deltaLine: String {
        let delta = computeDelta(data: data)
        if delta == 0 { return data.headline }
        let sign = delta > 0 ? "+" : ""
        return String(localized: "\(sign)\(delta) vs 7-day avg")
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
        case "intense":  return String(localized: "High intensity")
        case "moderate": return String(localized: "Moderate intensity")
        case "light":    return String(localized: "Light activity")
        case "rest":     return String(localized: "Rest recommended")
        default:         return advice
        }
    }
}

// MARK: - Large vitals cell

private struct LargeVital: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(WidgetColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WidgetColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(WidgetColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 7-day bars (latest day = solid fg, prior days = chart-3 muted)

struct WidgetWeekBars: View {
    let scores: [SharedDayScore]

    var body: some View {
        GeometryReader { geo in
            let count = max(scores.count, 1)
            let gap: CGFloat = 4
            let totalGap = gap * CGFloat(count - 1)
            let barW = max((geo.size.width - totalGap) / CGFloat(count), 4)

            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(scores.enumerated()), id: \.offset) { i, day in
                    let pct = max(CGFloat(day.score) / 100, 0.04)
                    Rectangle()
                        .fill(i == count - 1 ? WidgetColors.textPrimary : WidgetColors.chart3)
                        .frame(width: barW, height: geo.size.height * pct)
                        .clipShape(RoundedRectangle(cornerRadius: 1, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

// MARK: - 7-day day labels (W T F S S M T pattern; latest highlighted)

struct WidgetWeekLabels: View {
    let scores: [SharedDayScore]

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // single-letter weekday
        return f
    }()

    private static let isoParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    var body: some View {
        let count = scores.count
        HStack(spacing: 0) {
            ForEach(Array(scores.enumerated()), id: \.offset) { i, day in
                Text(letterFor(day.date))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(i == count - 1 ? WidgetColors.textPrimary : WidgetColors.textQuaternary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func letterFor(_ iso: String) -> String {
        guard let date = Self.isoParser.date(from: iso) else { return "·" }
        return Self.weekdayFormatter.string(from: date)
    }
}

// MARK: - Helpers

private func computeDelta(data: WidgetHealthData) -> Int {
    let prior = data.dailyScores.dropLast()
    guard !prior.isEmpty else { return 0 }
    let avg = prior.map(\.score).reduce(0, +) / prior.count
    return data.score - avg
}

private func timeShortString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

private func formatSleepShort(_ hours: Double) -> String {
    guard hours > 0 else { return "--" }
    let h = Int(hours)
    let m = Int((hours - Double(h)) * 60)
    return "\(h)h\(m)m"
}

// ╔════════════════════════════════════════════════════════════╗
// ║  WIDGET ENTRY VIEW + DEFINITIONS                          ║
// ╚════════════════════════════════════════════════════════════╝

struct PulseWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PulseWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  PulseWidgetSmall(data: entry.data)
            case .systemMedium: PulseWidgetMedium(data: entry.data)
            case .systemLarge:  PulseWidgetLarge(data: entry.data)
            default:            PulseWidgetSmall(data: entry.data)
            }
        }
        .containerBackground(for: .widget) {
            WidgetColors.background
        }
    }
}

struct PulseLockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PulseWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    PulseLockScreenCircular(data: entry.data)
        case .accessoryRectangular: PulseLockScreenRectangular(data: entry.data)
        case .accessoryInline:      PulseLockScreenInline(data: entry.data)
        default:                    PulseLockScreenCircular(data: entry.data)
        }
    }
}

struct PulseHomeWidget: Widget {
    let kind = "PulseHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWidgetProvider()) { entry in
            PulseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Pulse Status"))
        .description(String(localized: "Today's readiness score with 7-day trend."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

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
