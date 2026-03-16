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

    var body: some View {
        NavigationStack {
            Group {
                if allEntries.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .background(PulseTheme.background)
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            LazyVStack(spacing: PulseTheme.spacingS) {
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
                            .foregroundStyle(PulseTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, sectionIndex == 0 ? 0 : PulseTheme.spacingS)
                            .padding(.leading, PulseTheme.spacingXS)
                    }
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
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
                color: PulseTheme.accent
            )

            Rectangle()
                .fill(PulseTheme.border.opacity(0.5))
                .frame(width: 0.5, height: 40)

            summaryItem(
                value: formatDuration(totalMinutes),
                label: String(localized: "Total Time"),
                icon: "clock.fill",
                color: PulseTheme.statusModerate
            )

            Rectangle()
                .fill(PulseTheme.border.opacity(0.5))
                .frame(width: 0.5, height: 40)

            summaryItem(
                value: totalCalories >= 1000 ? String(format: "%.1fk", totalCalories / 1000) : "\(Int(totalCalories))",
                label: String(localized: "Calories"),
                icon: "flame.fill",
                color: PulseTheme.statusPoor
            )
        }
        .pulseCard()
    }

    private func summaryItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: PulseTheme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 训练行

    private func workoutRow(_ entry: WorkoutHistoryEntry) -> some View {
        let color = Color(hex: entry.activityColor)

        return HStack(spacing: PulseTheme.spacingM) {
            // 运动类型 icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: entry.activityIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
            }

            // 名称 + 日期
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.activityName)
                    .font(PulseTheme.bodyFont.weight(.medium))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(formatRelativeDate(entry.startDate))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()

            // 时长 + 卡路里
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(entry.durationMinutes))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                if let cal = entry.totalCalories {
                    Text("\(Int(cal)) kcal")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow.opacity(0.3), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.activityName), \(formatRelativeDate(entry.startDate))")
        .accessibilityValue("\(formatDuration(entry.durationMinutes))\(entry.totalCalories.map { ", \(Int($0)) kcal" } ?? "")")
        .accessibilityHint(String(localized: "Double tap to view details"))
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: PulseTheme.spacingL) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: "figure.run")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(PulseTheme.accent)
            }

            VStack(spacing: PulseTheme.spacingS) {
                Text(String(localized: "Complete Your First Workout"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(String(localized: "Start a workout on Apple Watch and your history will appear here"))
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // 支持的训练类型提示
            VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                Text(String(localized: "Supported workout types:"))
                    .font(PulseTheme.captionFont.weight(.medium))
                    .foregroundStyle(PulseTheme.textTertiary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: PulseTheme.spacingXS) {
                    workoutTypeItem(icon: "dumbbell.fill", name: String(localized: "Strength Training"))
                    workoutTypeItem(icon: "figure.run", name: String(localized: "Running"))
                    workoutTypeItem(icon: "figure.walk", name: String(localized: "Walking"))
                    workoutTypeItem(icon: "figure.cycling", name: String(localized: "Cycling"))
                    workoutTypeItem(icon: "figure.mixed.cardio", name: "HIIT")
                    workoutTypeItem(icon: "heart.fill", name: String(localized: "Other"))
                }
            }
            .padding(PulseTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                    .fill(PulseTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                    .stroke(PulseTheme.border.opacity(0.3), lineWidth: 0.5)
            )

            Spacer()
            Spacer()
        }
        .padding(.horizontal, PulseTheme.spacingL)
    }
    
    private func workoutTypeItem(icon: String, name: String) -> some View {
        HStack(spacing: PulseTheme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 16)
            
            Text(name)
                .font(.system(size: 10))
                .foregroundStyle(PulseTheme.textTertiary)
            
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
