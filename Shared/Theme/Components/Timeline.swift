import SwiftUI

// P14 · Timeline — vertical event flow (recovery / anomaly).
// NOTE: SwiftUI/WidgetKit own a top-level `Timeline` and `TimelineEntry`,
// so this primitive ships as `EventTimeline` + `EventEntry` to avoid
// collision in the watchOS complication target. The design spec name
// remains "Timeline (P14)" — only the Swift symbol differs.
// Row: 8pt impact dot · title (Body) above · detail (BodyS inkMid) below · time (Mono inkDim) at right.
// Forbidden: icons on rows, card-per-row, avatars.

enum TimelineImpact {
    case positive, negative, neutral

    var color: Color {
        switch self {
        case .positive: return DS.Color.good
        case .negative: return DS.Color.bad
        case .neutral:  return DS.Color.inkDim
        }
    }
}

struct EventEntry: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let detail: String?
    let impact: TimelineImpact
    var isCurrent: Bool = false
}

struct EventTimeline: View {
    let events: [EventEntry]

    var body: some View {
        if events.isEmpty {
            HStack {
                MonoLabel(text: "Awaiting Data", size: .m, tone: .dim)
                Spacer()
            }
            .padding(.vertical, DS.Spacing.s)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    row(event)
                    if index < events.count - 1 {
                        Rectangle()
                            .fill(DS.Color.lineSoft)
                            .frame(height: DS.Stroke.hairline)
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private func row(_ event: EventEntry) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            Circle()
                .fill(event.impact.color)
                .frame(width: DS.Spacing.s, height: DS.Spacing.s)
                .padding(.top, 6)
                .overlay(
                    Group {
                        if event.isCurrent {
                            Circle()
                                .stroke(event.impact.color.opacity(0.35), lineWidth: 2)
                                .frame(width: DS.Spacing.card, height: DS.Spacing.card)
                                .padding(.top, 6)
                        }
                    }
                )

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(event.title)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.ink)
                if let detail = event.detail {
                    Text(detail)
                        .font(DS.Typography.bodyS)
                        .foregroundStyle(DS.Color.inkMid)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: DS.Spacing.s)

            MonoLabel(text: event.time, size: .s, tone: .dim)
                .padding(.top, 2)
        }
        .padding(.vertical, DS.Spacing.s)
    }
}

#Preview {
    Card {
        EventTimeline(events: [
            .init(time: "07:14", title: "Wake", detail: "RHR 54 — well rested.", impact: .positive),
            .init(time: "12:30", title: "Lunch HR spike", detail: "Brief 96 bpm — likely caffeine.", impact: .neutral, isCurrent: true),
            .init(time: "16:02", title: "Stress event", detail: "HRV dipped to 32 ms — meeting?", impact: .negative),
            .init(time: "19:00", title: "Wind-down", detail: "Steady decline. On track for sleep.", impact: .positive)
        ])
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}

#Preview("empty") {
    Card {
        EventTimeline(events: [])
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}
