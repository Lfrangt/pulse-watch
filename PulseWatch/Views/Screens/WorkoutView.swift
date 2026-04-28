import SwiftUI
import SwiftData
import HealthKit
import os

/// Tab: 运动记录 — 从 HealthKit 读取 HKWorkout，展示心率区间分布
struct WorkoutView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "WorkoutView")

    @State private var workouts: [HKWorkout] = []
    @State private var heartRateZones: [UUID: [HeartRateZone]] = [:]
    @State private var expandedId: UUID?
    @State private var isLoading = true
    @State private var weekStats: WeekWorkoutStats?
    @State private var strengthExpanded = true

    @Query(sort: \StrengthRecord.date, order: .reverse) private var strengthRecords: [StrengthRecord]
    @Query(sort: \WorkoutHistoryEntry.startDate, order: .reverse) private var allHistoryEntries: [WorkoutHistoryEntry]
    @AppStorage("pulse.user.weightKg") private var bodyweight: Double = 0

    /// 最近 7 天的 OpenClaw AI 训练记录
    private var recentAIWorkouts: [WorkoutHistoryEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return allHistoryEntries.filter { $0.sourceName == "OpenClaw" && $0.startDate >= cutoff }
    }

    private let store = HKHealthStore()

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseTheme.spacingM) {
                    // ── 本周统计 ──
                    if let stats = weekStats, stats.totalCount > 0 {
                        weekStatsCard(stats)
                            .staggered(index: 0)
                    }

                    // ── 力量训练（最近5条，紧跟本周统计）──
                    strengthSection
                        .staggered(index: 1)

                    // ── HealthKit 运动记录 ──
                    if workouts.isEmpty && !isLoading {
                        emptyState
                            .staggered(index: 2)
                    } else {
                        ForEach(Array(workouts.enumerated()), id: \.element.uuid) { index, workout in
                            workoutRow(workout, index: index + 1)
                        }
                    }

                    if isLoading {
                        loadingView
                    }

                    // ── AI 记录（OpenClaw 写入）──
                    if !recentAIWorkouts.isEmpty {
                        aiWorkoutsSection
                            .staggered(index: workouts.count + 2)
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.spacingM)
            }
            .background(PulseTheme.background)
            .navigationTitle(String(localized: "Exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Exercise")
                        .font(PulseTheme.headlineFont)
                        .foregroundStyle(PulseTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        WorkoutHistoryListView()
                            .preferredColorScheme(.dark)
                    } label: {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 16))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .accessibilityLabel(String(localized: "History"))
                }
            }
            .task {
                await loadWorkouts()
            }
            .refreshable {
                await loadWorkouts()
            }
        }
    }

    // MARK: - AI 训练记录 section

    private var aiWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack(spacing: 6) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(PulseTheme.accentTeal)
                Text("OpenClaw AI 记录")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .padding(.leading, 4)

            ForEach(Array(recentAIWorkouts.enumerated()), id: \.offset) { _, entry in
                aiWorkoutRow(entry)
            }
        }
    }

    private func aiWorkoutRow(_ entry: WorkoutHistoryEntry) -> some View {
        let title = !(entry.notes ?? "").isEmpty ? entry.notes! : entry.activityName
        return NavigationLink(destination: WorkoutHistoryDetailView(entry: entry)) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PulseTheme.accentTeal.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.activityIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PulseTheme.accentTeal)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(PulseTheme.bodyFont.weight(.medium))
                            .foregroundStyle(PulseTheme.textPrimary)
                            .lineLimit(1)
                        Text("AI")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.accentTeal)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(PulseTheme.accentTeal.opacity(0.13)))
                    }
                    Text(timeString(entry.startDate))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
                Spacer()
                Text("\(entry.durationMinutes)m")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .padding(PulseTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.highlight)
                    .overlay(RoundedRectangle(cornerRadius: PulseTheme.radiusM).stroke(PulseTheme.accentTeal.opacity(0.2), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 本周统计卡片

    private func weekStatsCard(_ stats: WeekWorkoutStats) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
                    .accessibilityHidden(true)
                Text("This Week's Exercise")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }

            HStack(spacing: 0) {
                statItem(
                    value: "\(stats.activeDays)",
                    unit: String(localized: "days"),
                    label: String(localized: "Active Days"),
                    color: PulseTheme.statusGood
                )

                statDivider

                statItem(
                    value: formatDuration(stats.totalMinutes),
                    unit: "",
                    label: String(localized: "Total Duration"),
                    color: PulseTheme.accent
                )

                statDivider

                statItem(
                    value: "\(Int(stats.totalCalories))",
                    unit: "kcal",
                    label: String(localized: "Total Burned"),
                    color: PulseTheme.statusModerate
                )
            }
        }
        .pulseCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "This Week's Exercise"))
    }

    private func statItem(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: PulseTheme.spacingXS) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(PulseTheme.metricLabelFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            Text(label)
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(PulseTheme.border.opacity(0.5))
            .frame(width: 0.5, height: 40)
    }

    // MARK: - 运动记录行

    private func workoutRow(_ workout: HKWorkout, index: Int) -> some View {
        let isExpanded = expandedId == workout.uuid

        return VStack(spacing: 0) {
            // 主行
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    expandedId = isExpanded ? nil : workout.uuid
                }
                if !isExpanded && heartRateZones[workout.uuid] == nil {
                    Task { await loadHeartRateZones(for: workout) }
                }
            } label: {
                HStack(spacing: PulseTheme.spacingM) {
                    // 运动类型 icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(workoutColor(workout).opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: workoutIcon(workout))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(workoutColor(workout))
                    }

                    // 名称 + 日期
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workoutName(workout))
                            .font(PulseTheme.bodyFont.weight(.medium))
                            .foregroundStyle(PulseTheme.textPrimary)

                        Text(formatWorkoutDate(workout.startDate))
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }

                    Spacer()

                    // 时长 + 卡路里
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDuration(Int(workout.duration / 60)))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)

                        if let cal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                            Text("\(Int(cal)) kcal")
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textSecondary)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            // 展开：心率区间
            if isExpanded {
                if let zones = heartRateZones[workout.uuid] {
                    heartRateZonesView(zones)
                        .padding(.top, PulseTheme.spacingM)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    ProgressView()
                        .tint(PulseTheme.accent)
                        .padding(.vertical, PulseTheme.spacingM)
                }
            }
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(workoutName(workout)), \(formatWorkoutDate(workout.startDate))")
        .accessibilityValue("\(formatDuration(Int(workout.duration / 60)))\(workout.totalEnergyBurned.map { ", \(Int($0.doubleValue(for: .kilocalorie()))) kcal" } ?? "")")
        .accessibilityHint(isExpanded ? String(localized: "Double tap to collapse heart rate zones") : String(localized: "Double tap to expand heart rate zones"))
        .staggered(index: index)
    }

    // MARK: - 心率区间分布

    private func heartRateZonesView(_ zones: [HeartRateZone]) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Heart Rate Zone")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(zones) { zone in
                HStack(spacing: PulseTheme.spacingS) {
                    Text(zone.name)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(zone.color)
                        .frame(width: 50, alignment: .leading)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(zone.color.opacity(0.25))
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(zone.color)
                                    .frame(width: max(4, geo.size.width * zone.percentage))
                            }
                    }
                    .frame(height: 8)

                    Text("\(Int(zone.percentage * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(zone.name)
                .accessibilityValue("\(Int(zone.percentage * 100)) \(String(localized: "percent"))")
            }
        }
        .padding(.top, PulseTheme.spacingXS)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: PulseTheme.spacingL) {
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.08))
                    .frame(width: 80, height: 80)

                Image(systemName: "figure.run")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(PulseTheme.accent)
                    .accessibilityHidden(true)
            }

            VStack(spacing: PulseTheme.spacingS) {
                Text("No workout records yet")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                Text("Your workout records will appear here.\nSupports running, cycling, swimming, strength training, and more.")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.vertical, PulseTheme.spacingXL * 2)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var loadingView: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
            .fill(PulseTheme.cardBackground)
            .frame(height: 80)
            .overlay(ProgressView().tint(PulseTheme.accent))
    }

    // MARK: - 数据加载

    private func loadWorkouts() async {
        isLoading = true

        guard HKHealthStore.isHealthDataAvailable() else {
            isLoading = false
            return
        }

        let workoutType = HKWorkoutType.workoutType()
        let readTypes: Set<HKObjectType> = [workoutType, HKQuantityType(.heartRate)]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            isLoading = false
            return
        }

        // 最近 30 天的运动
        let calendar = Calendar.current
        let now = Date()
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else {
            isLoading = false
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 50
        )

        do {
            let results = try await descriptor.result(for: store)
            workouts = results

            // 计算本周统计
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let weekWorkouts = results.filter { $0.startDate >= startOfWeek }

            let totalMinutes = weekWorkouts.reduce(0) { $0 + Int($1.duration / 60) }
            let totalCalories = weekWorkouts.reduce(0.0) {
                $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
            }
            let activeDays = Set(weekWorkouts.map { calendar.startOfDay(for: $0.startDate) }).count

            weekStats = WeekWorkoutStats(
                totalCount: weekWorkouts.count,
                totalMinutes: totalMinutes,
                totalCalories: totalCalories,
                activeDays: activeDays
            )
        } catch {
            logger.error("Workout fetch error: \(error)")
        }

        isLoading = false
    }

    private func loadHeartRateZones(for workout: HKWorkout) async {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        do {
            let samples = try await descriptor.result(for: store)
            let bpmValues = samples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }

            guard !bpmValues.isEmpty else { return }

            // 5区间划分（基于最大心率估算 220-age，默认用 190）
            let maxHR: Double = 190
            var zoneCounts = [0, 0, 0, 0, 0]
            let total = Double(bpmValues.count)

            for bpm in bpmValues {
                let pct = bpm / maxHR
                switch pct {
                case ..<0.6:   zoneCounts[0] += 1
                case 0.6..<0.7: zoneCounts[1] += 1
                case 0.7..<0.8: zoneCounts[2] += 1
                case 0.8..<0.9: zoneCounts[3] += 1
                default:        zoneCounts[4] += 1
                }
            }

            let zones: [HeartRateZone] = [
                HeartRateZone(name: String(localized: "Warm-up"), percentage: Double(zoneCounts[0]) / total, color: PulseTheme.statusGood),
                HeartRateZone(name: String(localized: "Fat Burn"), percentage: Double(zoneCounts[1]) / total, color: Color(hex: "A8C256")),
                HeartRateZone(name: String(localized: "Cardio"), percentage: Double(zoneCounts[2]) / total, color: PulseTheme.statusModerate),
                HeartRateZone(name: String(localized: "Anaerobic"), percentage: Double(zoneCounts[3]) / total, color: Color(hex: "D47456")),
                HeartRateZone(name: String(localized: "Peak"), percentage: Double(zoneCounts[4]) / total, color: PulseTheme.activityAccent),
            ]

            heartRateZones[workout.uuid] = zones
        } catch {
            logger.error("HR zone fetch error: \(error)")
        }
    }

    // MARK: - 力量训练模块（内嵌）

    private var strengthAssessment: StrengthService.StrengthAssessment? {
        StrengthService.shared.assess(records: strengthRecords, bodyweightKg: bodyweight)
    }

    @State private var showAddStrength = false

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // Section header (tap to expand)
            Button {
                withAnimation(.spring(response: 0.3)) { strengthExpanded.toggle() }
            } label: {
                HStack(spacing: PulseTheme.spacingS) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PulseTheme.accent)
                    Text("Strength")
                        .font(PulseTheme.headlineFont)
                        .foregroundStyle(PulseTheme.textPrimary)
                    Spacer()

                    // 评分 mini badge
                    if let a = strengthAssessment, a.totalScore > 0 {
                        Text("\(a.totalScore)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: a.totalLevel.color))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: a.totalLevel.color).opacity(0.15)))
                    }

                    Button {
                        showAddStrength = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(PulseTheme.accent)
                    }

                    Image(systemName: strengthExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // 三项最佳成绩（始终显示）
            if let a = strengthAssessment {
                HStack(spacing: 0) {
                    ForEach(a.lifts, id: \.liftType) { lift in
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", lift.best1RM))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text(lift.liftType.label)
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.textTertiary)
                            Text(lift.level.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color(hex: lift.level.color))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else if bodyweight <= 0 {
                Text("Set body weight in Settings → Profile")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            } else if strengthRecords.isEmpty {
                Text("No lifts recorded yet — tap + to add")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            // 展开详情
            if strengthExpanded {
                // 最近记录
                if !strengthRecords.isEmpty {
                    Divider().background(PulseTheme.border)
                    ForEach(strengthRecords.prefix(5)) { record in
                        let type = StrengthService.LiftType(rawValue: record.liftType) ?? .squat
                        HStack(spacing: PulseTheme.spacingS) {
                            Circle()
                                .fill(Color(hex: type.color))
                                .frame(width: 6, height: 6)
                            Text(type.label)
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                                .frame(width: 70, alignment: .leading)
                            Text(String(format: "%.0f kg × %d × %d", record.weightKg, record.sets, record.reps))
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textSecondary)
                            Spacer()
                            Text(record.date, format: .dateTime.month(.abbreviated).day())
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.textTertiary)
                            if record.isPersonalRecord {
                                Text("PR")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(PulseTheme.statusModerate)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(PulseTheme.statusModerate.opacity(0.15)))
                            }
                        }
                    }
                }

                // 进入完整力量页面
                NavigationLink {
                    StrengthView()
                        .preferredColorScheme(.dark)
                } label: {
                    HStack {
                        Text("View Full Strength Details")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(PulseTheme.accent)
                    }
                }
                .padding(.top, PulseTheme.spacingXS)
            }
        }
        .pulseCard()
        .sheet(isPresented: $showAddStrength) {
            AddStrengthRecordView()
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - 辅助

    private func workoutIcon(_ workout: HKWorkout) -> String {
        switch workout.workoutActivityType {
        case .running:              return "figure.run"
        case .cycling:              return "figure.outdoor.cycle"
        case .swimming:             return "figure.pool.swim"
        case .walking:              return "figure.walk"
        case .hiking:               return "figure.hiking"
        case .yoga:                 return "figure.yoga"
        case .functionalStrengthTraining,
             .traditionalStrengthTraining: return "dumbbell.fill"
        case .highIntensityIntervalTraining: return "flame.fill"
        case .dance:                return "figure.dance"
        case .elliptical:           return "figure.elliptical"
        case .rowing:               return "figure.rower"
        case .stairClimbing:        return "figure.stair.stepper"
        case .basketball:           return "basketball.fill"
        case .soccer:               return "soccerball"
        case .tennis:               return "tennisball.fill"
        case .tableTennis:          return "figure.table.tennis"
        case .badminton:            return "figure.badminton"
        case .cooldown:             return "wind"
        default:                    return "figure.mixed.cardio"
        }
    }

    private func workoutColor(_ workout: HKWorkout) -> Color {
        switch workout.workoutActivityType {
        case .running, .highIntensityIntervalTraining:
            return PulseTheme.statusPoor
        case .cycling, .swimming, .rowing:
            return PulseTheme.accent
        case .walking, .hiking, .yoga, .cooldown:
            return PulseTheme.statusGood
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return PulseTheme.statusModerate
        default:
            return PulseTheme.accent
        }
    }

    private func workoutName(_ workout: HKWorkout) -> String {
        switch workout.workoutActivityType {
        case .running:              return String(localized: "Running")
        case .cycling:              return String(localized: "Cycling")
        case .swimming:             return String(localized: "Swimming")
        case .walking:              return String(localized: "Walking")
        case .hiking:               return String(localized: "Hiking")
        case .yoga:                 return String(localized: "Yoga")
        case .functionalStrengthTraining: return String(localized: "Functional Strength")
        case .traditionalStrengthTraining: return String(localized: "Strength Training")
        case .highIntensityIntervalTraining: return String(localized: "HIIT")
        case .dance:                return String(localized: "Dance")
        case .elliptical:           return String(localized: "Elliptical")
        case .rowing:               return String(localized: "Rowing")
        case .stairClimbing:        return String(localized: "Stair Climbing")
        case .basketball:           return String(localized: "Basketball")
        case .soccer:               return String(localized: "Soccer")
        case .tennis:               return String(localized: "Tennis")
        case .tableTennis:          return String(localized: "Table Tennis")
        case .badminton:            return String(localized: "Badminton")
        case .cooldown:             return String(localized: "Cooldown")
        default:                    return String(localized: "Exercise")
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private func formatWorkoutDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "Today ") + timeString(date)
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday ") + timeString(date)
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateFormat = "M/d EEE"
            return formatter.string(from: date)
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 数据模型

private struct WeekWorkoutStats {
    let totalCount: Int
    let totalMinutes: Int
    let totalCalories: Double
    let activeDays: Int
}

private struct HeartRateZone: Identifiable {
    let id = UUID()
    let name: String
    let percentage: Double
    let color: Color
}

#Preview {
    WorkoutView()
        .preferredColorScheme(.dark)
}
