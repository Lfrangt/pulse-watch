import SwiftUI

// P1 · MonoLabel — small uppercase tracked label, "this is metadata, not content".
// Bilingual: zh skips uppercase + zeros tracking.

enum MonoSize {
    case s, m, l

    var font: Font {
        switch self {
        case .s: return DS.Typography.monoS
        case .m: return DS.Typography.mono
        case .l: return DS.Typography.monoL
        }
    }

    var tracking: CGFloat {
        switch self {
        case .s: return DS.Tracking.monoS
        case .m: return DS.Tracking.mono
        case .l: return DS.Tracking.monoL
        }
    }
}

enum MonoTone {
    case `default`, emphasised, dim, accent, good, warn, bad

    func color(_ chinese: Bool) -> Color {
        switch self {
        case .default:    return DS.Color.inkMid
        case .emphasised: return DS.Color.ink
        case .dim:        return DS.Color.inkDim
        case .accent:     return DS.Color.accent
        case .good:       return DS.Color.good
        case .warn:       return DS.Color.warn
        case .bad:        return DS.Color.bad
        }
    }
}

struct MonoLabel: View {
    let text: String
    var size: MonoSize = .m
    var tone: MonoTone = .default
    var chinese: Bool? = nil

    @Environment(\.locale) private var locale

    private var isChinese: Bool {
        if let chinese { return chinese }
        return locale.language.languageCode?.identifier == "zh"
    }

    var body: some View {
        Text(text)
            .font(size.font)
            .tracking(isChinese ? 0 : size.tracking)
            .textCase(isChinese ? nil : .uppercase)
            .foregroundStyle(tone.color(isChinese))
    }
}

#Preview("light · en") {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
        MonoLabel(text: "Today · May 5", size: .m)
        MonoLabel(text: "30d Trend", size: .s, tone: .dim)
        MonoLabel(text: "AVG 78 · σ 8.2", size: .m, tone: .default)
        MonoLabel(text: "Live", size: .s, tone: .accent)
        MonoLabel(text: "Awaiting Data", size: .l, tone: .emphasised)
    }
    .padding(DS.Spacing.edge)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DS.Color.bg)
    .preferredColorScheme(.light)
    .environment(\.locale, .init(identifier: "en"))
}

#Preview("dark · zh") {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
        MonoLabel(text: "今天 · 5月5日", size: .m)
        MonoLabel(text: "30 日趋势", size: .s, tone: .dim)
        MonoLabel(text: "均值 78 · σ 8.2", size: .m)
        MonoLabel(text: "实时", size: .s, tone: .accent)
        MonoLabel(text: "等待数据", size: .l, tone: .emphasised)
    }
    .padding(DS.Spacing.edge)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DS.Color.bg)
    .preferredColorScheme(.dark)
    .environment(\.locale, .init(identifier: "zh-Hans"))
}
