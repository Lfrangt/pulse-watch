import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Pulse Design System v2 — DS shim
//
// Phase 5 collapses the v1 PulseTheme namespace into a thin forwarding layer
// over DS.Color / DS.Spacing / DS.Radius / DS.Typography / DS.Motion. Every
// `PulseTheme.X` reference in legacy services / models / KEEP-MIGRATE
// components (which R11 forbids touching) now resolves to the v2 Clinical
// design tokens.
//
// New code MUST use DS.* directly. PulseTheme.X is preserved only so the
// untouched service / model layer compiles.

enum PulseTheme {

    // MARK: - Surfaces
    static let background       = DS.Color.bg
    static let surface          = DS.Color.bgElev
    static let surface2         = DS.Color.bgElev
    static let cardBackground   = DS.Color.bgElev
    static let cardElevated     = DS.Color.bgElev
    static let border           = DS.Color.line
    static let borderStrong     = DS.Color.line
    static let divider          = DS.Color.lineSoft
    static let highlight        = DS.Color.chipBg
    static let warmHighlight    = DS.Color.chipBg
    static let scrim            = Color.black.opacity(0.6)

    // MARK: - Foreground
    static let textPrimary      = DS.Color.ink
    static let textSecondary    = DS.Color.inkMid
    static let textTertiary     = DS.Color.inkDim
    static let textQuaternary   = DS.Color.inkDim

    // MARK: - Accent (single mono accent per v2 Clinical)
    static let accent           = DS.Color.accent
    static let accentTeal       = DS.Color.accent
    static let accentSoft       = DS.Color.accent.opacity(0.12)
    static let accentStrong     = DS.Color.accent

    // MARK: - Status
    static let statusGood       = DS.Color.good
    static let statusWarning    = DS.Color.warn
    static let statusPoor       = DS.Color.bad
    static let statusModerate   = DS.Color.warn

    // MARK: - Legacy multi-color aliases — all retired to single accent.
    static let sleepViolet      = DS.Color.accent
    static let activityCoral    = DS.Color.accent
    static let positiveGreen    = DS.Color.good
    static let sleepAccent      = DS.Color.accent
    static let activityAccent   = DS.Color.accent
    static let trendBlue        = DS.Color.accent
    static let hrvBlue          = DS.Color.accent
    static let chartPurple      = DS.Color.accent

    // MARK: - HR Zones (Z1 → Z5) — clinical neutral progression.
    static let zoneRest         = DS.Color.lineSoft
    static let zoneFatBurn      = DS.Color.inkDim
    static let zoneCardio       = DS.Color.accent
    static let zonePeak         = DS.Color.warn
    static let zoneMax          = DS.Color.bad
    static let zoneColors: [Color] = [zoneRest, zoneFatBurn, zoneCardio, zonePeak, zoneMax]

    // MARK: - Muscle status
    static let muscleHealthy    = DS.Color.good
    static let muscleFatigued   = DS.Color.bad

    // MARK: - Typography (forward to DS.Typography)
    static let displayFont: Font     = DS.Typography.display3
    static let titleFont: Font       = DS.Typography.title1
    static let title2Font: Font      = DS.Typography.title2
    static let headlineFont: Font    = DS.Typography.bodyL
    static let bodyFont: Font        = DS.Typography.body
    static let bodyStrongFont: Font  = DS.Typography.body.weight(.medium)
    static let calloutFont: Font     = DS.Typography.bodyS
    static let footnoteFont: Font    = DS.Typography.caption
    static let captionFont: Font     = DS.Typography.caption
    static let eyebrowFont: Font     = DS.Typography.mono

    static let metricXLFont: Font    = DS.Typography.display2
    static let metricLFont: Font     = DS.Typography.display3
    static let metricMFont: Font     = DS.Typography.title1
    static let metricSFont: Font     = DS.Typography.title2

    static let unitFont: Font        = DS.Typography.monoL
    static let monoFont: Font        = DS.Typography.mono

    static let scoreFont: Font       = DS.Typography.display3
    static let metricFont: Font      = DS.Typography.title1
    static let metricLabelFont: Font = DS.Typography.mono

    static let captionTracking: CGFloat = DS.Tracking.mono
    static let eyebrowTracking: CGFloat = DS.Tracking.mono

    // MARK: - Spacing (mapped onto DS.Spacing)
    static let spacingXS: CGFloat  = DS.Spacing.xs
    static let spacingS:  CGFloat  = DS.Spacing.s
    static let spacingM:  CGFloat  = DS.Spacing.m
    static let spacingL:  CGFloat  = DS.Spacing.l
    static let spacingXL: CGFloat  = DS.Spacing.xl
    static let spacing2XL: CGFloat = DS.Spacing.xxl

