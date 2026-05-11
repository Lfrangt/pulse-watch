import SwiftUI

// P12 · Insight — one-line action sentence. Verb-first, never a number.

struct Insight: View {
    let text: String
    var label: String? = nil
    var cta: String? = nil
    var onCTA: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            if let label {
                MonoLabel(text: label, size: .s, tone: .dim)
            }
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                Text(text)
                    .font(DS.Typography.bodyL)
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let cta, let onCTA {
                    Button(action: onCTA) {
                        Chip(text: cta, style: .accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DS.Spacing.l) {
        Insight(text: "Train hard.", label: "Today's coach")
        Insight(text: "Recover today — yesterday's session pushed you near the edge.", label: "Today's coach")
        Insight(text: "认真训练。", label: "今日教练")
        Insight(text: "Sleep more tonight.", label: "Today's coach", cta: "Set Bedtime", onCTA: {})
    }
    .padding(DS.Spacing.edge)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DS.Color.bg)
}
