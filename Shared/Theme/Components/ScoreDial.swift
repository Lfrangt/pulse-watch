import SwiftUI

// P7 · ScoreDial — 0-100 score on 240pt dial with tick marks.
// 60 ticks (12 major / 48 minor) + accent arc + center number/status.
// Animation: respects Reduce Motion via DS.Motion.respecting.

struct ScoreDial: View {
    let score: Int?
    let status: String
    var size: CGFloat = 240
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedScore: Double = 0

    private var displayScore: Int { animated ? Int(animatedScore.rounded()) : (score ?? 0) }
    private var arcFraction: Double {
        guard let score else { return 0 }
        if animated { return animatedScore / 100 }
        return Double(score) / 100
    }

    var body: some View {
        ZStack {
            ticks
            if score != nil {
                arc
            }
            center
        }
        .frame(width: size, height: size)
        .onAppear { syncToScore(initial: true) }
        .onChange(of: score) { _, _ in syncToScore(initial: false) }
    }

    private var ticks: some View {
        ZStack {
            ForEach(0..<60, id: \.self) { i in
                let isMajor = i % 5 == 0
                Rectangle()
                    .fill(isMajor ? DS.Color.line : DS.Color.lineSoft)
                    .frame(
                        width: isMajor ? DS.Stroke.tickMajor : DS.Stroke.tickMinor,
                        height: isMajor ? size * 0.045 : size * 0.025
                    )
                    .offset(y: -size / 2 + (isMajor ? size * 0.045 : size * 0.025) / 2 + 2)
                    .rotationEffect(.degrees(Double(i) * 6))
            }
        }
    }

    private var arc: some View {
        Circle()
            .trim(from: 0, to: max(0, min(1, arcFraction)))
            .stroke(
                DS.Color.accent,
                style: .init(lineWidth: DS.Stroke.chartHeavy, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: size * 0.86, height: size * 0.86)
    }

    private var center: some View {
        VStack(spacing: DS.Spacing.xs) {
            if let score, score > 0 {
                BigNum(value: "\(displayScore)", size: .display1)
            } else {
                BigNum(value: "—", size: .display1, color: DS.Color.inkDim)
            }
            MonoLabel(text: status, size: .m, tone: .dim)
        }
    }

    private func syncToScore(initial: Bool) {
        guard animated else {
            animatedScore = Double(score ?? 0)
            return
        }
        let target = Double(score ?? 0)
        if initial {
            animatedScore = 0
            withAnimation(DS.Motion.respecting(DS.Motion.scoreChange, reduce: reduceMotion)) {
                animatedScore = target
            }
        } else {
            withAnimation(DS.Motion.respecting(DS.Motion.scoreChange, reduce: reduceMotion)) {
                animatedScore = target
            }
        }
    }
}

#Preview("default · 78") {
    ScoreDial(score: 78, status: "Good")
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(DS.Color.bg)
}

#Preview("no data") {
    ScoreDial(score: nil, status: "Awaiting Data")
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(DS.Color.bg)
        .preferredColorScheme(.dark)
}

#Preview("zh · 92") {
    ScoreDial(score: 92, status: "巅峰")
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(DS.Color.bg)
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
