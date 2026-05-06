import SwiftUI

// P2 · BigNum — measured number with optional unit. Tabular figures, light weight.

enum BigNumSize {
    case display1, display2, display3, title1

    var font: Font {
        switch self {
        case .display1: return DS.Typography.display1
        case .display2: return DS.Typography.display2
        case .display3: return DS.Typography.display3
        case .title1:   return DS.Typography.title1
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display1: return DS.Tracking.display1
        case .display2: return DS.Tracking.display2
        case .display3: return DS.Tracking.display3
        case .title1:   return DS.Tracking.title1
        }
    }

    /// Unit font sized at ~18-22% of number per DESIGN §3.3.
    var unitFont: Font {
        switch self {
        case .display1, .display2: return DS.Typography.monoL
        case .display3, .title1:   return DS.Typography.mono
        }
    }
}

enum BigNumLayout {
    case inline   // number + unit horizontal
    case stacked  // number with mono unit below
}

struct BigNum: View {
    let value: String
    var unit: String? = nil
    var size: BigNumSize = .display3
    var color: Color = DS.Color.ink
    var layout: BigNumLayout = .inline

    var body: some View {
        switch layout {
        case .inline:
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                numberView
                if let unit {
                    Text(unit)
                        .font(size.unitFont)
                        .tracking(DS.Tracking.mono)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Color.inkMid)
                }
            }
        case .stacked:
            VStack(alignment: .trailing, spacing: 0) {
                numberView
                if let unit {
                    Text(unit)
                        .font(size.unitFont)
                        .tracking(DS.Tracking.mono)
                        .textCase(.uppercase)
                        .foregroundStyle(DS.Color.inkMid)
                }
            }
        }
    }

    private var numberView: some View {
        Text(value)
            .font(size.font)
            .tracking(size.tracking)
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

#Preview("display1 · score") {
    VStack(spacing: DS.Spacing.l) {
        BigNum(value: "78", size: .display1)
        BigNum(value: "—", size: .display1, color: DS.Color.inkDim)
    }
    .padding(DS.Spacing.edge)
    .frame(maxWidth: .infinity)
    .background(DS.Color.bg)
}

#Preview("vital scale") {
    VStack(alignment: .leading, spacing: DS.Spacing.l) {
        BigNum(value: "0:42:18", size: .display2)
        BigNum(value: "58", unit: "ms", size: .display3)
        BigNum(value: "8.5", unit: "h", size: .title1)
        BigNum(value: "—", unit: "bpm", size: .title1, color: DS.Color.inkDim)
    }
    .padding(DS.Spacing.edge)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DS.Color.bg)
}
