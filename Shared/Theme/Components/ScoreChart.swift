import SwiftUI

// P9 · ScoreChart — multi-day score trend (default 30d).
// Path stroke chartHeavy in ink, fill 0.05, dashed baseline at avg, terminal accent dot.
// Forbidden: grid, y-axis labels, legend, bar version.

struct ScoreChart: View {
    let data: [(day: Date, value: Int)]
    var height: CGFloat = 130
    var onScrub: ((Date, Int) -> Void)? = nil

    @State private var scrubX: CGFloat? = nil

    private var values: [Double] { data.map { Double($0.value) } }
    private var average: Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            GeometryReader { geo in
                if data.count < 2 {
                    emptyState(in: geo.size)
                } else {
                    chartBody(in: geo.size)
                }
            }
            .frame(height: height)

            footer
        }
    }

    private func chartBody(in size: CGSize) -> some View {
        let pts = points(in: size)
        return ZStack {
            // baseline (avg)
            let baselineY = yFor(value: average, in: size)
            Path { p in
                p.move(to: CGPoint(x: 0, y: baselineY))
                p.addLine(to: CGPoint(x: size.width, y: baselineY))
            }
            .stroke(DS.Color.lineSoft, style: .init(lineWidth: DS.Stroke.hairline, dash: [3, 3]))

            // fill
            fillPath(pts: pts, in: size).fill(DS.Color.ink.opacity(0.05))

            // line
            linePath(pts: pts).stroke(
                DS.Color.ink,
                style: .init(lineWidth: DS.Stroke.chartHeavy, lineCap: .round, lineJoin: .round)
            )

            // terminal dot
            if let last = pts.last {
                Circle()
                    .fill(DS.Color.accent)
                    .frame(width: DS.Spacing.s, height: DS.Spacing.s)
                    .position(last)
            }

            // scrub indicator
            if let scrubX, let nearest = nearestPoint(to: scrubX, points: pts) {
                Path { p in
                    p.move(to: CGPoint(x: nearest.x, y: 0))
                    p.addLine(to: CGPoint(x: nearest.x, y: size.height))
                }
                .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    scrubX = v.location.x
                    if let onScrub, let pt = nearestIndex(to: v.location.x, points: pts) {
                        onScrub(data[pt].day, data[pt].value)
                    }
                }
                .onEnded { _ in scrubX = nil }
        )
    }

    private func emptyState(in size: CGSize) -> some View {
        VStack(alignment: .center) {
            Spacer()
            MonoLabel(text: "Awaiting Data", size: .m, tone: .dim)
            Spacer()
        }
        .frame(width: size.width, height: size.height)
    }

    private var footer: some View {
        HStack {
            if let first = data.first {
                MonoLabel(text: dateString(first.day), size: .s, tone: .dim)
            }
            Spacer()
            if let last = data.last {
                MonoLabel(text: dateString(last.day), size: .s, tone: .dim)
            }
        }
    }

    // MARK: - Geometry

    private func yFor(value: Double, in size: CGSize) -> CGFloat {
        let lo = (values.min() ?? 0) - 4
        let hi = (values.max() ?? 100) + 4
        let span = max(hi - lo, 1)
        return size.height * CGFloat(1 - (value - lo) / span)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        return data.enumerated().map { i, item in
            let x = size.width * CGFloat(i) / CGFloat(data.count - 1)
            let y = yFor(value: Double(item.value), in: size)
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }

    private func fillPath(pts: [CGPoint], in size: CGSize) -> Path {
        var p = linePath(pts: pts)
        guard let first = pts.first, let last = pts.last else { return p }
        p.addLine(to: CGPoint(x: last.x, y: size.height))
        p.addLine(to: CGPoint(x: first.x, y: size.height))
        p.closeSubpath()
        return p
    }

    private func nearestIndex(to x: CGFloat, points: [CGPoint]) -> Int? {
        guard !points.isEmpty else { return nil }
        return points.enumerated().min(by: { abs($0.1.x - x) < abs($1.1.x - x) })?.0
    }

    private func nearestPoint(to x: CGFloat, points: [CGPoint]) -> CGPoint? {
        guard let i = nearestIndex(to: x, points: points) else { return nil }
        return points[i]
    }

    // MARK: - Format

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: d)
    }
}

#Preview {
    let demo: [(Date, Int)] = (0..<30).map { i in
        let d = Calendar.current.date(byAdding: .day, value: -29 + i, to: .now)!
        let v = 60 + Int(sin(Double(i) / 4) * 12) + (i % 5)
        return (d, v)
    }
    return Card {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                MonoLabel(text: "Score · 30 days", size: .m)
                Spacer()
                MonoLabel(text: "Avg 64 · σ 8.2", size: .s, tone: .dim)
            }
            ScoreChart(data: demo.map { (day: $0.0, value: $0.1) })
        }
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}
