import SwiftUI
import Charts

// MARK: - WeeklyReadinessChart
// 7-day readiness line chart — mirrors Today.jsx WeeklyThumb / LineChart.
// Top row: "7-Day Readiness" eyebrow + mono "avg N" right-aligned.
// Below: 80pt line chart with subtle area fill, dashed center grid line, point only on today.
// Uses SwiftUI Charts framework (iOS 17+).

@available(iOS 16.0, *)
struct WeeklyReadinessChart: View {
    /// 7 values, oldest first, today last. nil = missing day.
    let scores: [Int?]

    /// Domain — fixed so the chart shape stays comparable day-to-day.
    private let yDomain: ClosedRange<Double> = 40...100

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("7-Day Readiness")
                    .pulseEyebrow()
                Spacer()
                Text(avgLabel)
                    .font(PulseTheme.monoFont)
                    .foregroundStyle(PulseTheme.textSecondary)
            }

            chart
                .frame(height: 80)
        }
        .pulseCard()
    }

    // MARK: - Chart

    private var chart: some View {
        // Build typed data points for Charts. Skip nil entries for line/area.
        let points: [DayPoint] = scores.enumerated().compactMap { idx, score in
            guard let score else { return nil }
            return DayPoint(index: idx, value: Double(score))
        }
        let lastIndex = scores.count - 1
        let todayPoint = points.first { $0.index == lastIndex }

        return Chart {
            // Center dashed grid line — drawn as a RuleMark for the axis-free chart.
            RuleMark(y: .value("Mid", (yDomain.lowerBound + yDomain.upperBound) / 2))
                .foregroundStyle(PulseTheme.border)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))

            ForEach(points) { p in
                AreaMark(
                    x: .value("Day", p.index),
                    y: .value("Score", p.value)
                )
                .foregroundStyle(PulseTheme.textPrimary.opacity(0.06))
                .interpolationMethod(.linear)

                LineMark(
                    x: .value("Day", p.index),
                    y: .value("Score", p.value)
                )
                .foregroundStyle(PulseTheme.textPrimary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            if let todayPoint {
                PointMark(
                    x: .value("Day", todayPoint.index),
                    y: .value("Score", todayPoint.value)
                )
                .symbolSize(24)
                .foregroundStyle(PulseTheme.textPrimary)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: 0...Double(max(scores.count - 1, 1)))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.padding(.horizontal, 2)
        }
    }

    // MARK: - Helpers

    private var avgLabel: String {
        let valid = scores.compactMap { $0 }
        guard !valid.isEmpty else { return "avg —" }
        let avg = Int((Double(valid.reduce(0, +)) / Double(valid.count)).rounded())
        return "avg \(avg)"
    }
}

// MARK: - DayPoint (Identifiable for ForEach in Chart)

private struct DayPoint: Identifiable {
    let index: Int
    let value: Double
    var id: Int { index }
}

// MARK: - Preview

@available(iOS 16.0, *)
#Preview("Weekly — full week") {
    WeeklyReadinessChart(scores: [58, 64, 71, 68, 75, 72, 78])
        .padding()
        .background(PulseTheme.background)
}

@available(iOS 16.0, *)
#Preview("Weekly — partial") {
    WeeklyReadinessChart(scores: [nil, 64, 71, nil, 75, 72, 78])
        .padding()
        .background(PulseTheme.background)
}

@available(iOS 16.0, *)
#Preview("Weekly — empty") {
    WeeklyReadinessChart(scores: [nil, nil, nil, nil, nil, nil, nil])
        .padding()
        .background(PulseTheme.background)
}
