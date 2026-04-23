import SwiftUI

// MARK: - Pulse Design System
// ui3.0: Editorial Dark — Rewired + Bevel hybrid, glass morphism
// Warm whites, glass cards, premium typography

enum PulseTheme {

    // MARK: - Colors
    // Editorial Dark — warm whites, glass surfaces

    /// Deep black background
    static let background = Color(hex: "0A0A0A")

    /// Elevated surface — subtle glass
    static let surface = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.03)

    /// Secondary surface — slightly more visible
    static let surface2 = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.05)

    /// Card background — glass-like transparency
    static let cardBackground = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.02)

    /// Elevated card (active/pressed)
    static let cardElevated = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.05)

    /// Subtle glass border
    static let border = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.07)

    /// Primary text — warm white (not pure #FFF)
    static let textPrimary = Color(.sRGB, red: 245/255, green: 245/255, blue: 240/255, opacity: 1.0)

    /// Secondary text — warm white at 60%
    static let textSecondary = Color(.sRGB, red: 245/255, green: 245/255, blue: 240/255, opacity: 0.6)

    /// Tertiary text — warm white at 40%
    static let textTertiary = Color(.sRGB, red: 245/255, green: 245/255, blue: 240/255, opacity: 0.4)

    /// Quaternary text — warm white at 20% (labels, dividers)
    static let textQuaternary = Color(.sRGB, red: 245/255, green: 245/255, blue: 240/255, opacity: 0.2)

    // MARK: - Accent Colors
    // DESIGN RULE: Accent colors are PUNCTUATION ONLY.
    // Use them for: 6px status dots, 1px borders/glows, small text labels, icon tints.
    // NEVER use as large background fills. Keep them small and intentional.

    /// TriScore primary / accent — electric teal
    static let accentTeal = Color(hex: "00F5FF")

    /// Sleep / HRV accent — soft violet
    static let sleepViolet = Color(hex: "BF94FF")

    /// Activity / steps accent — coral red
    static let activityCoral = Color(hex: "FF6B6B")

    // MARK: - Status Colors

    /// Good / recovered — Rewired lime
    static let statusGood = Color(hex: "BFFF00")

    /// Warning / moderate — muted amber
    static let statusWarning = Color(hex: "E0A850")

    /// Moderate / okay — soft violet
    static let statusModerate = Color(hex: "BF94FF")

    /// Poor / needs rest — Rewired orange
    static let statusPoor = Color(hex: "FF6B00")

    /// Legacy aliases
    static let accent = accentTeal
    static let sleepAccent = sleepViolet
    static let activityAccent = activityCoral

    /// Positive state accent — Rewired lime
    static let positiveGreen = Color(hex: "BFFF00")

    /// Subtle highlight for active states
    static let warmHighlight = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.04)

    // MARK: - Semantic Colors

    /// Trend / chart blue
    static let trendBlue = Color(hex: "5B8DEF")

    /// HRV chart blue
    static let hrvBlue = Color(hex: "5C7BC7")

    /// Chart purple
    static let chartPurple = Color(hex: "4B3D8F")

    // MARK: - Gradients

    /// Hero section gradient — subtle, editorial
    static let heroGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: "0A0F14"), location: 0),
            .init(color: Color(hex: "0C1A22"), location: 0.3),
            .init(color: Color(hex: "0E2029"), location: 0.5),
            .init(color: Color(hex: "0B1419"), location: 0.7),
            .init(color: Color(hex: "0A0A0A"), location: 1.0),
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
    // Premium hierarchy: heavy rounded numbers, clean body, uppercase captions

    static let titleFont: Font = .system(size: 28, weight: .bold, design: .rounded)
    static let headlineFont: Font = .system(size: 18, weight: .semibold, design: .rounded)
    static let bodyFont: Font = .system(size: 15, weight: .regular, design: .default)
    static let captionFont: Font = .system(size: 11, weight: .semibold, design: .default)
    static let scoreFont: Font = .system(size: 52, weight: .heavy, design: .rounded)
    static let metricFont: Font = .system(size: 24, weight: .bold, design: .rounded)
    static let metricLabelFont: Font = .system(size: 11, weight: .semibold, design: .default)

    /// Caption letter spacing for ALL CAPS labels (use with .tracking())
    static let captionTracking: CGFloat = 1.5

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

    static let cardShadow: Color = .black.opacity(0.15)
    static let glowShadow: Color = accent.opacity(0.10)

    // MARK: - Animation Presets
    // DESIGN RULE: No bounce. Critically damped or easeOut only.

    static let animationFast: Animation = .easeOut(duration: 0.2)
    static let animationNormal: Animation = .easeOut(duration: 0.3)
    static let animationSlow: Animation = .easeOut(duration: 0.4)
    static let animationBreathing: Animation = .easeInOut(duration: 4).repeatForever(autoreverses: true)

    // MARK: - Heart Rate Zone Colors

    static let zoneRest = Color(hex: "3B82F6")       // Zone 1 — Rest
    static let zoneFatBurn = Color(hex: "22C55E")     // Zone 2 — Fat Burn
    static let zoneCardio = Color(hex: "EAB308")      // Zone 3 — Cardio
    static let zonePeak = Color(hex: "F97316")        // Zone 4 — Peak
    static let zoneMax = Color(hex: "EF4444")         // Zone 5 — Max

    static let zoneColors: [Color] = [zoneRest, zoneFatBurn, zoneCardio, zonePeak, zoneMax]

    // MARK: - Muscle Status Colors

    static let muscleHealthy = Color(hex: "7FC75C")
    static let muscleFatigued = Color(hex: "C75C5C")

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
                ZStack {
                    // Glass fill — rgba(255,255,255,0.02)
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .fill(PulseTheme.cardBackground)
                    // Inner top highlight — glass rim light, white 5% at top fading to clear at 30%
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.05), location: 0),
                                    .init(color: Color.clear, location: 0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous))
            // Noise texture overlay — subtle grain
            .modifier(NoiseTexture(opacity: 0.03))
            // 1px glass border — rgba(255,255,255,0.07)
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .stroke(PulseTheme.border, lineWidth: 1)
            )
            // NO drop shadow — glass floats without it
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
                // Critically damped — no bounce, no overshoot
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

// MARK: - Noise Texture Overlay

struct NoiseTexture: ViewModifier {
    var opacity: Double = 0.03

    func body(content: Content) -> some View {
        content.overlay(
            Canvas { context, size in
                let count = Int(size.width * size.height * 0.01)
                for _ in 0..<count {
                    let x = Double.random(in: 0...size.width)
                    let y = Double.random(in: 0...size.height)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white)
                    )
                }
            }
            .blendMode(.overlay)
            .opacity(opacity)
            .allowsHitTesting(false)
        )
    }
}

extension View {
    func noiseTexture(opacity: Double = 0.03) -> some View {
        modifier(NoiseTexture(opacity: opacity))
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
            .animation(.spring(response: 0.3, dampingFraction: 1.0), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct PulseSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PulseTheme.bodyFont.weight(.medium))
            .foregroundColor(PulseTheme.accent)
            .padding(.horizontal, PulseTheme.spacingL)
            .padding(.vertical, PulseTheme.spacingS)
            .background(PulseTheme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(PulseTheme.animationFast, value: configuration.isPressed)
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
