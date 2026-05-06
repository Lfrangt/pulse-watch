import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Pulse Design System v2 — Clinical
// Direction: Medical/dashboard minimalism (Apple Health + Luma references)
// Two themes: Light (warm paper #F7F6F2) + Dark (true black #000)
// Type: SF Pro Rounded for metrics (tabular), SF Pro Text for body, SF Mono for units
// Rules: data is decoration, no gradients/glass/shadows except overlays,
//        single functional accent (desaturated teal), hairline borders replace shadows.

enum PulseTheme {

    // MARK: - Dynamic color helpers

    private static func dyn(light: UInt32, dark: UInt32) -> Color {
        #if os(watchOS)
        return Color(rgb: dark)
        #elseif canImport(UIKit)
        return Color(UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        return Color(rgb: dark)
        #endif
    }

    private static func dynA(light: (UInt32, Double), dark: (UInt32, Double)) -> Color {
        #if os(watchOS)
        return Color(rgb: dark.0).opacity(dark.1)
        #elseif canImport(UIKit)
        return Color(UIColor { trait in
            let (hex, alpha) = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(rgb: hex, alpha: alpha)
        })
        #else
        return Color(rgb: dark.0).opacity(dark.1)
        #endif
    }

    // MARK: - Surfaces

    static let background       = dyn(light: 0xF7F6F2, dark: 0x000000)
    static let surface          = dyn(light: 0xFFFFFF, dark: 0x141414)
    static let surface2         = dyn(light: 0xFFFFFF, dark: 0x1A1A1A)
    static let cardBackground   = dyn(light: 0xFFFFFF, dark: 0x141414)
    static let cardElevated     = dyn(light: 0xFBFAF7, dark: 0x1F1F1F)
    static let border           = dyn(light: 0xE8E5DC, dark: 0x2A2A2A)
    static let borderStrong     = dyn(light: 0xD4CFC0, dark: 0x363636)
    static let divider          = dyn(light: 0xEFECE4, dark: 0x171717)
    static let highlight        = dynA(light: (0x000000, 0.03), dark: (0xFFFFFF, 0.04))
    static let warmHighlight    = highlight
    static let scrim            = dynA(light: (0x000000, 0.06), dark: (0x000000, 0.60))

    // MARK: - Foreground

    static let textPrimary      = dynA(light: (0x17161A, 1.00), dark: (0xF5F5F0, 1.00))
    static let textSecondary    = dynA(light: (0x52504C, 1.00), dark: (0xF5F5F0, 0.60))
    static let textTertiary     = dynA(light: (0x8A867E, 1.00), dark: (0xF5F5F0, 0.40))
    static let textQuaternary   = dynA(light: (0xB7B2A6, 1.00), dark: (0xF5F5F0, 0.20))

    // MARK: - Accent — desaturated medical teal (single functional accent)

    static let accent           = dyn(light: 0x0A7E8C, dark: 0x4FD9E6)
    static let accentTeal       = accent
    static let accentSoft       = dynA(light: (0x0A7E8C, 0.10), dark: (0x4FD9E6, 0.14))
    static let accentStrong     = dyn(light: 0x086570, dark: 0x7FE6F0)

    // MARK: - Status (medical-appropriate desaturated)

    static let statusGood       = dyn(light: 0x2F9E5C, dark: 0x6BD393)
    static let statusWarning    = dyn(light: 0xC28A2C, dark: 0xE8B24F)
    static let statusPoor       = dyn(light: 0xC43E28, dark: 0xF07A5F)
    static let statusModerate   = dyn(light: 0x6B5FC2, dark: 0xA898F5)

    // MARK: - Legacy multi-color aliases — all retired to single accent
    // v2 Clinical: data is decoration; semantic distinction lives in icon + label,
    // not color. These tokens stay name-compatible so views compile, but every
    // chart / metric / decorative usage now resolves to the single teal accent.
    // Real status semantics (statusGood / Warning / Poor / Moderate) stay below.

    static let sleepViolet      = accent
    static let activityCoral    = accent
    static let positiveGreen    = statusGood
    static let sleepAccent      = accent
    static let activityAccent   = accent
    static let trendBlue        = accent
    static let hrvBlue          = accent
    static let chartPurple      = accent

    // MARK: - Heart Rate Zones (Z1 → Z5)

    static let zoneRest         = dyn(light: 0x6FA8DC, dark: 0x6FA8DC)
    static let zoneFatBurn      = dyn(light: 0x2F9E5C, dark: 0x6BD393)
    static let zoneCardio       = dyn(light: 0xC28A2C, dark: 0xE8B24F)
    static let zonePeak         = dyn(light: 0xD97A2B, dark: 0xF09A4F)
    static let zoneMax          = dyn(light: 0xC43E28, dark: 0xF07A5F)
    static let zoneColors: [Color] = [zoneRest, zoneFatBurn, zoneCardio, zonePeak, zoneMax]

    // MARK: - Muscle status

    static let muscleHealthy    = statusGood
    static let muscleFatigued   = statusPoor

    // MARK: - Typography
    // SF Pro Rounded for metrics, SF Pro Text for body, SF Mono for units
    // Hierarchy by size, not weight. Tabular numerics on all data.

    static let displayFont: Font     = .system(size: 56, weight: .bold,     design: .rounded)
    static let titleFont: Font       = .system(size: 34, weight: .bold,     design: .rounded)
    static let title2Font: Font      = .system(size: 22, weight: .semibold, design: .rounded)
    static let headlineFont: Font    = .system(size: 17, weight: .semibold, design: .rounded)
    static let bodyFont: Font        = .system(size: 15, weight: .regular)
    static let bodyStrongFont: Font  = .system(size: 15, weight: .medium)
    static let calloutFont: Font     = .system(size: 13, weight: .medium)
    static let footnoteFont: Font    = .system(size: 12, weight: .regular)
    static let captionFont: Font     = .system(size: 11, weight: .semibold)
    static let eyebrowFont: Font     = .system(size: 10, weight: .semibold)

    // Metric scale — tabular numerics
    static let metricXLFont: Font    = .system(size: 72, weight: .bold,     design: .rounded).monospacedDigit()
    static let metricLFont: Font     = .system(size: 44, weight: .semibold, design: .rounded).monospacedDigit()
    static let metricMFont: Font     = .system(size: 28, weight: .semibold, design: .rounded).monospacedDigit()
    static let metricSFont: Font     = .system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()

    // Mono unit/timestamp
    static let unitFont: Font        = .system(size: 13, weight: .medium, design: .monospaced)
    static let monoFont: Font        = .system(size: 13, weight: .regular, design: .monospaced)

    // Legacy aliases
    static let scoreFont: Font       = metricLFont
    static let metricFont: Font      = metricMFont
    static let metricLabelFont: Font = eyebrowFont

    // Tracking (points, not em)
    static let captionTracking: CGFloat = 0.66   // ~0.06em at 11pt
    static let eyebrowTracking: CGFloat = 2.2    // ~0.22em at 10pt

    // MARK: - Spacing (4-based)

    static let spacingXS: CGFloat  = 4
    static let spacingS:  CGFloat  = 8
    static let spacingM:  CGFloat  = 16
    static let spacingL:  CGFloat  = 24
    static let spacingXL: CGFloat  = 32
    static let spacing2XL: CGFloat = 48

    // MARK: - Corner Radius

    static let radiusXS: CGFloat = 6    // pills
    static let radiusS:  CGFloat = 10   // small buttons, inputs
    static let radiusM:  CGFloat = 14   // metric tiles, buttons
    static let radiusL:  CGFloat = 19   // cards, sheets
    static let radiusXL: CGFloat = 28   // bottom sheets

    // MARK: - Borders

    static let hairline: CGFloat = 1

    // MARK: - Shadows
    // Clinical: shadows reserved for popovers/sheets only — cards rely on hairline borders.
    // Legacy properties kept near-invisible for backward compat.

    static let cardShadow: Color = .black.opacity(0.04)
    static let popShadow:  Color = .black.opacity(0.10)
    static let glowShadow: Color = .clear

    // MARK: - Animation
    // easeOut only, no bounce. Fast/normal/slow durations.

    static let animationFast:      Animation = .easeOut(duration: 0.15)
    static let animationNormal:    Animation = .easeOut(duration: 0.22)
    static let animationSlow:      Animation = .easeOut(duration: 0.35)
    static let animationBreathing: Animation = .easeInOut(duration: 4).repeatForever(autoreverses: true)

    // MARK: - Gradients (legacy compat — flattened to clinical)

    static let heroGradient = LinearGradient(
        colors: [background, background],
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
        case 0..<40:  return statusPoor
        case 40..<70: return statusModerate
        default:      return statusGood
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

// MARK: - Card Modifier — Clinical (opaque + hairline + 19pt)

struct PulseCardStyle: ViewModifier {
    var padding: CGFloat = PulseTheme.spacingL

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PulseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                    .stroke(PulseTheme.border, lineWidth: PulseTheme.hairline)
            )
    }
}

extension View {
    func pulseCard(padding: CGFloat = PulseTheme.spacingL) -> some View {
        modifier(PulseCardStyle(padding: padding))
    }

