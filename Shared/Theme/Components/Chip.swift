import SwiftUI

// P15 · Chip — pill status badge or quick-prompt. Mono 10pt, pill radius.

enum ChipStyle {
    case neutral, accent, good, warn, bad

    var bg: Color {
        switch self {
        case .neutral: return DS.Color.chipBg
        case .accent:  return DS.Color.accent
        case .good:    return DS.Color.good.opacity(0.15)
        case .warn:    return DS.Color.warn.opacity(0.15)
        case .bad:     return DS.Color.bad.opacity(0.15)
        }
    }

    var fg: Color {
        switch self {
        case .neutral: return DS.Color.inkMid
        case .accent:  return DS.Color.accentInk
        case .good:    return DS.Color.good
        case .warn:    return DS.Color.warn
        case .bad:     return DS.Color.bad
        }
    }
}

struct Chip: View {
    let text: String
    var style: ChipStyle = .neutral
    var chinese: Bool? = nil

    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        if let chinese { return chinese }
        return locale.language.languageCode?.identifier == "zh"
    }

    var body: some View {
        Text(text)
            .font(DS.Typography.mono)
            .tracking(isChinese ? 0 : DS.Tracking.mono)
            .textCase(isChinese ? nil : .uppercase)
            .foregroundStyle(style.fg)
            .padding(.horizontal, DS.Spacing.s)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule(style: .continuous).fill(style.bg)
            )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
        HStack(spacing: DS.Spacing.s) {
            Chip(text: "Demo Data", style: .neutral)
            Chip(text: "Heavy", style: .accent)
            Chip(text: "Good", style: .good)
            Chip(text: "Stale", style: .warn)
            Chip(text: "Low SpO2", style: .bad)
        }
        HStack(spacing: DS.Spacing.s) {
            Chip(text: "演示数据", style: .neutral)
            Chip(text: "强度", style: .accent)
            Chip(text: "正常", style: .good)
        }
    }
    .padding(DS.Spacing.edge)
    .background(DS.Color.bg)
}
