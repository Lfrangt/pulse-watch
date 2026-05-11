// Pulse Design Tokens — single source of truth.
//
// HARD RULE: Outside this file, NO color hex literal, NO numeric font size,
// NO numeric padding/spacing/radius. Always reference DS.* tokens.
// Violations are caught by Scripts/check-design-rules.sh.
//
// Origin: design/DESIGN.md v1.0 + design/reference/tokens.js
//
// Port to install: copy this file to Shared/Theme/DS.swift,
// then delete the legacy PulseTheme.swift in the same Phase 1 commit.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Namespace

enum DS {

    // MARK: - Color

    enum Color {
        // Surfaces
        static let bg       = dyn(light: 0xF5F4EF, dark: 0x0B0C0A)
        static let bgElev   = dyn(light: 0xFFFFFF, dark: 0x141513)
        static let bgSunk   = dyn(light: 0xEDEBE3, dark: 0x070806)

        // Lines
        static let line     = dynA(light: (0x141612, 0.10), dark: (0xFFFFFF, 0.10))
        static let lineSoft = dynA(light: (0x141612, 0.06), dark: (0xFFFFFF, 0.05))

        // Ink
        static let ink      = dyn(light: 0x14140F, dark: 0xF2F1EC)
        static let inkMid   = dynA(light: (0x141612, 0.62), dark: (0xF2F1EC, 0.62))
        static let inkDim   = dynA(light: (0x141612, 0.38), dark: (0xF2F1EC, 0.34))

        // Accent (single saturated color allowed in the system)
        static let accent    = dyn(light: 0xC8FF3D, dark: 0xD2FF3D)
        static let accentInk = SwiftUI.Color(rgb: 0x0E1A00) // constant ink on accent

        // Semantic (only for status meaning, never for decoration)
        static let good = dyn(light: 0x2F7A3D, dark: 0x7BD68A)
        static let warn = dyn(light: 0xB6571B, dark: 0xE89A55)
        static let bad  = dyn(light: 0xA11D1D, dark: 0xE76E6E)

        // Chip background
        static let chipBg = dynA(light: (0x141612, 0.05), dark: (0xFFFFFF, 0.06))
    }

    // MARK: - Spacing (no half values; only 4 / 8 / 12 / 14 / 18 / 22 / 26 / 32 / 40)

    enum Spacing {
        static let xs:    CGFloat = 4
        static let s:     CGFloat = 8
        static let m:     CGFloat = 12
        static let card:  CGFloat = 14   // card inner top-bottom
        static let l:     CGFloat = 18   // card inner default
        static let edge:  CGFloat = 22   // iPhone screen edge
        static let group: CGFloat = 26   // gap between semantic groups
        static let xl:    CGFloat = 32
        static let xxl:   CGFloat = 40

        // Per-platform edge override
        static let watchEdge:  CGFloat = 14
        static let widgetEdge: CGFloat = 12
    }

    // MARK: - Radius

    enum Radius {
        static let chipIcon: CGFloat = 2
        static let chip:     CGFloat = 8
        static let inner:    CGFloat = 14
        static let card:     CGFloat = 18
        static let watch:    CGFloat = 38
        static let pill:     CGFloat = 999
    }

    // MARK: - Stroke

    enum Stroke {
        static let hairline:    CGFloat = 0.5
        static let chartLine:   CGFloat = 1.25
        static let chartHeavy:  CGFloat = 1.5
        static let tickMajor:   CGFloat = 1.25
        static let tickMinor:   CGFloat = 0.75
    }

    // MARK: - Typography
    //
    // System font policy: Apple-platform native — SF Pro for display,
    // SF Mono for mono LABEL types. The web design names "Inter" + "JetBrains Mono"
    // are equivalent intent on web; on iOS we use SF Pro / SF Mono.
    //
    // tabular_nums + ss01 stylistic alternates are applied through .monospacedDigit()
    // and .fontFeatureSettings on supporting platforms.

    enum Typography {
        // Display (large numerals, score, timer)
        static let display1 = Font.system(size: 96, weight: .ultraLight).monospacedDigit()
        static let display2 = Font.system(size: 72, weight: .light).monospacedDigit()
        static let display3 = Font.system(size: 48, weight: .light).monospacedDigit()

        // Title
        static let title1 = Font.system(size: 28, weight: .regular)
        static let title2 = Font.system(size: 22, weight: .regular)

