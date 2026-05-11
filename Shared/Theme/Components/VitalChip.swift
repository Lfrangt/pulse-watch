import SwiftUI

// P8 · VitalChip — compact vital readout, 2-column grid cell.
// Composition: top MonoLabel · middle BigNum.title1 + unit · right TrendArrow · bottom sub.

struct VitalChip: View {
    let label: String
    let value: String
    var unit: String? = nil
    var trend: TrendDirection = .flat
    var polarity: Polarity = .higherIsBetter
    var trendColor: Color? = nil
    var sub: String? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        let content = Card(padding: DS.Spacing.card) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                MonoLabel(text: label, size: .s, tone: .default)

                HStack(alignment: .firstTextBaseline) {
                    BigNum(value: value, unit: unit, size: .title1)
                    Spacer(minLength: DS.Spacing.xs)
                    TrendArrow(direction: trend, polarity: polarity, contextualColor: trendColor)
                        .padding(.bottom, 2)
                }

                if let sub {
                    Text(sub)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.inkDim)
                        .lineLimit(1)
                }
            }
        }

        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

#Preview {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: DS.Spacing.s),
        GridItem(.flexible(), spacing: DS.Spacing.s)
    ], spacing: DS.Spacing.s) {
        VitalChip(label: "HRV", value: "58", unit: "ms", trend: .up, polarity: .higherIsBetter, sub: "+6 vs 30d")
        VitalChip(label: "RHR", value: "54", unit: "bpm", trend: .down, polarity: .lowerIsBetter, sub: "−2 vs 30d")
        VitalChip(label: "Sleep", value: "7.5", unit: "h", trend: .up, polarity: .higherIsBetter)
        VitalChip(label: "SpO2", value: "97", unit: "%", trend: .flat, polarity: .contextual, trendColor: DS.Color.inkDim)
        VitalChip(label: "Stress", value: "—", trend: .flat, polarity: .lowerIsBetter)
        VitalChip(label: "Health Age", value: "27", unit: "y", trend: .down, polarity: .lowerIsBetter, sub: "−2 vs actual")
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}
