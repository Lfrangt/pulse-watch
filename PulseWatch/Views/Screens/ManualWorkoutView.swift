import SwiftUI
import SwiftData
import os

/// 手动添加训练记录页面
struct ManualWorkoutView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "ManualWorkoutView")

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var selectedType: WorkoutType = .strength
    @State private var date = Date()
    @State private var durationMinutes: Int = 45
    @State private var calories: String = ""
    @State private var notes: String = ""
    @State private var selectedMuscleGroups: Set<MuscleGroup> = []

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseTheme.spacingL) {
                    // 运动类型
                    typeSection
                    // 日期时间
                    dateSection
                    // 时长
                    durationSection
                    // 卡路里
                    caloriesSection
                    // 肌群
                    muscleGroupSection
                    // 备注
                    notesSection
                    // 保存
                    saveButton

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingM)
            }
            .background(PulseTheme.background)
            .navigationTitle(String(localized: "Add Workout"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 运动类型

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Workout Type")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(WorkoutType.allCases) { type in
                    let selected = selectedType == type
                    Button {
                        selectedType = type
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(selected ? PulseTheme.accent : PulseTheme.textTertiary)
                            Text(type.label)
                                .font(.system(size: 10, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? PulseTheme.textPrimary : PulseTheme.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? PulseTheme.accent.opacity(0.12) : PulseTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selected ? PulseTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 日期

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Date & Time")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .tint(PulseTheme.accent)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .pulseCard()
    }

    // MARK: - 时长

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack {
                Text("Duration")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
                Text(String(format: String(localized: "%d min"), durationMinutes))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
            }

            Slider(value: Binding(
                get: { Double(durationMinutes) },
                set: { durationMinutes = Int($0) }
            ), in: 5...180, step: 5)
            .tint(PulseTheme.accent)
        }
        .pulseCard()
    }

    // MARK: - 卡路里

    private var caloriesSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Calories (optional)")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            TextField("e.g. 350", text: $calories)
                .keyboardType(.numberPad)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .padding(PulseTheme.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                        .fill(PulseTheme.surface)
                )
        }
        .pulseCard()
    }

    // MARK: - 肌群

    private var muscleGroupSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Muscle Groups")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(MuscleGroup.allCases) { group in
                    let selected = selectedMuscleGroups.contains(group)
                    Button {
                        if selected { selectedMuscleGroups.remove(group) }
                        else { selectedMuscleGroups.insert(group) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(group.emoji)
                                .font(.system(size: 16))
                            Text(group.label)
                                .font(.system(size: 10, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? group.color : PulseTheme.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? group.color.opacity(0.15) : PulseTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selected ? group.color.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 备注

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Notes (optional)")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            TextField(String(localized: "How did it feel?"), text: $notes, axis: .vertical)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .lineLimit(3...6)
                .padding(PulseTheme.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                        .fill(PulseTheme.surface)
                )
        }
        .pulseCard()
    }

    // MARK: - 保存

    private var saveButton: some View {
        Button {
            saveWorkout()
            dismiss()
        } label: {
            Text("Save Workout")
                .font(PulseTheme.bodyFont.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .fill(PulseTheme.accent)
                )
        }
        .buttonStyle(.plain)
    }

    private func saveWorkout() {
        let durationSec = Double(durationMinutes) * 60
        let endDate = date.addingTimeInterval(durationSec)
        let cal = Double(calories) ?? nil

        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: "manual-\(UUID().uuidString)",
            activityType: selectedType.hkActivityType,
            startDate: date,
            endDate: endDate,
            durationSeconds: durationSec,
            totalCalories: cal,
            sourceName: String(localized: "手动记录"),
            isManual: true,
            notes: notes.isEmpty ? nil : notes
        )
        entry.muscleGroupTags = Array(selectedMuscleGroups)
        modelContext.insert(entry)
        do {
            try modelContext.save()
            logger.info("WorkoutHistoryEntry saved: \(entry.activityName, privacy: .public), uuid=\(entry.hkWorkoutUUID ?? "nil", privacy: .public)")
        } catch {
            logger.error("Save failed: \(error)")
        }
    }
}

// MARK: - Workout Type enum

enum WorkoutType: String, CaseIterable, Identifiable {
    case running = "running"
    case cycling = "cycling"
    case strength = "strength"
    case swimming = "swimming"
    case yoga = "yoga"
    case basketball = "basketball"
    case soccer = "soccer"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .running:    return String(localized: "Running")
        case .cycling:    return String(localized: "Cycling")
        case .strength:   return String(localized: "Strength")
        case .swimming:   return String(localized: "Swimming")
        case .yoga:       return String(localized: "Yoga")
        case .basketball: return String(localized: "Basketball")
        case .soccer:     return String(localized: "Soccer")
        case .other:      return String(localized: "Other")
        }
    }

    var icon: String {
        switch self {
        case .running:    return "figure.run"
        case .cycling:    return "figure.outdoor.cycle"
        case .strength:   return "dumbbell.fill"
        case .swimming:   return "figure.pool.swim"
        case .yoga:       return "figure.yoga"
        case .basketball: return "basketball.fill"
        case .soccer:     return "soccerball"
        case .other:      return "figure.mixed.cardio"
        }
    }

    var hkActivityType: Int {
        switch self {
        case .running:    return 37
        case .cycling:    return 13
        case .strength:   return 58
        case .swimming:   return 46
        case .yoga:       return 50
        case .basketball: return 4
        case .soccer:     return 43
        case .other:      return 0
        }
    }
}
