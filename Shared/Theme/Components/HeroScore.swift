import SwiftUI

// P11 · HeroScore — Today screen hero (score + status + insight + 30d sparkline).

struct HeroScore: View {
    let score: Int?
    let status: String
    let insightText: String?
    var insightLabel: String? = nil
    var trendData: [Double] = []
    var trendLabel: String = "30d Trend"
    var dateLabel: String
    /// Optional baseline delta — e.g. "+6 vs 7d" — rendered as a small mono
    /// label opposite the dateLabel. Preserves the v1 hero's "vs 7-day avg"
    /// affordance under R11.
    var baselineDelta: (text: String, tone: MonoTone)? = nil

    var body: some View {
        VStack(alignment: .center, spacing: DS.Spacing.l) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: dateLabel, size: .m)
                Spacer()
                if let baselineDelta {
                    MonoLabel(text: baselineDelta.text, size: .s, tone: baselineDelta.tone)
                }
            }
            ScoreDial(score: score, status: status)
            if let insightText {
                Insight(text: insightText, label: insightLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !trendData.isEmpty {
                HStack(alignment: .center, spacing: DS.Spacing.s) {
                    MonoLabel(text: trendLabel, size: .s, tone: .dim)
                    Sparkline(data: trendData, width: 140, height: 24, color: DS.Color.inkMid)
                    Spacer()
                }
            }
        }
        .padding(.top, DS.Spacing.l)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack {
        HeroScore(
            score: 78,
            status: "Good",
            insightText: "Train hard. Recovery is in your favor.",
            insightLabel: "Today's coach",
            trendData: [62, 58, 71, 65, 73, 78, 76, 71, 73, 80, 78, 82, 76, 72, 74, 78],
            dateLabel: "Today · May 5"
        )
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}

#Preview("no data") {
    HeroScore(
        score: nil,
        status: "Awaiting Data",
        insightText: nil,
        dateLabel: "Today · May 5"
    )
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
    .preferredColorScheme(.dark)
}
