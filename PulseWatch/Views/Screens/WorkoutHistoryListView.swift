import SwiftUI
import SwiftData

/// 训练历史列表页 — 按日期倒序展示所有持久化的训练记录
struct WorkoutHistoryListView: View {

    @Query(sort: \WorkoutHistoryEntry.startDate, order: .reverse)
    private var allEntries: [WorkoutHistoryEntry]

    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false
    @State private var entryToDelete: WorkoutHistoryEntry?
    @State private var entryToShare: WorkoutHistoryEntry?
    @State private var showShareScreen = false
    @State private var showAddWorkout = false

    var body: some View {
        NavigationStack {
            Group {
                if allEntries.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .background(DS.Color.bg)
            .navigationTitle(String(localized: "Workout History"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddWorkout = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(DS.Typography.bodyL)
                            .foregroundStyle(DS.Color.accent)
                    }
                    .accessibilityLabel(String(localized: "Add Workout"))
                }
            }
            .sheet(isPresented: $showAddWorkout) {
                ManualWorkoutView()
                    .preferredColorScheme(.dark)
            }
            .alert(
                String(localized: "Delete Workout"),
                isPresented: $showDeleteConfirm,
                presenting: entryToDelete
            ) { entry in
                Button(String(localized: "Delete"), role: .destructive) {
                    withAnimation {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: { entry in
                Text("Delete \(entry.activityName) on \(formatDate(entry.startDate))?")
            }
            .fullScreenCover(isPresented: $showShareScreen) {
                if let entry = entryToShare {
                    WorkoutShareScreen(entry: entry)
                        .preferredColorScheme(.dark)
                }
            }
        }
    }

    // MARK: - 训练列表

    private var workoutList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: DS.Spacing.s) {
                // 统计概览
                summaryHeader
                    .staggered(index: 0)

                // 按月份分组
                ForEach(Array(groupedByMonth.enumerated()), id: \.element.key) { sectionIndex, section in
                    Section {
                        ForEach(Array(section.entries.enumerated()), id: \.element.id) { rowIndex, entry in
                            NavigationLink {
                                WorkoutHistoryDetailView(entry: entry)
                                    .preferredColorScheme(.dark)
                            } label: {
                                workoutRow(entry)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    entryToShare = entry
                                    showShareScreen = true
                                } label: {
                                    Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
                                }

                                Button(role: .destructive) {
                                    entryToDelete = entry
                                    showDeleteConfirm = true
                                } label: {
                                    Label(String(localized: "Delete"), systemImage: "trash")
                                }
                            }
                            .staggered(index: rowIndex + 1)
                        }
                    } header: {
                        Text(section.key)
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(DS.Color.inkDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, sectionIndex == 0 ? 0 : DS.Spacing.s)
                            .padding(.leading, DS.Spacing.xs)
                    }
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, DS.Spacing.m)
        }
    }

    // MARK: - 统计概览

    private var summaryHeader: some View {
        let totalWorkouts = allEntries.count
        let totalMinutes = allEntries.reduce(0) { $0 + $1.durationMinutes }
        let totalCalories = allEntries.compactMap(\.totalCalories).reduce(0, +)

        return HStack(spacing: 0) {
            summaryItem(
                value: "\(totalWorkouts)",
                label: String(localized: "Workouts"),
                icon: "figure.mixed.cardio",
                color: DS.Color.accent
            )

            Rectangle()
                .fill(DS.Color.line.opacity(0.5))
                .frame(width: 0.5, height: 40)

            summaryItem(
                value: formatDuration(totalMinutes),
                label: String(localized: "Total Time"),
                icon: "clock.fill",
                color: DS.Color.warn
            )

            Rectangle()
                .fill(DS.Color.line.opacity(0.5))
                .frame(width: 0.5, height: 40)

            summaryItem(
                value: totalCalories >= 1000 ? String(format: "%.1fk", totalCalories / 1000) : "\(Int(totalCalories))",
                label: String(localized: "Calories"),
                icon: "flame.fill",
                color: DS.Color.bad
            )
        }
        .pulseCard()
    }

