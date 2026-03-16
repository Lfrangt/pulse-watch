import WidgetKit
import SwiftUI

// MARK: - Shared Data Key

enum PulseSharedData {
    static let suiteName = "group.com.abundra.pulse"
    static let scoreKey = "pulse.score"
    static let headlineKey = "pulse.headline"
    static let heartRateKey = "pulse.heartRate"
    static let stepsKey = "pulse.steps"
    static let hrvKey = "pulse.hrv"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

// MARK: - Timeline Entry

struct PulseEntry: TimelineEntry {
    let date: Date
    let score: Int
    let headline: String
    let heartRate: Int
    let steps: Int
}

// MARK: - Timeline Provider

struct PulseComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, score: 72, headline: "Good", heartRate: 68, steps: 6500)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> PulseEntry {
        let defaults = PulseSharedData.defaults
        let score = defaults?.integer(forKey: PulseSharedData.scoreKey) ?? 0
        let headline = defaults?.string(forKey: PulseSharedData.headlineKey) ?? String(localized: "Waiting to sync")
        let heartRate = defaults?.integer(forKey: PulseSharedData.heartRateKey) ?? 0
        let steps = defaults?.integer(forKey: PulseSharedData.stepsKey) ?? 0
        return PulseEntry(
            date: .now,
            score: score > 0 ? score : 72,
            headline: headline,
            heartRate: heartRate > 0 ? heartRate : 68,
            steps: steps
        )
    }
}

// MARK: - Circular Complication — 圆形仪表盘

struct PulseComplicationCircular: View {
    let entry: PulseEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Gauge(value: Double(entry.score), in: 0...100) {
                Text("P")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            } currentValueLabel: {
                Text("\(entry.score)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeGradient)
        }
        .widgetURL(URL(string: "pulse://summary"))
    }

    private var scoreColor: Color {
        switch entry.score {
        case 0..<40: return Color(hex: "C75C5C")
        case 40..<70: return Color(hex: "D4A056")
        default: return Color(hex: "7FB069")
        }
    }

    private var gaugeGradient: Gradient {
        switch entry.score {
        case 0..<40: return Gradient(colors: [Color(hex: "C75C5C"), Color(hex: "A04040")])
        case 40..<70: return Gradient(colors: [Color(hex: "D4A056"), Color(hex: "B88A40")])
        default: return Gradient(colors: [Color(hex: "7FB069"), Color(hex: "5A9044")])
        }
    }
}

// MARK: - Rectangular Complication — 矩形卡片

struct PulseComplicationRectangular: View {
    let entry: PulseEntry

    var body: some View {
        HStack(spacing: 8) {
            // 左侧：圆形仪表
            Gauge(value: Double(entry.score), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text("\(entry.score)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeColor)
            .frame(width: 40)

            // 右侧：文字摘要
            VStack(alignment: .leading, spacing: 2) {
                Text("Pulse · \(entry.headline)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .widgetAccentable()
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // 心率
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color(hex: "C75C5C"))
                        Text("\(entry.heartRate)")
                            .font(.system(size: 10, design: .rounded))
                    }

                    // 步数
                    HStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 8))
                            .foregroundStyle(Color(hex: "7FB069"))
                        Text(formatSteps(entry.steps))
                            .font(.system(size: 10, design: .rounded))
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "pulse://summary"))
    }

    private var gaugeColor: Color {
        switch entry.score {
        case 0..<40: return Color(hex: "C75C5C")
        case 40..<70: return Color(hex: "D4A056")
        default: return Color(hex: "7FB069")
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return steps > 0 ? "\(steps)" : "--"
    }
}

// MARK: - Inline Complication

struct PulseComplicationInline: View {
    let entry: PulseEntry

    var body: some View {
        Text("Pulse \(entry.score) · \(entry.headline)")
    }
}

// MARK: - Widget Bundle

@main
struct PulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        PulseComplicationWidget()
    }
}

struct PulseComplicationWidget: Widget {
    let kind = "PulseComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseComplicationProvider()) { entry in
            PulseComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Pulse")
        .description("Today's Score · Tap for details")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct PulseComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PulseEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            PulseComplicationRectangular(entry: entry)
        case .accessoryInline:
            PulseComplicationInline(entry: entry)
        default:
            PulseComplicationCircular(entry: entry)
        }
    }
}

