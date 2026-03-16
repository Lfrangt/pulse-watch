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
                        .stroke(Color(hex: "C9A96E").opacity(0.3), lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - Double(pulseScale))

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: "C9A96E").opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(hex: "C9A96E"))
                    }
                    .scaleEffect(appeared ? 1.0 : 0.5)
                }

                Text("At the Gym?")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "F5F0EB"))

                if let plan = trainingPlan {
                    VStack(spacing: 4) {
                        Text("建议练\(localizedGroup(plan.targetMuscleGroup))")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "9A938C"))

                        if !plan.reason.isEmpty {
                            Text(plan.reason)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Color(hex: "5C564F"))
                        }
                    }
                }

                // Start button
                Button(action: onStartWorkout) {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "0D0C0B"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hex: "C9A96E"))
                                .shadow(color: Color(hex: "C9A96E").opacity(0.3), radius: 8, y: 3)
                        )
                }
                .buttonStyle(.plain)

                // Dismiss
                Button("Skip", action: onDismiss)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color(hex: "5C564F"))
            }
            .padding(.horizontal, 8)
        }
        .containerBackground(
            LinearGradient(
                colors: [Color(hex: "0D0C0B"), Color(hex: "111010")],
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
