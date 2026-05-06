import SwiftUI

// MARK: - Launch Screen
// Dark atmospheric background matching the app's teal-accented dark theme

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            PulseTheme.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    PulseTheme.accentTeal.opacity(0.06),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            .ignoresSafeArea()

            VStack(spacing: PulseTheme.spacingS) {
                Text("Pulse")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text("by Abundra")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