    /// Eyebrow label: 10pt semibold, ALL CAPS, +0.22em tracking, fg-3.
    func pulseEyebrow() -> some View {
        self.font(PulseTheme.eyebrowFont)
            .tracking(PulseTheme.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(PulseTheme.textTertiary)
    }

    /// Hairline border at given radius.
    func pulseHairline(radius: CGFloat = PulseTheme.radiusL) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(PulseTheme.border, lineWidth: PulseTheme.hairline)
        )
    }
}

// MARK: - Staggered appearance

struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35).delay(Double(index) * 0.08)) {
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

// MARK: - Buttons — Clinical

/// Primary: inverted fg/bg pattern (data-as-decoration aesthetic).
struct PulseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PulseTheme.bodyStrongFont)
            .foregroundStyle(PulseTheme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                    .fill(PulseTheme.textPrimary)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(PulseTheme.animationFast, value: configuration.isPressed)
    }
}

/// Secondary: tinted accent, used sparingly.
struct PulseSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PulseTheme.bodyStrongFont)
            .foregroundStyle(PulseTheme.accent)
            .padding(.horizontal, PulseTheme.spacingL)
            .padding(.vertical, PulseTheme.spacingS)
            .background(PulseTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(PulseTheme.animationFast, value: configuration.isPressed)
    }
}

// MARK: - Color helpers

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
