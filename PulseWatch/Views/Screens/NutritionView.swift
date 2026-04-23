import SwiftUI

/// Coming Soon stub — Nutrition Tracking preview
struct NutritionView: View {

    @State private var appeared = false
    @State private var ringAnimated = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingXL) {

                Spacer().frame(height: PulseTheme.spacingL)

                // MARK: - Hero illustration
                ZStack {
                    // Ambient glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "FF9F43").opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(appeared ? 1.08 : 0.95)
                        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: appeared)

                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        Image(systemName: "fork.knife")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FF9F43"), Color(hex: "FF6B6B")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(appeared ? 1.0 : 0.8)
                            .opacity(appeared ? 1.0 : 0)
                    }
                }

                // MARK: - Title + badge
                VStack(spacing: PulseTheme.spacingS) {
                    Text(String(localized: "Nutrition Tracking"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)

                    Text(String(localized: "Track meals, macros, and how nutrition affects your recovery"))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(PulseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PulseTheme.spacingL)

                    // Coming Soon badge
                    Text(String(localized: "Coming Soon"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(hex: "FF9F43"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(hex: "FF9F43").opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "FF9F43").opacity(0.25), lineWidth: 0.5)
                                )
                        )
                        .padding(.top, 4)
                }

                // MARK: - Macro preview circles
                VStack(spacing: PulseTheme.spacingM) {
                    Text(String(localized: "DAILY MACROS"))
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(PulseTheme.captionTracking)
                        .foregroundStyle(PulseTheme.textTertiary)

                    HStack(spacing: PulseTheme.spacingL) {
                        macroCircle(
                            label: String(localized: "Protein"),
                            percentage: 35,
                            grams: "142g",
                            color: Color(hex: "FF6B6B")
                        )
                        macroCircle(
                            label: String(localized: "Carbs"),
                            percentage: 45,
                            grams: "225g",
                            color: Color(hex: "FFD700")
                        )
                        macroCircle(
                            label: String(localized: "Fat"),
                            percentage: 20,
                            grams: "67g",
                            color: Color(hex: "BF94FF")
                        )
                    }
                }
                .padding(PulseTheme.spacingL)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .overlay(alignment: .topTrailing) {
                    Text(String(localized: "Preview"))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(PulseTheme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.white.opacity(0.06))
                        )
                        .padding(12)
                }
                .padding(.horizontal, PulseTheme.spacingM)

                // MARK: - Feature preview list
                VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
                    featureRow(icon: "camera.fill", text: String(localized: "Snap a photo to log meals instantly"))
                    featureRow(icon: "chart.bar.fill", text: String(localized: "See how nutrition impacts your recovery score"))
                    featureRow(icon: "bell.badge.fill", text: String(localized: "Smart reminders for meal timing"))
                }
                .padding(PulseTheme.spacingL)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, PulseTheme.spacingM)

                Spacer(minLength: 60)
            }
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "Nutrition"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3)) {
                ringAnimated = true
            }
        }
    }

    // MARK: - Macro Circle

    private func macroCircle(label: String, percentage: Int, grams: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                // Track
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 5)
                    .frame(width: 64, height: 64)

                // Progress
                Circle()
                    .trim(from: 0, to: ringAnimated ? CGFloat(percentage) / 100 : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                // Percentage
                Text("\(percentage)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
            }

            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)

            Text(grams)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "FF9F43").opacity(0.1))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "FF9F43"))
            }

            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        NutritionView()
    }
    .preferredColorScheme(.dark)
}
