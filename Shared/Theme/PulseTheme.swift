import SwiftUI

// MARK: - Pulse Design System
// Warm, organic, minimal. Oura's calm meets Apple Weather's depth.
// 暖色调，有质感，不要AI味

enum PulseTheme {

    // MARK: - Colors
    // Earthy palette — browns, ambers, sage. No tech-blue.

    /// Deep warm charcoal — not pure black
    static let background = Color(hex: "0D0C0B")

    /// Slightly elevated warm surface
    static let surface = Color(hex: "161412")

    /// Card background with earthy warmth
    static let cardBackground = Color(hex: "1A1816")

    /// Elevated card (active/pressed)
    static let cardElevated = Color(hex: "211E1B")

    /// Subtle warm border
    static let border = Color(hex: "2A2623")

    /// Primary text — warm parchment white
    static let textPrimary = Color(hex: "F5F0EB")

    /// Secondary text — warm stone gray
    static let textSecondary = Color(hex: "9A938C")

    /// Tertiary text — muted earth
    static let textTertiary = Color(hex: "5C564F")

    // MARK: - Status Colors

    /// Good / recovered — soft sage green
    static let statusGood = Color(hex: "7FB069")

    /// Moderate / okay — warm amber
    static let statusModerate = Color(hex: "D4A056")

    /// Poor / needs rest — muted terracotta
    static let statusPoor = Color(hex: "C75C5C")

    /// Primary accent — warm antique gold
    static let accent = Color(hex: "C9A96E")

    /// Subtle warm highlight for active states
    static let warmHighlight = Color(hex: "2D2520")

    // MARK: - Gradients

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
        case 0..<30: return "需要休息"
        case 30..<50: return "状态一般"
        case 50..<70: return "还不错"
        case 70..<85: return "状态良好"
        default: return "巅峰状态"
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
