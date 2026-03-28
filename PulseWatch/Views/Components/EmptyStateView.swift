import SwiftUI

/// Reusable empty state placeholder — consistent across all detail views
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: PulseTheme.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(PulseTheme.textTertiary)
                .accessibilityHidden(true)

            VStack(spacing: PulseTheme.spacingXS) {
                Text(title)
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textSecondary)

                Text(message)
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseTheme.spacingXL)
        .accessibilityElement(children: .combine)
    }
}
