import SwiftUI
import SwiftData
import Combine

/// 健身房到达 → 选部位 → AI 训练计划 → 开始计时 → 完成记录
/// 4 步完整智能健身启动流程
struct GymArrivalFlowView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutHistoryEntry.startDate, order: .reverse)
    private var recentWorkouts: [WorkoutHistoryEntry]

    @AppStorage("pulse.user.weightKg") private var bodyweight: Double = 0

    // Flow state
    @State private var step: FlowStep = .welcome
    @State private var selectedGroups: Set<MuscleGroup> = []
    @State private var generatedPlan: GeneratedPlan?
    @State private var timerRunning = false
    @State private var elapsedSeconds: Int = 0
    @State private var showStrengthPrompt = false

    // External context
    var readinessScore: Int
    var strainScore: Int

    enum FlowStep {
        case welcome
        case selectMuscle
        case plan
        case training
        case complete
    }

    struct GeneratedPlan {
        let intensity: TrainingPlan.Intensity
        let exercises: [SuggestedExercise]
        let estimatedMinutes: Int
        let reason: String
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PulseTheme.background.ignoresSafeArea()

                switch step {
                case .welcome:     welcomeStep
                case .selectMuscle: selectMuscleStep
                case .plan:        planStep
                case .training:    trainingStep
                case .complete:    completeStep
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                guard timerRunning else { return }
                elapsedSeconds += 1
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: PulseTheme.spacingXL) {
            Spacer()

            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundStyle(PulseTheme.accent)

            VStack(spacing: PulseTheme.spacingS) {
                Text("You're at the Gym 💪")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text("Ready to start training?")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
            }

            // Readiness badge
            HStack(spacing: PulseTheme.spacingM) {
                readinessBadge(label: "Readiness", score: readinessScore)
                readinessBadge(label: "Strain", score: strainScore)
            }
            .padding(.horizontal, PulseTheme.spacingL)

            Spacer()

            VStack(spacing: PulseTheme.spacingM) {
                Button {
                    withAnimation { step = .selectMuscle }
                } label: {
                    Text("Start Training")
                        .font(PulseTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(PulseTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: PulseTheme.radiusM).fill(PulseTheme.accent))
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Text("Maybe Later")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            .padding(.horizontal, PulseTheme.spacingL)
            .padding(.bottom, 40)
        }
    }

    private func readinessBadge(label: String, score: Int) -> some View {
        let color = PulseTheme.statusColor(for: score)
        return VStack(spacing: 4) {
            Text("\(score)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
            Text(label)
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: PulseTheme.radiusM).stroke(color.opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - Step 2: Select Muscle Groups

    private var selectMuscleStep: some View {
        VStack(spacing: PulseTheme.spacingL) {
            Spacer().frame(height: 40)

            Text("What are you training today?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(PulseTheme.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(MuscleGroup.allCases) { group in
                    let selected = selectedGroups.contains(group)
                    Button {
                        if selected { selectedGroups.remove(group) }
                        else { selectedGroups.insert(group) }
                    } label: {
                        VStack(spacing: 6) {
                            Text(group.emoji)
                                .font(.system(size: 28))
                            Text(group.label)
                                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? group.color : PulseTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? group.color.opacity(0.15) : PulseTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected ? group.color.opacity(0.5) : PulseTheme.border.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PulseTheme.spacingM)

            Spacer()

            Button {
                generatePlan()
                withAnimation { step = .plan }
            } label: {
                Text(String(format: String(localized: "Continue (%d selected)"), selectedGroups.count))
                    .font(PulseTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: PulseTheme.radiusM)
                        .fill(selectedGroups.isEmpty ? PulseTheme.textTertiary : PulseTheme.accent))
            }
            .buttonStyle(.plain)
            .disabled(selectedGroups.isEmpty)
            .padding(.horizontal, PulseTheme.spacingL)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 3: AI Training Plan

    private var planStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseTheme.spacingL) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Training Plan")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(PulseTheme.textPrimary)
                    if let plan = generatedPlan {
                        HStack(spacing: 8) {
                            Text(plan.intensity.rawValue)
                                .font(PulseTheme.captionFont.weight(.medium))
                                .foregroundStyle(intensityColor(plan.intensity))
                            Text("·")
                                .foregroundStyle(PulseTheme.textTertiary)
                            Text(String(format: String(localized: "~%d min"), plan.estimatedMinutes))
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                        Text(plan.reason)
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textSecondary)
                    }
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, 20)

                // Exercises
                if let plan = generatedPlan {
                    VStack(spacing: PulseTheme.spacingS) {
                        ForEach(plan.exercises.indices, id: \.self) { i in
                            exerciseRow(plan.exercises[i], index: i + 1)
                        }
                    }
                    .padding(.horizontal, PulseTheme.spacingM)
                }

                Spacer(minLength: 40)

                // Buttons
                VStack(spacing: PulseTheme.spacingM) {
                    Button {
                        elapsedSeconds = 0
                        timerRunning = true
                        withAnimation { step = .training }
                    } label: {
                        HStack {
                            Image(systemName: "timer")
                            Text("Start Timer")
                        }
                        .font(PulseTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(PulseTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: PulseTheme.radiusM).fill(PulseTheme.accent))
                    }
                    .buttonStyle(.plain)

                    Button { dismiss() } label: {
                        Text("Save Plan & Close")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.accent)
                    }
                }
                .padding(.horizontal, PulseTheme.spacingL)
                .padding(.bottom, 40)
            }
        }
    }

    private func exerciseRow(_ exercise: SuggestedExercise, index: Int) -> some View {
        HStack(spacing: PulseTheme.spacingM) {
            Text("\(index)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(PulseTheme.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(PulseTheme.bodyFont.weight(.medium))
                    .foregroundStyle(PulseTheme.textPrimary)
                HStack(spacing: 8) {
                    Text("\(exercise.sets) × \(exercise.reps)")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                    if let w = exercise.suggestedWeight {
                        Text(String(format: "%.0f kg", w))
                            .font(PulseTheme.captionFont.weight(.medium))
                            .foregroundStyle(PulseTheme.accent)
                    }
                }
            }
            Spacer()
        }
        .padding(PulseTheme.spacingM)
        .background(RoundedRectangle(cornerRadius: PulseTheme.radiusM).fill(PulseTheme.cardBackground))
    }

    // MARK: - Step 4: Training Timer

    private var trainingStep: some View {
        VStack(spacing: PulseTheme.spacingXL) {
            Spacer()

            // Timer display
            VStack(spacing: 8) {
                Text(formatTime(elapsedSeconds))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .monospacedDigit()
                Text("Training in progress")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            // Selected groups reminder
            HStack(spacing: 8) {
                ForEach(Array(selectedGroups).prefix(4)) { g in
                    Text(g.emoji + " " + g.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(g.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(g.color.opacity(0.12)))
                }
            }

            Spacer()

            // End button
            Button {
                timerRunning = false
                withAnimation { step = .complete }
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("End Workout")
                }
                .font(PulseTheme.bodyFont.weight(.semibold))
                .foregroundStyle(PulseTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: PulseTheme.radiusM).fill(PulseTheme.activityAccent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, PulseTheme.spacingL)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 5: Complete

    private var completeStep: some View {
        VStack(spacing: PulseTheme.spacingXL) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(PulseTheme.statusGood)

            VStack(spacing: PulseTheme.spacingS) {
                Text("Workout Complete! 🎉")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(formatTime(elapsedSeconds))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
            }

            // Strength prompt (if relevant muscles)
            let hasStrengthMuscle = selectedGroups.contains(.chest) || selectedGroups.contains(.legs) || selectedGroups.contains(.back)
            if hasStrengthMuscle {
                VStack(spacing: 8) {
                    Text("Did you hit any PRs today?")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                    Text("Record your lifts in Strength tracking")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            Spacer()

            Button {
                saveWorkoutRecord()
                dismiss()
            } label: {
                Text("Done")
                    .font(PulseTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: PulseTheme.radiusM).fill(PulseTheme.accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, PulseTheme.spacingL)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Plan Generation

    private func generatePlan() {
        let intensity: TrainingPlan.Intensity
        switch readinessScore {
        case 70...: intensity = .heavy
        case 50..<70: intensity = .moderate
        default: intensity = .light
        }

        var exercises: [SuggestedExercise] = []
        let sets = intensity == .heavy ? 4 : 3
        let reps = intensity == .heavy ? 8 : (intensity == .moderate ? 10 : 12)

        for group in selectedGroups.sorted(by: { $0.rawValue < $1.rawValue }) {
            exercises.append(contentsOf: exercisesForGroup(group, sets: sets, reps: reps))
        }

        // 天数分析
        _ = selectedGroups.map(\.label).joined(separator: " + ")
        var reasons: [String] = []
        for group in selectedGroups {
            let lastWorkout = recentWorkouts.first { $0.muscleGroupTags.contains(group) }
            if let last = lastWorkout {
                let days = Calendar.current.dateComponents([.day], from: last.startDate, to: .now).day ?? 0
                if days > 0 {
                    reasons.append(String(format: String(localized: "Last %@ was %d days ago"), group.label, days))
                }
            }
        }
        let reason = reasons.first
            ?? String(format: String(localized: "Readiness %d — %@ intensity recommended"), readinessScore, intensity.rawValue)

        generatedPlan = GeneratedPlan(
            intensity: intensity,
            exercises: exercises,
            estimatedMinutes: exercises.count * 8 + 10,
            reason: reason
        )
    }

    private func exercisesForGroup(_ group: MuscleGroup, sets: Int, reps: Int) -> [SuggestedExercise] {
        switch group {
        case .chest:
            return [
                SuggestedExercise(name: String(localized: "Flat Bench Press"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Incline Dumbbell Press"), sets: 3, reps: 10, suggestedWeight: nil),
            ]
        case .back:
            return [
                SuggestedExercise(name: String(localized: "Pull-up"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Barbell Row"), sets: 3, reps: 10, suggestedWeight: nil),
            ]
        case .legs:
            return [
                SuggestedExercise(name: String(localized: "Squat"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Romanian Deadlift"), sets: 3, reps: 10, suggestedWeight: nil),
            ]
        case .shoulders:
            return [
                SuggestedExercise(name: String(localized: "Dumbbell Press"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Lateral Raise"), sets: 3, reps: 15, suggestedWeight: nil),
            ]
        case .arms:
            return [
                SuggestedExercise(name: String(localized: "Barbell Curl"), sets: 3, reps: 12, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Tricep Pushdown"), sets: 3, reps: 12, suggestedWeight: nil),
            ]
        case .core:
            return [
                SuggestedExercise(name: String(localized: "Plank"), sets: 3, reps: 60, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Cable Crunch"), sets: 3, reps: 15, suggestedWeight: nil),
            ]
        case .fullBody:
            return [
                SuggestedExercise(name: String(localized: "Squat"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Flat Bench Press"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Barbell Row"), sets: 3, reps: 10, suggestedWeight: nil),
            ]
        case .cardio:
            return [
                SuggestedExercise(name: String(localized: "Treadmill Run"), sets: 1, reps: 30, suggestedWeight: nil),
            ]
        }
    }

    // MARK: - Timer (declarative via .onReceive in body)

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Save

    private func saveWorkoutRecord() {
        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: "gym-flow-\(UUID().uuidString)",
            activityType: 58,  // Strength Training
            startDate: Date().addingTimeInterval(-Double(elapsedSeconds)),
            endDate: Date(),
            durationSeconds: Double(elapsedSeconds),
            sourceName: String(localized: "Gym Session"),
            isManual: true
        )
        entry.muscleGroupTags = Array(selectedGroups)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func intensityColor(_ intensity: TrainingPlan.Intensity) -> Color {
        switch intensity {
        case .heavy:    return PulseTheme.activityAccent
        case .moderate: return PulseTheme.statusModerate
        case .light:    return PulseTheme.statusGood
        }
    }
}
