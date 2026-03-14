import SwiftUI

/// Shown when user arrives at gym — haptic + prompt
struct GymArrivalView: View {
    
    let trainingPlan: TrainingPlan?
    var onStartWorkout: () -> Void = {}
    var onDismiss: () -> Void = {}
    
    @State private var appeared = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Gym icon with pulse animation
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: "C9A96E"))
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)
                
                Text("在健身房？")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "F5F0EB"))
                
                if let plan = trainingPlan {
                    Text("建议练\(localizedGroup(plan.targetMuscleGroup))")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color(hex: "8A8580"))
                    
                    Text(plan.reason)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color(hex: "5A5550"))
                }
                
                // Start button
                Button(action: onStartWorkout) {
                    Label("开始训练", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "0F0F0F"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "C9A96E"))
                        )
                }
                .buttonStyle(.plain)
                
                // Dismiss
                Button("不了", action: onDismiss)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color(hex: "5A5550"))
            }
            .padding(.horizontal, 8)
        }
        .containerBackground(Color(hex: "0F0F0F").gradient, for: .navigation)
        .onAppear {
            appeared = true
            // Trigger haptic
            WKInterfaceDevice.current().play(.notification)
        }
    }
    
    private func localizedGroup(_ group: String) -> String {
        switch group {
        case "chest": return "胸"
        case "back": return "背"
        case "legs": return "腿"
        case "shoulders": return "肩"
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
            reason: "上次练胸是3天前"
        )
    )
}