    // MARK: - Radius
    static let radiusXS: CGFloat = DS.Radius.chip
    static let radiusS:  CGFloat = DS.Radius.chip
    static let radiusM:  CGFloat = DS.Radius.inner
    static let radiusL:  CGFloat = DS.Radius.card
    static let radiusXL: CGFloat = DS.Radius.card

    // MARK: - Stroke
    static let hairline: CGFloat = DS.Stroke.hairline

    // MARK: - Shadows — R7 forbids shadows. Tokens kept clear for backward compat.
    static let cardShadow: Color = .clear
    static let popShadow:  Color = .clear
    static let glowShadow: Color = .clear

    // MARK: - Animation (forward to DS.Motion)
    static let animationFast:      Animation = DS.Motion.tabSwitch
    static let animationNormal:    Animation = DS.Motion.scoreChange
    static let animationSlow:      Animation = DS.Motion.scoreChange
    static let animationBreathing: Animation = .easeInOut(duration: 4).repeatForever(autoreverses: true)

    // MARK: - Gradients (legacy compat — flattened to flat surfaces per v2 Clinical)
    static let heroGradient = LinearGradient(
        colors: [DS.Color.bg, DS.Color.bg],
        startPoint: .top, endPoint: .bottom
    )

    static func statusGradient(for score: Int) -> LinearGradient {
        let color = statusColor(for: score)
        return LinearGradient(
            colors: [color.opacity(0.06), color.opacity(0)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static func ambientGradient(for score: Int) -> RadialGradient {
        RadialGradient(colors: [.clear, .clear], center: .top, startRadius: 0, endRadius: 1)
    }

    // MARK: - Helpers
    static func statusColor(for score: Int) -> Color {
        switch score {
        case 0..<40:  return DS.Color.bad
        case 40..<70: return DS.Color.warn
        default:      return DS.Color.good
        }
    }

    static func statusLabel(for score: Int) -> String {
        switch score {
        case 0..<30:  return String(localized: "Rest")
        case 30..<50: return String(localized: "Average")
        case 50..<70: return String(localized: "Fair")
        case 70..<85: return String(localized: "Good")
        default:      return String(localized: "Peak")
        }
    }
}

// MARK: - Card modifier (mirror of DS.Card primitive — forwarded for legacy callers)

struct PulseCardStyle: ViewModifier {
    var padding: CGFloat = DS.Spacing.l

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DS.Color.bgElev)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
            )
    }
}

extension View {
    /// Legacy `.pulseCard()` — forwards to DS-tokenised PulseCardStyle.
    func pulseCard(padding: CGFloat = DS.Spacing.l) -> some View {
        modifier(PulseCardStyle(padding: padding))
    }

    /// Legacy `.pulseEyebrow()` — small mono uppercase + tracking + inkMid.
    func pulseEyebrow() -> some View {
        self.font(DS.Typography.mono)
            .tracking(DS.Tracking.mono)
            .textCase(.uppercase)
            .foregroundStyle(DS.Color.inkDim)
    }

    /// Legacy `.pulseHairline()` — overlay rounded rect with line stroke.
    func pulseHairline(radius: CGFloat = DS.Radius.card) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
        )
    }
}

// MARK: - Staggered entrance (legacy decoration — opacity + offset, no harm under
// reduce motion since the move is small).

struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                let anim = DS.Motion.respecting(
                    .easeOut(duration: 0.35).delay(Double(index) * 0.08),
                    reduce: reduceMotion
                )
                if let anim {
                    withAnimation(anim) { appeared = true }
                } else {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggered(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

// MARK: - Noise (legacy no-op — clinical has no grain)

struct NoiseTexture: ViewModifier {
    var opacity: Double = 0
    func body(content: Content) -> some View { content }
}

extension View {
    func noiseTexture(opacity: Double = 0) -> some View {
        modifier(NoiseTexture(opacity: opacity))
    }
}

// MARK: - Button styles (legacy — both forward to clinical DS surfaces)

struct PulseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.body.weight(.medium))
            .foregroundStyle(DS.Color.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.card)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Color.ink)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct PulseSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.body.weight(.medium))
            .foregroundStyle(DS.Color.accent)
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
            .background(DS.Color.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Color hex helpers (preserved — used by legacy services / models that
// build colors from hex strings or UInt32 RGB. Kept distinct from DS.swift's
// single-arg rgb initialiser by the alpha parameter.)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    init(rgb: UInt32, alpha: Double = 1.0) {
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255,
                  opacity: alpha)
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1.0) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: alpha)
    }

    convenience init(rgb: UInt32, alpha: Double) {
        self.init(rgb: rgb, alpha: CGFloat(alpha))
    }
}
#endif
