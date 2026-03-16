import SwiftUI
import HealthKit

/// Tab: 运动记录 — 从 HealthKit 读取 HKWorkout，展示心率区间分布
struct WorkoutView: View {

    @State private var workouts: [HKWorkout] = []
    @State private var heartRateZones: [UUID: [HeartRateZone]] = [:]
    @State private var expandedId: UUID?
    @State private var isLoading = true
    @State private var weekStats: WeekWorkoutStats?

    private let store = HKHealthStore()

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseTheme.spacingM) {
                    // 本周统计
                    if let stats = weekStats, stats.totalCount > 0 {
                        weekStatsCard(stats)
                            .staggered(index: 0)
                    }

                    // 运动记录列表
                    if workouts.isEmpty && !isLoading {
                        emptyState
                            .staggered(index: 1)
                    } else {
                        ForEach(Array(workouts.enumerated()), id: \.element.uuid) { index, workout in
                            workoutRow(workout, index: index + 1)
                        }
                    }

                    if isLoading {
                        loadingView
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.spacingM)
            }
            .background(PulseTheme.background)
            .navigationTitle("Exercise")
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
            print("Workout fetch error: \(error)")
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
                HeartRateZone(name: String(localized: "Warm-up"), percentage: Double(zoneCounts[0]) / total, color: Color(hex: "7FB069")),
                HeartRateZone(name: String(localized: "Fat Burn"), percentage: Double(zoneCounts[1]) / total, color: Color(hex: "A8C256")),
                HeartRateZone(name: String(localized: "Cardio"), percentage: Double(zoneCounts[2]) / total, color: Color(hex: "D4A056")),
                HeartRateZone(name: String(localized: "Anaerobic"), percentage: Double(zoneCounts[3]) / total, color: Color(hex: "D47456")),
                HeartRateZone(name: String(localized: "Peak"), percentage: Double(zoneCounts[4]) / total, color: Color(hex: "C75C5C")),
            ]

            heartRateZones[workout.uuid] = zones
        } catch {
            #if DEBUG
            print("HR zone fetch error: \(error)")
            #endif
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
        case .running:              return "Running"
        case .cycling:              return "Cycling"
        case .swimming:             return "Swimming"
        case .walking:              return "Walking"
        case .hiking:               return "Hiking"
        case .yoga:                 return "Yoga"
        case .functionalStrengthTraining: return "Functional Strength"
        case .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .dance:                return "Dance"
        case .elliptical:           return "Elliptical"
        case .rowing:               return "Row"
        case .stairClimbing:        return "Stair Climbing"
        case .basketball:           return "Basketball"
        case .soccer:               return "Soccer"
        case .tennis:               return "Tennis"
        case .tableTennis:          return "Table Tennis"
        case .badminton:            return "Badminton"
        case .cooldown:             return "Recovery"
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
            formatter.locale = Locale(identifier: "zh_CN")
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
