import SwiftUI

// P10 · SleepBand — last night sleep stage timeline.
// 4 lanes (top-down): awake / REM / core / deep.
// Stage colors: deep=ink · core=inkMid · rem=accent · awake=inkDim.

enum SleepStageKind {
    case awake, rem, core, deep

    var lane: Int {
        switch self {
        case .awake: return 0
        case .rem:   return 1
        case .core:  return 2
        case .deep:  return 3
        }
    }

    var color: Color {
        switch self {
        case .deep:  return DS.Color.ink
        case .core:  return DS.Color.inkMid
        case .rem:   return DS.Color.accent
        case .awake: return DS.Color.inkDim
        }
    }

    var label: String {
        switch self {
        case .awake: return "AWAKE"
        case .rem:   return "REM"
        case .core:  return "CORE"
        case .deep:  return "DEEP"
        }
    }
}

struct SleepStage {
    let stage: SleepStageKind
    let mins: Int
}

struct SleepBand: View {
    let stages: [SleepStage]
    var height: CGFloat = 60

    private var totalMins: Int { stages.reduce(0) { $0 + $1.mins } }

    var body: some View {
        if stages.isEmpty || totalMins == 0 {
            HStack {
                MonoLabel(text: "Awaiting Data", size: .m, tone: .dim)
                Spacer()
            }
            .frame(height: height)
        } else {
            GeometryReader { geo in
                let laneH = (geo.size.height - 6) / 4
                ZStack(alignment: .topLeading) {
                    ForEach(0..<4, id: \.self) { lane in
                        Rectangle()
                            .fill(DS.Color.lineSoft)
                            .frame(height: DS.Stroke.hairline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .offset(y: CGFloat(lane) * (laneH + 2) + laneH / 2)
                    }
                    let segs = computedSegments(width: geo.size.width)
                    ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                        RoundedRectangle(cornerRadius: DS.Radius.chipIcon)
                            .fill(seg.kind.color)
                            .frame(width: seg.width, height: laneH)
                            .offset(x: seg.x, y: CGFloat(seg.kind.lane) * (laneH + 2))
                    }
                }
            }
            .frame(height: height)
        }
    }

    private struct Seg {
        let kind: SleepStageKind
        let x: CGFloat
        let width: CGFloat
    }

    private func computedSegments(width: CGFloat) -> [Seg] {
        guard totalMins > 0 else { return [] }
        var x: CGFloat = 0
        return stages.map { stage in
            let w = width * CGFloat(stage.mins) / CGFloat(totalMins)
            let seg = Seg(kind: stage.stage, x: x, width: w)
            x += w
            return seg
        }
    }
}

#Preview {
    Card {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                MonoLabel(text: "Last Night", size: .m)
                Spacer()
                MonoLabel(text: "7H 52M", size: .s, tone: .dim)
            }
            SleepBand(stages: [
                .init(stage: .awake, mins: 8),
                .init(stage: .core,  mins: 80),
                .init(stage: .rem,   mins: 65),
                .init(stage: .deep,  mins: 90),
                .init(stage: .core,  mins: 95),
                .init(stage: .rem,   mins: 35),
                .init(stage: .awake, mins: 4),
                .init(stage: .core,  mins: 95)
            ])
        }
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}

#Preview("empty") {
    Card { SleepBand(stages: []) }
        .padding(DS.Spacing.edge)
        .background(DS.Color.bg)
        .preferredColorScheme(.dark)
}