        // Body
        static let bodyL    = Font.system(size: 17, weight: .regular)
        static let body     = Font.system(size: 15, weight: .regular)
        static let bodyS    = Font.system(size: 13, weight: .regular)
        static let caption  = Font.system(size: 12, weight: .regular)

        // Mono (labels, units, timestamps — UPPERCASE per usage rule)
        static let monoL = Font.system(size: 12, weight: .medium, design: .monospaced)
        static let mono  = Font.system(size: 10, weight: .medium, design: .monospaced)
        static let monoS = Font.system(size: 9,  weight: .medium, design: .monospaced)

        // Watch
        static let watchScore = Font.system(size: 70, weight: .ultraLight).monospacedDigit()
        static let watchLabel = Font.system(size: 9,  weight: .medium, design: .monospaced)
        static let watchVital = Font.system(size: 9,  weight: .medium, design: .monospaced) // 8.5pt rounded

        // Widget
        static let widgetSScore = Font.system(size: 56, weight: .ultraLight).monospacedDigit()
        static let widgetMScore = Font.system(size: 48, weight: .ultraLight).monospacedDigit()
        static let widgetLScore = Font.system(size: 64, weight: .ultraLight).monospacedDigit()
        static let widgetLabel  = Font.system(size: 10, weight: .medium, design: .monospaced)
    }

    // MARK: - Letter spacing (tracking) — apply via .tracking()
    //
    // SwiftUI tracking is in points, not em. These are calibrated for the matching
    // Type scale entry above.

    enum Tracking {
        static let display1: CGFloat = -3.84  // -0.04em × 96pt
        static let display2: CGFloat = -2.16
        static let display3: CGFloat = -0.96
        static let title1:   CGFloat = -0.6
        static let title2:   CGFloat = -0.4
        static let monoL:    CGFloat = 0.5
        static let mono:     CGFloat = 0.8
        static let monoS:    CGFloat = 0.6
    }

    // MARK: - Motion

    enum Motion {
        static let scoreChange: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.6)
        static let tabSwitch:   Animation = .easeOut(duration: 0.22)
        static let anomaly:     Animation = .easeInOut(duration: 0.5)
        static let streak:      Animation = .spring(response: 0.4, dampingFraction: 0.6)
        // HR pulse uses real BPM as its period — see HRPulse view for derivation.

        /// Returns animation respecting Reduce Motion. Returns nil if reduce motion is on.
        @MainActor
        static func respecting(_ animation: Animation, reduce: Bool) -> Animation? {
            reduce ? nil : animation
        }
    }
}

// MARK: - Color helpers (private to this file)

private extension DS.Color {
    static func dyn(light: UInt32, dark: UInt32) -> SwiftUI.Color {
        #if os(watchOS)
        return SwiftUI.Color(rgb: dark)
        #elseif canImport(UIKit)
        return SwiftUI.Color(UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        return SwiftUI.Color(rgb: dark)
        #endif
    }

    static func dynA(light: (UInt32, Double), dark: (UInt32, Double)) -> SwiftUI.Color {
        #if os(watchOS)
        return SwiftUI.Color(rgb: dark.0).opacity(dark.1)
        #elseif canImport(UIKit)
        return SwiftUI.Color(UIColor { trait in
            let (hex, alpha) = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(rgb: hex).withAlphaComponent(alpha)
        })
        #else
        return SwiftUI.Color(rgb: dark.0).opacity(dark.1)
        #endif
    }
}

// MARK: - Color(rgb:) bridge — kept here so this file is the only hex literal site.

extension SwiftUI.Color {
    init(rgb: UInt32) {
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(rgb: UInt32) {
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif

// MARK: - View ergonomics

extension View {
    /// Apply a mono LABEL style (uppercase + tracking + inkMid color).
    /// English: text gets .uppercase (per RULES.md §3.4 lang policy).
    /// Chinese: tracking dropped, no uppercase — caller passes `chinese: true`.
    func dsMonoLabel(_ font: Font = DS.Typography.mono, chinese: Bool = false) -> some View {
        self
            .font(font)
            .tracking(chinese ? 0 : DS.Tracking.mono)
            .textCase(chinese ? nil : .uppercase)
            .foregroundStyle(DS.Color.inkMid)
    }

    /// Hairline border at the canonical 0.5pt with line color.
    func dsHairline(_ radius: CGFloat = DS.Radius.card) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
        )
    }

    /// Card surface — bgElev + radius + hairline + padding.
    func dsCard(padding: CGFloat = DS.Spacing.l) -> some View {
        self
            .padding(padding)
            .background(DS.Color.bgElev, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            .dsHairline()
    }
}
