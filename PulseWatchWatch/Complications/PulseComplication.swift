import WidgetKit
import SwiftUI

struct PulseEntry: TimelineEntry {
    let date: Date
    let score: Int
    let headline: String
}

struct PulseComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, score: 72, headline: "状态良好")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        completion(PulseEntry(date: .now, score: 72, headline: "状态良好"))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        // Refresh every 30 minutes
        let entry = PulseEntry(date: .now, score: 72, headline: "状态良好")
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
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
            .tint(gaugeColor)
        }
    }
    
    private var gaugeColor: Color {
        switch entry.score {
        case 0..<40: return .red
        case 40..<70: return .orange
        default: return .green
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
        case 0..<40: return .red
        case 40..<70: return .orange
        default: return .green
        }
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
            PulseComplicationCircular(entry: entry)
        }
        .configurationDisplayName("Pulse")
        .description("今日状态评分")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
