import SwiftUI

// P6 · Card — information container. bgElev / bgSunk + radius.card + hairline border.
// Forbidden: drop shadows, inner gradients, margin.

struct Card<Content: View>: View {
    var padding: CGFloat = DS.Spacing.l
    var sunk: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(sunk ? DS.Color.bgSunk : DS.Color.bgElev)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
            )
    }
}

#Preview {
    VStack(spacing: DS.Spacing.s) {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                MonoLabel(text: "Score · 30 days", size: .m)
                BigNum(value: "78", size: .display3)
                MonoLabel(text: "Avg 74 · σ 8.2", size: .s, tone: .dim)
            }
        }
        Card(sunk: true) {
            MonoLabel(text: "Sunk surface", size: .m, tone: .dim)
        }
        Card(padding: DS.Spacing.card) {
            MonoLabel(text: "Tight padding", size: .m)
        }
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}