    private func summaryItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.bodyS)
                .foregroundStyle(color)

            Text(value)
                .font(DS.Typography.bodyL.weight(.semibold))
                .foregroundStyle(DS.Color.ink)

            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkDim)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 训练行

    private func workoutRow(_ entry: WorkoutHistoryEntry) -> some View {
        let color = entry.pulseActivityColor

        return HStack(spacing: DS.Spacing.m) {
            // 运动类型 icon
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: DS.Spacing.xxl, height: DS.Spacing.xxl)

                    Image(systemName: entry.activityIcon)
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(color)
                }

                // OpenClaw AI 写入标识
                if entry.sourceName == "OpenClaw" {
                    Image(systemName: "cpu.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.accent)
                        .background(Circle().fill(DS.Color.bgElev).frame(width: DS.Spacing.card, height: DS.Spacing.card))
                        .offset(x: 3, y: 3)
                } else if entry.isManual {
                    // 手动添加标识
                    Image(systemName: "pencil.circle.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.accent)
                        .background(Circle().fill(DS.Color.bgElev).frame(width: DS.Spacing.card, height: DS.Spacing.card))
                        .offset(x: 3, y: 3)
                }
            }

            // 名称 + 日期 + 肌群 badge
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    // OpenClaw 来源：优先用 notes 作为主标题
                    Text(entry.sourceName == "OpenClaw" && !(entry.notes ?? "").isEmpty
                         ? (entry.notes ?? entry.activityName)
                         : entry.activityName)
                        .font(PulseTheme.bodyFont.weight(.medium))
                        .foregroundStyle(DS.Color.ink)
                        .lineLimit(1)
                    if entry.sourceName == "OpenClaw" {
                        Text("AI")
                            .font(DS.Typography.monoS.weight(.bold))
                            .foregroundStyle(DS.Color.accent)
                            .padding(.horizontal, DS.Spacing.m).padding(.vertical, DS.Spacing.m)
                            .background(Capsule().fill(DS.Color.accent.opacity(0.13)))
                    }
                }

                Text(formatRelativeDate(entry.startDate))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkDim)

                // 肌群 badge 行
                let tags = entry.muscleGroupTags
                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(3)) { group in
                            Text(group.label)
                                .font(DS.Typography.mono.weight(.medium))
                                .foregroundStyle(group.color)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, DS.Spacing.m)
                                .background(Capsule().fill(group.color.opacity(0.12)))
                        }
                        if tags.count > 3 {
                            Text("+\(tags.count - 3)")
                                .font(DS.Typography.mono)
                                .foregroundStyle(DS.Color.inkDim)
                        }
                    }
                }
            }

            Spacer()

            // 时长 + 卡路里 + strain
            VStack(alignment: .trailing, spacing: 2) {
                // Strain badge
                let strain = StrainScoreService.computeForWorkout(entry)
                if strain > 0 {
                    let level = StrainScoreService.StrainLevel(score: strain)
                    Text("\(strain)")
                        .font(DS.Typography.bodyS.weight(.bold))
                        .foregroundStyle(level.pulseColor)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.m)
                        .background(Capsule().fill(level.pulseColor.opacity(0.15)))
                }

                Text(formatDuration(entry.durationMinutes))
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)

                if let cal = entry.totalCalories {
                    Text("\(Int(cal)) kcal")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(DS.Color.inkMid)
                }
            }

            Image(systemName: "chevron.right")
                .font(DS.Typography.caption.weight(.medium))
                .foregroundStyle(DS.Color.inkDim)
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                .fill(DS.Color.bgElev)
                
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                .stroke(DS.Color.line.opacity(0.5), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.activityName), \(formatRelativeDate(entry.startDate))")
        .accessibilityValue("\(formatDuration(entry.durationMinutes))\(entry.totalCalories.map { ", \(Int($0)) kcal" } ?? "")")
        .accessibilityHint(String(localized: "Double tap to view details"))
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DS.Color.accent.opacity(0.08))
                    .frame(width: DS.Spacing.xxl * 2 + DS.Spacing.l, height: DS.Spacing.xxl * 2 + DS.Spacing.l)

                Image(systemName: "figure.run")
                    .font(DS.Typography.title1.weight(.light))
                    .foregroundStyle(DS.Color.accent)
            }

            VStack(spacing: DS.Spacing.s) {
                Text(String(localized: "Complete Your First Workout"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)

                Text(String(localized: "Start a workout on Apple Watch and your history will appear here"))
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(DS.Color.inkMid)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // 支持的训练类型提示
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(String(localized: "Supported workout types:"))
                    .font(PulseTheme.captionFont.weight(.medium))
                    .foregroundStyle(DS.Color.inkDim)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DS.Spacing.xs) {
                    workoutTypeItem(icon: "dumbbell.fill", name: String(localized: "Strength Training"))
                    workoutTypeItem(icon: "figure.run", name: String(localized: "Running"))
                    workoutTypeItem(icon: "figure.walk", name: String(localized: "Walking"))
                    workoutTypeItem(icon: "figure.cycling", name: String(localized: "Cycling"))
                    workoutTypeItem(icon: "figure.mixed.cardio", name: "HIIT")
                    workoutTypeItem(icon: "heart.fill", name: String(localized: "Other"))
                }
            }
            .padding(DS.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(PulseTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .stroke(DS.Color.line.opacity(0.3), lineWidth: 0.5)
            )

            Spacer()
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.l)
    }
    
    private func workoutTypeItem(icon: String, name: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.mono)
                .foregroundStyle(DS.Color.accent)
                .frame(width: 16)
            
            Text(name)
                .font(DS.Typography.mono)
                .foregroundStyle(DS.Color.inkDim)
            
            Spacer()
        }
    }

    // MARK: - 按月分组

    private struct MonthSection {
        let key: String       // "2026年3月"
        let entries: [WorkoutHistoryEntry]
    }

    private var groupedByMonth: [MonthSection] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy年M月"

        let grouped = Dictionary(grouping: allEntries) { entry in
            formatter.string(from: entry.startDate)
        }

        // 按最新日期排序
        return grouped
            .map { MonthSection(key: $0.key, entries: $0.value) }
            .sorted { ($0.entries.first?.startDate ?? .distantPast) > ($1.entries.first?.startDate ?? .distantPast) }
    }

    // MARK: - 格式化

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "Today") + " " + timeString(date)
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday") + " " + timeString(date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d EEE HH:mm"
            return formatter.string(from: date)
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    WorkoutHistoryListView()
        .modelContainer(for: WorkoutHistoryEntry.self, inMemory: true)
        .preferredColorScheme(.dark)
}
