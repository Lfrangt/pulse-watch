import SwiftUI
import Charts

// MARK: - TrendCard
// Mirrors Trends.jsx TrendCard exactly:
//   ┌──────────────────────────────────────┐
//   │ LABEL (eyebrow)        delta (mono)  │
//   │ 72 unit                              │  ← 30pt metric + unit
//   │ ─── line chart 80pt height ───       │
//   └──────────────────────────────────────┘
//
// Visual rules (from JSX MiniTrend):
//  • 80pt height chart, no axes, three guide lines (top/middle dashed/bottom)
//  • AreaMark fill at 0.05 opacity, LineMark 1.5pt, PointMark only on last point
//  • Empty state: dashed grid skeleton
//  • Delta colors: positive+good=statusGood, negative+good=textTertiary, anything bad=statusPoor
struct TrendCard: View {
    let label: String
    let metric: String
    let unit: String
    let delta: String
    /// True when the delta direction means "improving health" (positive delta on score/HRV good,
    /// negative delta on resting HR good, etc.). Used to choose color.
    let deltaIsGood: Bool
    /// Raw values for the chart line. Empty = render empty-state skeleton.
    let scores: [Double]

    private let chartHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: eyebrow LEFT, mono delta RIGHT
            HStack(alignment: .center) {
                Text(label)
                    .pulseEyebrow()
                Spacer()
                Text(delta)
                    .font(PulseTheme.monoFont)
                    .foregroundStyle(deltaColor)
            }

            // Big metric + unit (baseline-aligned)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(metric)
                    .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(unit)
                    .font(PulseTheme.unitFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .padding(.top, 8)

            // Mini line chart
            chartSection
                .frame(height: chartHeight)
                .padding(.top, 16)
        }
        .pulseCard(padding: 20)
    }

    // MARK: - Delta color

    private var deltaColor: Color {
        // Match JSX exactly:
        // deltaGood && delta starts with "+" → good (green)
        // deltaGood && delta starts with "−" → tertiary (e.g. resting HR going down is good but neutral-toned)
        // !deltaGood (regression) → poor
        if !deltaIsGood {
            return PulseTheme.statusPoor
        }
        if delta.hasPrefix("+") {
            return PulseTheme.statusGood
        }
        // good direction but value moved in raw negative form (e.g. "−1 bpm" for resting HR)
        return PulseTheme.textTertiary
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        if scores.isEmpty {
            emptyChart
        } else {
            populatedChart
        }
    }

    private var populatedChart: some View {
        let indexed = scores.enumerated().map { (idx, val) in
            (idx: idx, value: val)
        }
        let lastIdx = indexed.count - 1
        let lo = scores.min() ?? 0
        let hi = scores.max() ?? 1
        let pad = max((hi - lo) * 0.08, 0.5)

        return Chart {
            ForEach(indexed, id: \.idx) { item in
                AreaMark(
                    x: .value("Idx", item.idx),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(PulseTheme.textPrimary.opacity(0.05))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Idx", item.idx),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(PulseTheme.textPrimary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                if item.idx == lastIdx {
                    PointMark(
                        x: .value("Idx", item.idx),
                        y: .value("Value", item.value)
                    )
                    .symbolSize(30)
                    .foregroundStyle(PulseTheme.textPrimary)
                }
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot
                .background(gridBackground)
        }
    }

    /// Three horizontal guide lines (top, middle dashed, bottom) — matches MiniTrend SVG.
    private var gridBackground: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(PulseTheme.divider)
                    .frame(width: w, height: 1)
                    .offset(y: 0.5)

                // Middle dashed line at 50%
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 2))
                    p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(PulseTheme.divider, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

                Rectangle()
                    .fill(PulseTheme.divider)
                    .frame(width: w, height: 1)
                    .offset(y: h - 0.5)
            }
        }
    }

    private var emptyChart: some View {
        // Dashed grid skeleton with no line
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(PulseTheme.divider)
                    .frame(width: w, height: 1)
                    .offset(y: 0.5)

                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 2))
                    p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(PulseTheme.divider, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

                Rectangle()
                    .fill(PulseTheme.divider)
                    .frame(width: w, height: 1)
                    .offset(y: h - 0.5)

                Text("No data yet")
                    .font(.system(size: 11))
                    .foregroundStyle(PulseTheme.textQuaternary)
                    .frame(width: w, height: h)
            }
        }
    }
}

// MARK: - Preview

#Preview("Populated") {
    VStack(spacing: 12) {
        TrendCard(
            label: "Readiness",
            metric: "72",
            unit: "avg",
            delta: "+3 vs prev 30d",
            deltaIsGood: true,
            scores: [60, 64, 68, 67, 72, 70, 75, 73, 76, 74, 78, 71, 72, 74, 76, 78, 75, 77, 79, 76, 78, 80, 78, 76, 74, 77, 79, 81, 78, 80]
        )
        TrendCard(
            label: "Resting HR",
            metric: "53",
            unit: "bpm avg",
            delta: "−1 vs prev 30d",
            deltaIsGood: true,
            scores: [60, 58, 56, 57, 55, 54, 53, 52, 53, 52]
        )
        TrendCard(
            label: "HRV",
            metric: "—",
            unit: "ms avg",
            delta: "—",
            deltaIsGood: true,
            scores: []
        )
    }
    .padding()
    .background(PulseTheme.background)
}
