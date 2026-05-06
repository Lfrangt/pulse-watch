import SwiftUI

/// 7-day readiness bar sparkline. Hairline bars, today highlighted.
/// Clinical pattern: data is decoration. No grid, no axes.
/// When historical data is sparse, renders placeholder ticks instead of one giant bar.
struct ReadinessSparkline: View {
    /// Today's score (always present, drawn as the highlighted last bar).
    let todayScore: Int
    /// Six prior days, oldest → most recent. Use nil for missing days.
    let priorScores: [Int?]

    private let height: CGFloat = 44
    private let barSpacing: CGFloat = 3
    private let totalDays = 7

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let totalSpacing = barSpacing * CGFloat(totalDays - 1)
                let barWidth = max((geo.size.width - totalSpacing) / CGFloat(totalDays), 2)
                let allScores = priorScores + [todayScore]
                let knownScores = allScores.compactMap { $0 }
                let maxScore = max(knownScores.max() ?? 100, 60)

                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(0..<totalDays, id: \.self) { index in
                        let isToday = index == totalDays - 1
                        let score = allScores[index]

                        if let score {
                            let normalized = CGFloat(score) / CGFloat(maxScore)
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(isToday ? PulseTheme.accent : PulseTheme.textTertiary.opacity(0.45))
                                .frame(width: barWidth,
                                       height: max(geo.size.height * normalized, 2))
                        } else {
                            // Placeholder tick — no data for this day yet
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(PulseTheme.border)
                                .frame(width: barWidth, height: 4)
                        }
                    }
                }
                .frame(height: geo.size.height, alignment: .bottom)
            }
            .frame(height: height)

            HStack(spacing: 0) {
                ForEach(weekLabels(), id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.textQuaternary)
                        .frame(maxWidth: .infinity)
                        .monospacedDigit()
                }
            }
        }
    }

    private func weekLabels() -> [String] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = .current
        fmt.dateFormat = "EEEEE"
        let today = cal.startOfDay(for: .now)
        return (0..<totalDays).reversed().compactMap { offset -> String? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return offset == 0 ? String(localized: "Today") : fmt.string(from: d)
        }
    }
}

#Preview("Full week") {
    ReadinessSparkline(todayScore: 78, priorScores: [58, 64, 71, 68, 75, 72])
        .padding()
        .background(PulseTheme.cardBackground)
        .pulseHairline()
        .padding()
        .background(PulseTheme.background)
}

#Preview("Sparse data — only today") {
    ReadinessSparkline(todayScore: 50, priorScores: [nil, nil, nil, nil, nil, nil])
        .padding()
        .background(PulseTheme.cardBackground)
        .pulseHairline()
        .padding()
        .background(PulseTheme.background)
}
