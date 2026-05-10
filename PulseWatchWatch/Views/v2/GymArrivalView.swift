import SwiftUI
import WatchKit

/// Shown when user arrives at gym — haptic + prompt
struct GymArrivalView: View {

    let trainingPlan: TrainingPlan?
    var onStartWorkout: () -> Void = {}
    var onDismiss: () -> Void = {}

    @State private var appeared = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Gym icon with pulse ring
                ZStack {
                    // Pulsing ring
                    Circle()
                        .stroke(DS.Color.accent.opacity(0.3), lineWidth: 2)
                        .frame(width: DS.Spacing.xl + DS.Spacing.l + DS.Spacing.xs, height: DS.Spacing.xl + DS.Spacing.l + DS.Spacing.xs)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - Double(pulseScale))

                    // Icon
                    ZStack {
                        Circle()
                            .fill(DS.Color.accent.opacity(0.15))
                            .frame(width: DS.Spacing.xxl + DS.Spacing.s, height: DS.Spacing.xxl + DS.Spacing.s)

                        Image(systemName: "dumbbell.fill")
                            .font(DS.Typography.title2)
                            .foregroundStyle(DS.Color.accent)
                    }
                    .scaleEffect(appeared ? 1.0 : 0.5)
                }

                Text("At the Gym?")
                    .font(DS.Typography.bodyL.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)

                if let plan = trainingPlan {
                    VStack(spacing: 4) {
                        Text("Suggested: \(localizedGroup(plan.targetMuscleGroup))")
                            .font(DS.Typography.bodyS.weight(.medium))
                            .foregroundStyle(DS.Color.inkMid)

                        if !plan.reason.isEmpty {
                            Text(plan.reason)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Color.inkDim)
                        }
                    }
                }

                // Start button
                Button(action: onStartWorkout) {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(DS.Typography.bodyS.weight(.semibold))
                        .foregroundStyle(DS.Color.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DS.Color.accent)
                                
                        )
                }
                .buttonStyle(.plain)

                // Dismiss
                Button("Skip", action: onDismiss)
                    .font(DS.Typography.bodyS)
                    .foregroundStyle(DS.Color.inkDim)
            }
            .padding(.horizontal, DS.Spacing.s)
        }
        .containerBackground(
            LinearGradient(
                colors: [DS.Color.bg, DS.Color.bgElev],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigation
        )
        .onAppear {
            // Haptic
            WKInterfaceDevice.current().play(.notification)

            // Entry animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                appeared = true
            }

            // Pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseScale = 1.8
            }
        }
    }

    private func localizedGroup(_ group: String) -> String {
        switch group {
        case "chest": return String(localized: "Chest")
        case "back": return String(localized: "Back")
        case "legs": return String(localized: "Legs")
        case "shoulders": return String(localized: "Shoulders")
        default: return group
        }
    }
}

#Preview {
    GymArrivalView(
        trainingPlan: TrainingPlan(
            targetMuscleGroup: "chest",
            daysSinceLastTrained: 3,
            suggestedExercises: [],
            intensity: .heavy,
            reason: String(localized: "Last chest day was 3 days ago")
        )
    )
}
