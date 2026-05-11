import SwiftUI

// P3 · TrendArrow — 9×9pt direction indicator, polarity-aware coloring.

enum TrendDirection {
    case up, down, flat
}

enum Polarity {
    case higherIsBetter   // HRV, sleep
    case lowerIsBetter    // RHR, stress
    case contextual       // SpO₂ — caller supplies color
}

struct TrendArrow: View {
    let direction: TrendDirection
    var polarity: Polarity = .higherIsBetter
    var contextualColor: Color? = nil

    private static let dim: CGFloat = 9

    private var color: Color {
        switch (direction, polarity) {
        case (.flat, _):
            return DS.Color.inkDim
        case (_, .contextual):
            return contextualColor ?? DS.Color.inkDim
        case (.up, .higherIsBetter):
            return DS.Color.good
        case (.down, .higherIsBetter):
            return DS.Color.bad
        case (.up, .lowerIsBetter):
            return DS.Color.bad
        case (.down, .lowerIsBetter):
            return DS.Color.good
        }
    }

    var body: some View {
        Group {
            switch direction {
            case .up:
                Triangle(pointing: .up)
            case .down:
                Triangle(pointing: .down)
            case .flat:
                Rectangle()
                    .frame(width: Self.dim, height: DS.Stroke.chartLine)
            }
        }
        .foregroundStyle(color)
        .frame(width: Self.dim, height: Self.dim)
    }
}

private struct Triangle: Shape {
    enum Direction { case up, down }
    let pointing: Direction

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch pointing {
        case .up:
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        p.closeSubpath()
        return p
    }
}

#Preview {
    HStack(spacing: DS.Spacing.l) {
        VStack(spacing: DS.Spacing.s) {
            MonoLabel(text: "HRV ↑", size: .s)
            TrendArrow(direction: .up, polarity: .higherIsBetter)
        }
        VStack(spacing: DS.Spacing.s) {
            MonoLabel(text: "RHR ↑", size: .s)
            TrendArrow(direction: .up, polarity: .lowerIsBetter)
        }
        VStack(spacing: DS.Spacing.s) {
            MonoLabel(text: "Flat", size: .s)
            TrendArrow(direction: .flat)
        }
        VStack(spacing: DS.Spacing.s) {
            MonoLabel(text: "SpO2", size: .s)
            TrendArrow(direction: .down, polarity: .contextual, contextualColor: DS.Color.warn)
        }
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}
