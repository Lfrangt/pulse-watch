import SwiftUI

/// 7-day readiness bar sparkline. Hairline bars, today highlighted.
/// Clinical pattern: data is decoration. No grid, no axes, no labels.
struct ReadinessSparkline: View {
    let scores: [Int]

    private let height: CGFloat = 44
    private let barSpacing: CGFloat = 3

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let count = max(scores.count, 1)
                let totalSpacing = barSpacing * CGFloat(max(count - 1, 0))
                let barWidth = max((geo.size.width - totalSpacing) / CGFloat(count), 2)
                let maxScore = max(scores.max() ?? 100, 60)

                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                        let normalized = CGFloat(score) / CGFloat(maxScore)
                        let isToday = index == scores.count - 1
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(isToday ? PulseTheme.textPrimary : PulseTheme.textTertiary.opacity(0.5))
                            .frame(width: barWidth, height: max(geo.size.height * normalized, 2))
                    }
                }
                .frame(height: geo.size.height, alignment: .bottom)
            }
            .frame(height: height)

            HStack(spacing: 0) {
                ForEach(weekLabels(count: scores.count), id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.textQuaternary)
                        .frame(maxWidth: .infinity)
                        .monospacedDigit()
                }
            }
        }
    }

    private func weekLabels(count: Int) -> [String] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = .current
        fmt.dateFormat = "EEEEE"
        let today = cal.startOfDay(for: .now)
        return (0..<count).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return offset == 0 ? String(localized: "Today") : fmt.string(from: d)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ReadinessSparkline(scores: [58, 64, 71, 68, 75, 72, 78])
            .padding()
            .background(PulseTheme.cardBackground)
            .pulseHairline()
    }
    .padding()
    .background(PulseTheme.background)
}
