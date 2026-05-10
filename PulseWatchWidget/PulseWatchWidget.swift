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

// MARK: - Widget tokens — thin shim over DS.Color so widget code can stay
// terse while every value resolves to the v2 Clinical design system.
// Widget target now includes Shared/Theme/DS.swift, so DS.Color is reachable.

enum WidgetColors {
    static let background       = DS.Color.bg
    static let surface          = DS.Color.bgElev
    static let cardBackground   = DS.Color.bgElev
    static let border           = DS.Color.line
    static let borderStrong     = DS.Color.line
    static let chart3           = DS.Color.lineSoft

    static let textPrimary      = DS.Color.ink
    static let textSecondary    = DS.Color.inkMid
    static let textTertiary     = DS.Color.inkDim
    static let textQuaternary   = DS.Color.inkDim

    static let accent           = DS.Color.accent
    static let accentSoft       = DS.Color.accent.opacity(0.12)
    static let statusGood       = DS.Color.good
    static let statusWarning    = DS.Color.warn
    static let statusPoor       = DS.Color.bad
    static let sleepViolet      = DS.Color.accent

    // Legacy aliases preserved for compile but unified to clinical mono accent.
    static let statusModerate   = DS.Color.warn
    static let sleepPurple      = DS.Color.accent

    static func statusColor(for score: Int) -> Color {
        switch score {
        case 0..<40:  return DS.Color.bad
        case 40..<70: return DS.Color.warn
        default:      return DS.Color.good
        }
    }

}

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
                        .font(DS.Typography.body.weight(.semibold))
                        .monospacedDigit()
                    HStack(spacing: 1) {
                        Image(systemName: "heart.fill")
                            .font(DS.Typography.monoS)
                        Image(systemName: data.heartRateTrend.systemImage)
                            .font(DS.Typography.monoS.weight(.bold))
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
                    .font(DS.Typography.bodyS.weight(.semibold))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircular)
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(DS.Typography.watchVital)
                    Text(data.heartRate > 0 ? "\(data.heartRate) bpm" : "-- bpm")
                        .font(DS.Typography.caption.weight(.medium))
                        .monospacedDigit()
                    Text(data.heartRateTrend.arrow)
                        .font(DS.Typography.monoS.weight(.bold))
                }
                HStack(spacing: 3) {
                    Image(systemName: "waveform.path.ecg")
                        .font(DS.Typography.watchVital)
                    Text(data.hrv > 0 ? "HRV \(data.hrv)ms" : "HRV --")
                        .font(DS.Typography.caption.weight(.medium))
                        .monospacedDigit()
                }
                HStack(spacing: 3) {
                    Image(systemName: "moon.fill")
                        .font(DS.Typography.watchVital)
                    Text(data.sleepHours > 0 ? formatSleepCompact(data.sleepHours) : "--")
                        .font(DS.Typography.caption.weight(.medium))
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
                .padding(.bottom, DS.Spacing.m)

            // Hero metric
            Text("\(data.score)")
                .font(DS.Typography.widgetSScore)
                .monospacedDigit()
                .kerning(-1.4)
                .foregroundStyle(WidgetColors.textPrimary)
                .padding(.bottom, DS.Spacing.xs)

            // Delta vs avg (status color)
            Text(deltaLine)
                .font(DS.Typography.caption)
                .foregroundStyle(statusColor)

            Spacer(minLength: 0)

            // Bottom mono line
            Text(footer)
                .font(DS.Typography.mono)
                .foregroundStyle(WidgetColors.textQuaternary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.card)
        .padding(.vertical, DS.Spacing.m)
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
                    .font(DS.Typography.mono)
                    .foregroundStyle(WidgetColors.textQuaternary)
            }

            // Hero + bar chart row
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(data.score)")
                        .font(DS.Typography.widgetSScore)
                        .monospacedDigit()
                        .kerning(-2)
                        .foregroundStyle(WidgetColors.textPrimary)
                    Text(deltaLine)
                        .font(DS.Typography.caption)
                        .foregroundStyle(statusColor)
                }
                .padding(.top, DS.Spacing.xs)

                // 7-day mini-bars + day labels (latest day filled solid, others muted)
                if !data.dailyScores.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        WidgetWeekBars(scores: data.dailyScores)
                            .frame(height: 52)
                        WidgetWeekLabels(scores: data.dailyScores)
                    }
                    .padding(.bottom, DS.Spacing.xs)
                }
            }
            .padding(.top, DS.Spacing.s)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.card)
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
                    .font(DS.Typography.mono)
                    .foregroundStyle(WidgetColors.textQuaternary)
            }

            // Hero + delta + 7-day bars side-by-side
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Readiness")
                        .widgetEyebrow(size: 10)
                    Text("\(data.score)")
                        .font(DS.Typography.widgetLScore)
                        .monospacedDigit()
                        .kerning(-2)
                        .foregroundStyle(WidgetColors.textPrimary)
                    Text(deltaLine)
                        .font(DS.Typography.caption)
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
                    .font(DS.Typography.bodyS)
                    .foregroundStyle(WidgetColors.textPrimary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.l)
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
                .font(DS.Typography.monoS.weight(.semibold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(WidgetColors.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(DS.Typography.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(DS.Typography.mono)
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
                    .font(DS.Typography.monoS.weight(.medium))
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
