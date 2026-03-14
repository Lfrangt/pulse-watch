import WidgetKit
import SwiftUI

// MARK: - Shared Data Key

enum PulseSharedData {
    static let suiteName = "group.com.abundra.pulse"
    static let scoreKey = "pulse.score"
    static let headlineKey = "pulse.headline"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

// MARK: - Timeline Entry

struct PulseEntry: TimelineEntry {
    let date: Date
    let score: Int
    let headline: String
}

// MARK: - Timeline Provider

struct PulseComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, score: 72, headline: "状态良好")
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
        let headline = defaults?.string(forKey: PulseSharedData.headlineKey) ?? "等待同步"
        return PulseEntry(date: .now, score: score > 0 ? score : 72, headline: headline)
    }
}

// MARK: - Complication Views

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
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeGradient)
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

struct PulseComplicationRectangular: View {
    let entry: PulseEntry

    var body: some View {
        HStack(spacing: 8) {
            Gauge(value: Double(entry.score), in: 0...100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeColor)
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pulse")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .widgetAccentable()
                Text(entry.headline)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var gaugeColor: Color {
        switch entry.score {
        case 0..<40: return Color(hex: "C75C5C")
        case 40..<70: return Color(hex: "D4A056")
        default: return Color(hex: "7FB069")
        }
    }
}

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
        .description("今日状态评分")
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
