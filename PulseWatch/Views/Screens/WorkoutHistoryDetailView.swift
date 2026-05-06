import SwiftUI

/// 训练详情页 — 展示单次训练的完整数据：时长、心率区间分布、卡路里等
struct WorkoutHistoryDetailView: View {

    let entry: WorkoutHistoryEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showShareScreen = false
    @State private var selectedMuscleGroups: Set<MuscleGroup> = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {
                // 运动类型头部
                headerCard
                    .staggered(index: 0)

                // 关键指标
                metricsGrid
                    .staggered(index: 1)

                // 心率区间分布
                if !entry.heartRateZones.isEmpty {
                    heartRateZonesCard
                        .staggered(index: 2)
                }

                // 心率概览
                if entry.averageHeartRate != nil || entry.maxHeartRate != nil {
                    heartRateSummaryCard
                        .staggered(index: 3)
                }

                // 肌群标签
                muscleGroupCard
                    .staggered(index: 4)

                // 数据来源
                sourceCard
                    .staggered(index: 5)

                // 删除按钮
                deleteButton
                    .staggered(index: 6)

                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingS)
        }
        .background(PulseTheme.background)
        .onAppear { selectedMuscleGroups = Set(entry.muscleGroupTags) }
        .navigationTitle(entry.activityName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareScreen = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PulseTheme.accent)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showShareScreen) {
            WorkoutShareScreen(entry: entry)
                .preferredColorScheme(.dark)
        }
        .alert(
            String(localized: "Delete Workout"),
            isPresented: $showDeleteConfirm
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                modelContext.delete(entry)
                try? modelContext.save()
                dismiss()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("This action cannot be undone. The original HealthKit data will not be affected.")
        }
    }

    // MARK: - 头部卡片

    private var headerCard: some View {
        let color = entry.pulseActivityColor

        return VStack(spacing: PulseTheme.spacingM) {
            // 大图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: entry.activityIcon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            }

            // 运动名称（OpenClaw: 用 notes；其他: 用 activityName）
            VStack(spacing: 6) {
                Text(entry.sourceName == "OpenClaw" && !(entry.notes ?? "").isEmpty
                     ? (entry.notes ?? entry.activityName)
                     : entry.activityName)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if entry.sourceName == "OpenClaw" {
                    HStack(spacing: 5) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 10))
                        Text(String(localized: "Recorded by OpenClaw AI"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(PulseTheme.accentTeal)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(PulseTheme.accentTeal.opacity(0.12)))
                }
            }

            // 日期时间
            Text(formatFullDate(entry.startDate))
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseTheme.spacingXL)
        .pulseCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: - 关键指标网格

    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: PulseTheme.spacingS),
            GridItem(.flexible(), spacing: PulseTheme.spacingS),
        ]

        return LazyVGrid(columns: columns, spacing: PulseTheme.spacingS) {
            // 时长
            metricTile(
                icon: "clock.fill",
                label: String(localized: "Duration"),
                value: formatDuration(entry.durationMinutes),
                unit: "",
                color: PulseTheme.accent
            )

            // 卡路里
            if let cal = entry.totalCalories {
                metricTile(
                    icon: "flame.fill",
                    label: String(localized: "Calories"),
                    value: "\(Int(cal))",
                    unit: "kcal",
                    color: PulseTheme.statusModerate
                )
            }

            // 距离（如果有）
            if let dist = entry.totalDistance, dist > 0 {
                let km = dist / 1000
                metricTile(
                    icon: "figure.run",
                    label: String(localized: "Distance"),
                    value: String(format: "%.2f", km),
                    unit: "km",
                    color: PulseTheme.statusGood
                )
            }

            // 平均心率
            if let avgHR = entry.averageHeartRate {
                metricTile(
                    icon: "heart.fill",
                    label: String(localized: "Avg Heart Rate"),
                    value: "\(Int(avgHR))",
                    unit: "bpm",
                    color: PulseTheme.statusPoor
                )
            }
        }
    }

    private func metricTile(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack(spacing: PulseTheme.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 28, height: 28)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color)
                }

                Text(label)
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(PulseTheme.metricLabelFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityLabel(label)
        .accessibilityValue(unit.isEmpty ? value : "\(value) \(unit)")
    }

    // MARK: - 心率区间分布

    private var heartRateZonesCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack(spacing: PulseTheme.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PulseTheme.statusPoor.opacity(0.12))
                        .frame(width: 24, height: 24)

                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.statusPoor)
                }
                .accessibilityHidden(true)

                Text("Heart Rate Zones")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }

            ForEach(entry.heartRateZones) { zone in
                HStack(spacing: PulseTheme.spacingS) {
                    Text(zone.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(zone.pulseColor)
                        .frame(width: 60, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(zone.pulseColor.opacity(0.15))
                                .frame(maxWidth: .infinity)

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(zone.pulseColor)
                                .frame(width: max(4, geo.size.width * zone.percentage))
                        }
                    }
                    .frame(height: 12)

                    Text("\(Int(zone.percentage * 100))%")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .frame(width: 40, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(zone.name)
                .accessibilityValue("\(Int(zone.percentage * 100)) \(String(localized: "percent"))")
            }
        }
        .pulseCard()
    }

    // MARK: - 心率概览

    private var heartRateSummaryCard: some View {
        HStack(spacing: 0) {
            if let avgHR = entry.averageHeartRate {
                VStack(spacing: PulseTheme.spacingXS) {
                    Text("\(Int(avgHR))")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)

                    Text(String(localized: "Average") + " bpm")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            if entry.averageHeartRate != nil && entry.maxHeartRate != nil {
                Rectangle()
                    .fill(PulseTheme.border.opacity(0.5))
                    .frame(width: 0.5, height: 44)
            }

            if let maxHR = entry.maxHeartRate {
                VStack(spacing: PulseTheme.spacingXS) {
                    Text("\(Int(maxHR))")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.statusPoor)

                    Text(String(localized: "Max") + " bpm")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .pulseCard()
    }

    // MARK: - 肌群标签选择器

    private var muscleGroupCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
                Text("Muscle Groups")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
                if !selectedMuscleGroups.isEmpty {
                    Text(String(format: String(localized: "%d selected"), selectedMuscleGroups.count))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            // 选择网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(MuscleGroup.allCases) { group in
                    let selected = selectedMuscleGroups.contains(group)
                    Button {
                        if selected {
                            selectedMuscleGroups.remove(group)
                        } else {
                            selectedMuscleGroups.insert(group)
                        }
                        entry.muscleGroupTags = Array(selectedMuscleGroups)
                        try? modelContext.save()
                    } label: {
                        VStack(spacing: 4) {
                            Text(group.emoji)
                                .font(.system(size: 18))
                            Text(group.label)
                                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? group.color : PulseTheme.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
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
                    .accessibilityLabel(group.label)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 数据来源

    private var sourceCard: some View {
        HStack(spacing: PulseTheme.spacingS) {
            Image(systemName: "applewatch")
                .font(.system(size: 14))
                .foregroundStyle(PulseTheme.textTertiary)
                .accessibilityHidden(true)

            Text(String(localized: "Source:") + " \(entry.sourceName)")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Spacer()

            Text(String(localized: "Synced:") + " \(formatShortDate(entry.syncedAt))")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                .fill(PulseTheme.surface)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - 删除按钮

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                Text("Delete Record")
                    .font(PulseTheme.bodyFont.weight(.medium))
            }
            .foregroundStyle(PulseTheme.statusPoor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.statusPoor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                            .stroke(PulseTheme.statusPoor.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Delete Record"))
        .accessibilityHint(String(localized: "Deletes this workout record from the app"))
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

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        WorkoutHistoryDetailView(
            entry: {
                let e = WorkoutHistoryEntry(
                    hkWorkoutUUID: UUID().uuidString,
                    activityType: 37,
                    startDate: .now.addingTimeInterval(-3600),
                    endDate: .now,
                    durationSeconds: 3600,
                    totalCalories: 420,
                    totalDistance: 5230,
                    averageHeartRate: 145,
                    maxHeartRate: 178,
                    sourceName: "Apple Watch"
                )
                e.heartRateZones = [
                    HRZoneEntry(name: "Warm-up", percentage: 0.10, colorHex: "7FB069"),
                    HRZoneEntry(name: "Fat Burn", percentage: 0.15, colorHex: "A8C256"),
                    HRZoneEntry(name: "Cardio", percentage: 0.40, colorHex: "D4A056"),
                    HRZoneEntry(name: "Anaerobic", percentage: 0.25, colorHex: "D47456"),
                    HRZoneEntry(name: "Peak", percentage: 0.10, colorHex: "C75C5C"),
                ]
                return e
            }()
        )
    }
    .preferredColorScheme(.dark)
}
