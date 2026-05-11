import SwiftUI

// P4 · Sparkline — tiny inline trend line. Static (no animated draw).
// Forbidden: grid lines, axis labels, multi-color line.

struct Sparkline: View {
    let data: [Double]
    var width: CGFloat = 120
    var height: CGFloat = 32
    var color: Color = DS.Color.ink
    var fill: Bool = false

    var body: some View {
        GeometryReader { geo in
            let validData = data.compactMap { $0.isFinite ? $0 : nil }
            if validData.count < 2 {
                emptyView
            } else {
                let points = computePoints(in: geo.size, values: validData)
                ZStack {
                    if fill {
                        fillPath(points: points, in: geo.size)
                            .fill(color.opacity(0.15))
                    }
                    linePath(points: points)
                        .stroke(color, style: .init(
                            lineWidth: DS.Stroke.chartLine,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                    if let last = points.last {
                        Circle()
                            .fill(color)
                            .frame(width: DS.Spacing.xs, height: DS.Spacing.xs)
                            .position(last)
                    }
                }
            }
        }
        .frame(width: width, height: height)
    }

    private var emptyView: some View {
        Rectangle()
            .frame(height: DS.Stroke.hairline)
            .foregroundStyle(DS.Color.lineSoft)
            .frame(maxHeight: .infinity)
    }

    private func computePoints(in size: CGSize, values: [Double]) -> [CGPoint] {
        guard let lo = values.min(), let hi = values.max(), hi > lo else {
            return values.enumerated().map { i, _ in
                CGPoint(
                    x: size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1)),
                    y: size.height / 2
                )
            }
        }
        return values.enumerated().map { i, v in
            let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
            let y = size.height * CGFloat(1 - (v - lo) / (hi - lo))
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for pt in points.dropFirst() { p.addLine(to: pt) }
        return p
    }

    private func fillPath(points: [CGPoint], in size: CGSize) -> Path {
        var p = linePath(points: points)
        guard let last = points.last, let first = points.first else { return p }
        p.addLine(to: CGPoint(x: last.x, y: size.height))
        p.addLine(to: CGPoint(x: first.x, y: size.height))
        p.closeSubpath()
        return p
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DS.Spacing.l) {
        Sparkline(data: [62, 58, 71, 65, 73, 78, 76])
        Sparkline(data: [62, 58, 71, 65, 73, 78, 76], color: DS.Color.accent, fill: true)
        Sparkline(data: [], color: DS.Color.inkDim) // empty
        Sparkline(data: [50])                        // single point — fallback
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}
