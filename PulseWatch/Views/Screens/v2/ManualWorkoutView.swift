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
                VStack(spacing: DS.Spacing.l) {
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
                .padding(.horizontal, DS.Spacing.m)
                .padding(.top, DS.Spacing.m)
            }
            .background(DS.Color.bg)
            .navigationTitle(String(localized: "Add Workout"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .foregroundStyle(DS.Color.inkMid)
                }
            }
        }
    }

    // MARK: - 运动类型

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Workout Type")
                .font(DS.Typography.bodyL)
                .foregroundStyle(DS.Color.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(WorkoutType.allCases) { type in
                    let selected = selectedType == type
                    Button {
                        selectedType = type
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(DS.Typography.bodyL)
                                .foregroundStyle(selected ? DS.Color.accent : DS.Color.inkDim)
                            Text(type.label)
                                .font(DS.Typography.mono)
                                .foregroundStyle(selected ? DS.Color.ink : DS.Color.inkDim)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? DS.Color.accent.opacity(0.12) : DS.Color.bgElev)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selected ? DS.Color.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .dsCard()
    }

    // MARK: - 日期

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Date & Time")
                .font(DS.Typography.bodyL)
                .foregroundStyle(DS.Color.ink)

            DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .tint(DS.Color.accent)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .dsCard()
    }

    // MARK: - 时长

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                Text("Duration")
                    .font(DS.Typography.bodyL)
                    .foregroundStyle(DS.Color.ink)
                Spacer()
                Text(String(format: String(localized: "%d min"), durationMinutes))
                    .font(DS.Typography.title2.weight(.bold))
                    .foregroundStyle(DS.Color.accent)
            }

            Slider(value: Binding(
                get: { Double(durationMinutes) },
                set: { durationMinutes = Int($0) }
            ), in: 5...180, step: 5)
            .tint(DS.Color.accent)
        }
        .dsCard()
    }

    // MARK: - 卡路里

    private var caloriesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Calories (optional)")
                .font(DS.Typography.bodyL)
                .foregroundStyle(DS.Color.ink)

            TextField("e.g. 350", text: $calories)
                .keyboardType(.numberPad)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.ink)
                .padding(DS.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                        .fill(DS.Color.bgElev)
                )
        }
        .dsCard()
    }

    // MARK: - 肌群

    private var muscleGroupSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Muscle Groups")
                .font(DS.Typography.bodyL)
                .foregroundStyle(DS.Color.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(MuscleGroup.allCases) { group in
                    let selected = selectedMuscleGroups.contains(group)
                    Button {
                        if selected { selectedMuscleGroups.remove(group) }
                        else { selectedMuscleGroups.insert(group) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(group.emoji)
                                .font(DS.Typography.body)
                            Text(group.label)
                                .font(DS.Typography.mono)
                                .foregroundStyle(selected ? group.color : DS.Color.inkDim)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? group.color.opacity(0.15) : DS.Color.bgElev)
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
        .dsCard()
    }

    // MARK: - 备注

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Notes (optional)")
                .font(DS.Typography.bodyL)
                .foregroundStyle(DS.Color.ink)

            TextField(String(localized: "How did it feel?"), text: $notes, axis: .vertical)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.ink)
                .lineLimit(3...6)
                .padding(DS.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                        .fill(DS.Color.bgElev)
                )
        }
        .dsCard()
    }

    // MARK: - 保存

    private var saveButton: some View {
        Button {
            saveWorkout()
            dismiss()
        } label: {
            Text("Save Workout")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(DS.Color.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                        .fill(DS.Color.accent)
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
