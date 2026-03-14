import SwiftUI

// MARK: - Pulse Design System
// Warm, organic, minimal. No AI-blue. Think: Oura's calm meets Apple's precision.

enum PulseTheme {
    
    // MARK: - Colors
    // Earthy, warm palette — not the typical tech blue/purple
    
    /// Deep charcoal background — not pure black, has warmth
    static let background = Color(hex: "0F0F0F")
    
    /// Slightly elevated surface — cards, sheets
    static let surface = Color(hex: "1A1A1A")
    
    /// Card background with subtle warmth
    static let cardBackground = Color(hex: "1E1E1E")
    
    /// Subtle border/divider
    static let border = Color(hex: "2A2A2A")
    
    /// Primary text — warm white, not harsh
    static let textPrimary = Color(hex: "F5F0EB")
    
    /// Secondary text — muted warm gray
    static let textSecondary = Color(hex: "8A8580")
    
    /// Tertiary text — very subtle
    static let textTertiary = Color(hex: "5A5550")
    
    // MARK: - Accent Colors (Status)
    
    /// Good / recovered — soft sage green
    static let statusGood = Color(hex: "7FB069")
    
    /// Moderate / okay — warm amber
    static let statusModerate = Color(hex: "D4A056")
    
    /// Poor / needs rest — muted coral
    static let statusPoor = Color(hex: "C75C5C")
    
    /// Accent — warm gold for highlights
    static let accent = Color(hex: "C9A96E")
    
    // MARK: - Gradients
    
    static let cardGradient = LinearGradient(
        colors: [cardBackground, cardBackground.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static func statusGradient(for score: Int) -> LinearGradient {
        let color = statusColor(for: score)
        return LinearGradient(
            colors: [color.opacity(0.3), color.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Typography
    
    static let titleFont: Font = .system(size: 28, weight: .semibold, design: .rounded)
    static let headlineFont: Font = .system(size: 20, weight: .medium, design: .rounded)
    static let bodyFont: Font = .system(size: 16, weight: .regular, design: .rounded)
    static let captionFont: Font = .system(size: 13, weight: .regular, design: .rounded)
    static let scoreFont: Font = .system(size: 56, weight: .bold, design: .rounded)
    static let metricFont: Font = .system(size: 24, weight: .semibold, design: .rounded)
    
    // MARK: - Spacing
    
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
    
    // MARK: - Corner Radius
    
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 24
    
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
