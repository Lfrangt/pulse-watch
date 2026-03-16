import SwiftUI

/// Reusable component shown when HealthKit data is unavailable
/// Guides user to enable Health access via Settings app
struct HealthKitPermissionGuideView: View {
    
    @State private var pulseAnimation = false
    @State private var showLearnMore = false
    
    var body: some View {
        VStack(spacing: PulseTheme.spacingL) {
            // Animated heart illustration
            heartIllustration
            
            // Title and body text
            textContent
            
            // Primary CTA button
            settingsButton
            
            // Learn More section (collapsible)
            learnMoreSection
        }
        .padding(.vertical, PulseTheme.spacingXL)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow, radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .stroke(PulseTheme.accent.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
    
    // MARK: - Heart Illustration
    
    private var heartIllustration: some View {
        ZStack {
            // Pulse rings
            Circle()
                .fill(PulseTheme.accent.opacity(0.1))
                .frame(width: pulseAnimation ? 120 : 100, height: pulseAnimation ? 120 : 100)
                .opacity(pulseAnimation ? 0.3 : 0.6)
            
            Circle()
                .fill(PulseTheme.accent.opacity(0.15))
                .frame(width: pulseAnimation ? 100 : 80, height: pulseAnimation ? 100 : 80)
                .opacity(pulseAnimation ? 0.4 : 0.8)
            
            // Main heart icon
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(PulseTheme.accent)
                    .symbolEffect(.pulse, options: .repeating)
            }
        }
    }
    
    // MARK: - Text Content
    
    private var textContent: some View {
        VStack(spacing: PulseTheme.spacingM) {
            Text("Enable Health Access")
                .font(PulseTheme.titleFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Pulse Watch needs access to your health data to provide personalized insights, recovery scores, and training recommendations.")
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, PulseTheme.spacingM)
        }
    }
    
    // MARK: - Settings Button
    
    private var settingsButton: some View {
        Button {
            openAppSettings()
        } label: {
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "gear")
                    .font(.system(size: 16, weight: .medium))
                Text("Open Settings")
                    .font(PulseTheme.bodyFont.weight(.semibold))
            }
            .foregroundStyle(PulseTheme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.accent)
                    .shadow(color: PulseTheme.accent.opacity(0.3), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, PulseTheme.spacingM)
    }
    
    // MARK: - Learn More Section
    
    private var learnMoreSection: some View {
        VStack(spacing: PulseTheme.spacingS) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showLearnMore.toggle()
                }
            } label: {
                HStack(spacing: PulseTheme.spacingXS) {
                    Text("Learn More")
                        .font(PulseTheme.captionFont.weight(.medium))
                        .foregroundStyle(PulseTheme.textTertiary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .rotationEffect(.degrees(showLearnMore ? 90 : 0))
                        .animation(.spring(response: 0.3), value: showLearnMore)
                }
            }
            .buttonStyle(.plain)
            
            if showLearnMore {
                learnMoreContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, PulseTheme.spacingM)
    }
    
    private var learnMoreContent: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("What we access:")
                .font(PulseTheme.captionFont.weight(.semibold))
                .foregroundStyle(PulseTheme.textSecondary)
            
            VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                dataTypeRow(icon: "heart.fill", name: "Heart Rate & HRV", purpose: "Recovery analysis")
                dataTypeRow(icon: "figure.walk", name: "Steps & Activity", purpose: "Daily activity tracking")
                dataTypeRow(icon: "moon.fill", name: "Sleep Data", purpose: "Recovery insights")
                dataTypeRow(icon: "lungs.fill", name: "Blood Oxygen", purpose: "Health monitoring")
            }
            
            Divider()
                .overlay(PulseTheme.border.opacity(0.5))
                .padding(.vertical, PulseTheme.spacingXS)
            
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(PulseTheme.statusGood)
                
                Text("All data stays on your device. We never collect or share personal health information.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
                    .lineSpacing(2)
            }
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                .fill(PulseTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    private func dataTypeRow(icon: String, name: String, purpose: String) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 16)
            
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PulseTheme.textSecondary)
            
            Text("•")
                .font(.system(size: 11))
                .foregroundStyle(PulseTheme.textTertiary)
            
            Text(purpose)
                .font(.system(size: 11))
                .foregroundStyle(PulseTheme.textTertiary)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Localized Strings

private extension String {
    static let enableHealthAccess = String(localized: "Enable Health Access")
    static let healthPermissionMessage = String(localized: "Pulse Watch needs access to your health data to provide personalized insights, recovery scores, and training recommendations.")
    static let openSettings = String(localized: "Open Settings")
    static let learnMore = String(localized: "Learn More")
    static let whatWeAccess = String(localized: "What we access:")
    static let heartRateHRV = String(localized: "Heart Rate & HRV")
    static let recoveryAnalysis = String(localized: "Recovery analysis")
    static let stepsActivity = String(localized: "Steps & Activity")
    static let dailyActivityTracking = String(localized: "Daily activity tracking")
    static let sleepData = String(localized: "Sleep Data")
    static let recoveryInsights = String(localized: "Recovery insights")
    static let bloodOxygen = String(localized: "Blood Oxygen")
    static let healthMonitoring = String(localized: "Health monitoring")
    static let dataPrivacyMessage = String(localized: "All data stays on your device. We never collect or share personal health information.")
}

#Preview {
    ScrollView {
        HealthKitPermissionGuideView()
            .padding()
    }
    .background(PulseTheme.background)
    .preferredColorScheme(.dark)
}