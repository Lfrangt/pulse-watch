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
                DS.Color.bg.ignoresSafeArea()

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
                            .font(DS.Typography.title2)
                            .foregroundStyle(DS.Color.inkDim)
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
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "dumbbell.fill")
                .font(DS.Typography.display3)
                .foregroundStyle(DS.Color.accent)

            VStack(spacing: DS.Spacing.s) {
                Text("You're at the Gym 💪")
                    .font(DS.Typography.title1.weight(.bold))
                    .foregroundStyle(DS.Color.ink)
                Text("Ready to start training?")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(DS.Color.inkMid)
            }

            // Readiness badge
            HStack(spacing: DS.Spacing.m) {
                readinessBadge(label: "Readiness", score: readinessScore)
                readinessBadge(label: "Strain", score: strainScore)
            }
            .padding(.horizontal, DS.Spacing.l)

            Spacer()

            VStack(spacing: DS.Spacing.m) {
                Button {
                    withAnimation { step = .selectMuscle }
                } label: {
                    Text("Start Training")
                        .font(PulseTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(DS.Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.m)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.inner).fill(DS.Color.accent))
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Text("Maybe Later")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(DS.Color.inkDim)
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    private func readinessBadge(label: String, score: Int) -> some View {
        let color = PulseTheme.statusColor(for: score)
        return VStack(spacing: 4) {
            Text("\(score)")
                .font(DS.Typography.title1.weight(.bold))
                .foregroundStyle(DS.Color.ink)
            Text(label)
                .font(PulseTheme.captionFont)
                .foregroundStyle(DS.Color.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).stroke(color.opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - Step 2: Select Muscle Groups

    private var selectMuscleStep: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer().frame(height: 40)

            Text("What are you training today?")
                .font(DS.Typography.title1.weight(.bold))
                .foregroundStyle(DS.Color.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(MuscleGroup.allCases) { group in
                    let selected = selectedGroups.contains(group)
                    Button {
                        if selected { selectedGroups.remove(group) }
                        else { selectedGroups.insert(group) }
                    } label: {
                        VStack(spacing: 6) {
                            Text(group.emoji)
                                .font(DS.Typography.title1)
                            Text(group.label)
                                .font(DS.Typography.caption)
                                .foregroundStyle(selected ? group.color : DS.Color.inkDim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.card)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? group.color.opacity(0.15) : DS.Color.bgElev)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected ? group.color.opacity(0.5) : DS.Color.line.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.m)

            Spacer()

            Button {
                generatePlan()
                withAnimation { step = .plan }
            } label: {
                Text(String(format: String(localized: "Continue (%d selected)"), selectedGroups.count))
                    .font(PulseTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.m)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.inner)
                        .fill(selectedGroups.isEmpty ? DS.Color.inkDim : DS.Color.accent))
            }
            .buttonStyle(.plain)
            .disabled(selectedGroups.isEmpty)
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Step 3: AI Training Plan

    private var planStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Training Plan")
                        .font(DS.Typography.title1.weight(.bold))
                        .foregroundStyle(DS.Color.ink)
                    if let plan = generatedPlan {
                        HStack(spacing: 8) {
                            Text(plan.intensity.rawValue)
                                .font(PulseTheme.captionFont.weight(.medium))
                                .foregroundStyle(intensityColor(plan.intensity))
                            Text("·")
                                .foregroundStyle(DS.Color.inkDim)
                            Text(String(format: String(localized: "~%d min"), plan.estimatedMinutes))
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(DS.Color.inkDim)
                        }
                        Text(plan.reason)
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(DS.Color.inkMid)
                    }
                }
                .padding(.horizontal, DS.Spacing.m)
                .padding(.top, DS.Spacing.l)

                // Exercises
                if let plan = generatedPlan {
                    VStack(spacing: DS.Spacing.s) {
                        ForEach(plan.exercises.indices, id: \.self) { i in
                            exerciseRow(plan.exercises[i], index: i + 1)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.m)
                }

                Spacer(minLength: 40)

                // Buttons
                VStack(spacing: DS.Spacing.m) {
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
                        .foregroundStyle(DS.Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.m)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.inner).fill(DS.Color.accent))
                    }
                    .buttonStyle(.plain)

                    Button { dismiss() } label: {
                        Text("Save Plan & Close")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(DS.Color.accent)
                    }
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.bottom, DS.Spacing.xxl)
            }
        }
    }

    private func exerciseRow(_ exercise: SuggestedExercise, index: Int) -> some View {
        HStack(spacing: DS.Spacing.m) {
            Text("\(index)")
                .font(DS.Typography.bodyS.weight(.bold))
                .foregroundStyle(DS.Color.accent)
                .frame(width: DS.Spacing.xl - DS.Spacing.xs, height: DS.Spacing.xl - DS.Spacing.xs)
                .background(Circle().fill(DS.Color.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(PulseTheme.bodyFont.weight(.medium))
                    .foregroundStyle(DS.Color.ink)
                HStack(spacing: 8) {
                    Text("\(exercise.sets) × \(exercise.reps)")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(DS.Color.inkMid)
                    if let w = exercise.suggestedWeight {
                        Text(String(format: "%.0f kg", w))
                            .font(PulseTheme.captionFont.weight(.medium))
                            .foregroundStyle(DS.Color.accent)
                    }
                }
            }
            Spacer()
        }
        .padding(DS.Spacing.m)
        .background(RoundedRectangle(cornerRadius: DS.Radius.inner).fill(DS.Color.bgElev))
    }

    // MARK: - Step 4: Training Timer

    private var trainingStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            // Timer display
            VStack(spacing: 8) {
                Text(formatTime(elapsedSeconds))
                    .font(DS.Typography.display3)
                    .foregroundStyle(DS.Color.ink)
                    .monospacedDigit()
                Text("Training in progress")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(DS.Color.inkDim)
            }

            // Selected groups reminder
            HStack(spacing: 8) {
                ForEach(Array(selectedGroups).prefix(4)) { g in
                    Text(g.emoji + " " + g.label)
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(g.color)
                        .padding(.horizontal, DS.Spacing.s)
                        .padding(.vertical, DS.Spacing.xs)
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
                .foregroundStyle(DS.Color.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
                .background(RoundedRectangle(cornerRadius: DS.Radius.inner).fill(PulseTheme.activityAccent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Step 5: Complete

    private var completeStep: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.display3)
                .foregroundStyle(DS.Color.good)

            VStack(spacing: DS.Spacing.s) {
                Text("Workout Complete! 🎉")
                    .font(DS.Typography.title1.weight(.bold))
                    .foregroundStyle(DS.Color.ink)
                Text(formatTime(elapsedSeconds))
                    .font(DS.Typography.title1.weight(.bold))
                    .foregroundStyle(DS.Color.accent)
            }

            // Strength prompt (if relevant muscles)
            let hasStrengthMuscle = selectedGroups.contains(.chest) || selectedGroups.contains(.legs) || selectedGroups.contains(.back)
            if hasStrengthMuscle {
                VStack(spacing: 8) {
                    Text("Did you hit any PRs today?")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(DS.Color.inkMid)
                    Text("Record your lifts in Strength tracking")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(DS.Color.inkDim)
                }
            }

            Spacer()

            Button {
                saveWorkoutRecord()
                dismiss()
            } label: {
                Text("Done")
                    .font(PulseTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.m)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.inner).fill(DS.Color.accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.xxl)
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
        case .moderate: return DS.Color.warn
        case .light:    return DS.Color.good
        }
    }
}
