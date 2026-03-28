import SwiftUI

// MARK: - Pulse Design System
// ui2.0: Biometric Minimalism — deep charcoal + electric teal/violet/coral
// Stitch AI generated, 2026-03-19

enum PulseTheme {

    // MARK: - Colors
    // Biometric Minimalism — cold precision, data-forward

    /// Deep black background
    static let background = Color(hex: "0A0A0A")

    /// Elevated surface
    static let surface = Color(hex: "1A1A1A")

    /// Secondary surface
    static let surface2 = Color(hex: "242424")

    /// Card background
    static let cardBackground = Color(hex: "1A1A1A")

    /// Elevated card (active/pressed)
    static let cardElevated = Color(hex: "242424")

    /// Subtle cool border
    static let border = Color(hex: "3A494A")

    /// Primary text — pure white
    static let textPrimary = Color(hex: "FFFFFF")

    /// Secondary text — neutral gray
    static let textSecondary = Color(hex: "A0A0A0")

    /// Tertiary text — dim
    static let textTertiary = Color(hex: "9AABAC")

    // MARK: - Accent Colors

    /// TriScore primary / accent — electric teal
    static let accentTeal = Color(hex: "00F5FF")

    /// Sleep / HRV accent — soft violet
    static let sleepViolet = Color(hex: "BF94FF")

    /// Activity / steps accent — coral red
    static let activityCoral = Color(hex: "FF6B6B")

    // MARK: - Status Colors

    /// Good / recovered — electric teal
    static let statusGood = Color(hex: "00F5FF")

    /// Warning / moderate — gold
    static let statusWarning = Color(hex: "FFD700")

    /// Moderate / okay — soft violet
    static let statusModerate = Color(hex: "BF94FF")

    /// Poor / needs rest — coral red
    static let statusPoor = Color(hex: "FF6B6B")

    /// Legacy aliases
    static let accent = accentTeal
    static let sleepAccent = sleepViolet
    static let activityAccent = activityCoral

    /// Subtle highlight for active states
    static let warmHighlight = Color(hex: "1A2A2A")

    // MARK: - Semantic Colors

    /// Trend / chart blue
    static let trendBlue = Color(hex: "5B8DEF")

    /// HRV chart blue
    static let hrvBlue = Color(hex: "5C7BC7")

    /// Chart purple
    static let chartPurple = Color(hex: "4B3D8F")

    // MARK: - Gradients

    /// Hero section gradient (teal atmospheric)
    static let heroGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: "0A1628"), location: 0),
            .init(color: Color(hex: "0F2A3D"), location: 0.25),
            .init(color: Color(hex: "134E5E"), location: 0.45),
            .init(color: Color(hex: "0D3B4A"), location: 0.65),
            .init(color: Color(hex: "0A1A24"), location: 0.85),
            .init(color: Color.black, location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static func statusGradient(for score: Int) -> LinearGradient {
        let color = statusColor(for: score)
        return LinearGradient(
            colors: [color.opacity(0.15), color.opacity(0.03)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Ambient background gradient — subtle warmth radiating from top
    static func ambientGradient(for score: Int) -> RadialGradient {
        let color = statusColor(for: score)
        return RadialGradient(
            colors: [color.opacity(0.08), Color.clear],
            center: .top,
            startRadius: 50,
            endRadius: 400
        )
    }

    // MARK: - Typography

    static let titleFont: Font = .system(size: 28, weight: .semibold, design: .rounded)
    static let headlineFont: Font = .system(size: 18, weight: .medium, design: .rounded)
    static let bodyFont: Font = .system(size: 15, weight: .regular, design: .rounded)
    static let captionFont: Font = .system(size: 13, weight: .regular, design: .rounded)
    static let scoreFont: Font = .system(size: 48, weight: .bold, design: .rounded)
    static let metricFont: Font = .system(size: 22, weight: .semibold, design: .rounded)
    static let metricLabelFont: Font = .system(size: 12, weight: .medium, design: .rounded)

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Corner Radius

    static let radiusS: CGFloat = 10
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 22

    // MARK: - Shadows

    static let cardShadow: Color = .black.opacity(0.35)
    static let glowShadow: Color = accent.opacity(0.15)

    // MARK: - Helpers

    static func statusColor(for score: Int) -> Color {
        switch score {
        case 0..<40: return statusPoor
        case 40..<70: return statusModerate
        default: return statusGood
        }
    }

    static func statusLabel(for score: Int) -> String {
        switch score {
        case 0..<30: return String(localized: "Rest")
        case 30..<50: return String(localized: "Average")
        case 50..<70: return String(localized: "Fair")
        case 70..<85: return String(localized: "Good")
        default: return String(localized: "Peak")
        }
    }
}

// MARK: - Card Style Modifier

struct PulseCardStyle: ViewModifier {
    var padding: CGFloat = PulseTheme.spacingL

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                    .fill(PulseTheme.cardBackground)
                    .shadow(color: PulseTheme.cardShadow, radius: 16, y: 6)
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                    .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
            )
    }
}

extension View {
    func pulseCard(padding: CGFloat = PulseTheme.spacingL) -> some View {
        modifier(PulseCardStyle(padding: padding))
    }
}

// MARK: - Staggered Appearance

struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.08)) {
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

// MARK: - Tactile Button Style

struct PulseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PulseTheme.bodyFont.weight(.medium))
            .foregroundStyle(PulseTheme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.accent)
                    .shadow(color: PulseTheme.accent.opacity(0.3), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Color Extension

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
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
