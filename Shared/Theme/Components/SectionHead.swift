import SwiftUI

// P5 · SectionHead — editorial section divider with mono number prefix.
// Numbering restarts from "01" per screen.

struct SectionHead: View {
    let num: String
    let title: String
    var sub: String? = nil
    var action: String? = nil
    var actionColor: Color = DS.Color.accent
    var onAction: (() -> Void)? = nil
    var chinese: Bool? = nil

    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        if let chinese { return chinese }
        return locale.language.languageCode?.identifier == "zh"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
            Text(num)
                .font(DS.Typography.mono)
                .tracking(DS.Tracking.mono)
                .foregroundStyle(DS.Color.inkDim)
                .monospacedDigit()

            Text(title)
                .font(DS.Typography.bodyS.weight(.medium))
                .foregroundStyle(DS.Color.ink)

            if let sub {
                Text(sub)
                    .font(DS.Typography.mono)
                    .tracking(isChinese ? 0 : DS.Tracking.mono)
                    .textCase(isChinese ? nil : .uppercase)
                    .foregroundStyle(DS.Color.inkMid)
            }

            Spacer(minLength: DS.Spacing.s)

            if let action {
                if let onAction {
                    Button(action: onAction) {
                        actionLabel(action)
                    }
                    .buttonStyle(.plain)
                } else {
                    actionLabel(action)
                }
            }
        }
    }

    private func actionLabel(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.mono)
            .tracking(isChinese ? 0 : DS.Tracking.mono)
            .textCase(isChinese ? nil : .uppercase)
            .foregroundStyle(actionColor)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DS.Spacing.l) {
        SectionHead(num: "01", title: "Vitals", sub: "6 metrics", action: "All")
        SectionHead(num: "02", title: "Train", sub: "Suggested", action: "Start")
        SectionHead(num: "03", title: "Today", sub: "Timeline")
        SectionHead(num: "01", title: "生命体征", sub: "6 项", action: "全部", chinese: true)
    }
    .padding(DS.Spacing.edge)
    .frame(maxWidth: .infinity)
    .background(DS.Color.bg)
}
