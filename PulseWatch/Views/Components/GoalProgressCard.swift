import SwiftUI
import SwiftData

/// 目标进度卡片 — 在 Dashboard 显示活跃目标的完成进度
struct GoalProgressCard: View {

    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @Query(sort: \WorkoutHistoryEntry.startDate, order: .reverse) private var allWorkouts: [WorkoutHistoryEntry]
    @Query(filter: #Predicate<HealthGoal> { $0.isActive }) private var activeGoals: [HealthGoal]

    var body: some View {
        if activeGoals.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
                // 标题
                HStack(spacing: PulseTheme.spacingS) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PulseTheme.accentTeal.opacity(0.12))
                            .frame(width: 24, height: 24)
                        Image(systemName: "target")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PulseTheme.accentTeal)
                    }

                    Text(String(localized: "今日目标"))
                        .font(PulseTheme.headlineFont)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()
                }

                // 目标列表
                ForEach(activeGoals, id: \.id) { goal in
                    goalRow(goal)
                }
            }
            .pulseCard()
        }
    }

    private func goalRow(_ goal: HealthGoal) -> some View {
        let metric = GoalMetricType(rawValue: goal.metricType)
        let progress = currentProgress(for: goal)
        let pct = goal.targetValue > 0 ? min(progress / goal.targetValue, 1.0) : 0
        let completed = pct >= 1.0

        return HStack(spacing: PulseTheme.spacingM) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(PulseTheme.surface2, lineWidth: 4)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(
                        completed ? PulseTheme.accentTeal : PulseTheme.accent.opacity(0.7),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PulseTheme.accentTeal)
                } else {
                    Image(systemName: metric?.icon ?? "target")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(metric?.label ?? goal.metricType)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text("\(formatValue(progress, metric: metric)) / \(formatValue(goal.targetValue, metric: metric)) \(metric?.unit ?? "")")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()

            Text(String(format: "%.0f%%", pct * 100))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(completed ? PulseTheme.accentTeal : PulseTheme.textSecondary)
        }
    }

    // MARK: - 计算当前进度

    private func currentProgress(for goal: HealthGoal) -> Double {
        let metric = GoalMetricType(rawValue: goal.metricType)
        let today = Calendar.current.startOfDay(for: .now)
        let todaySummary = allSummaries.first { Calendar.current.isDate($0.date, inSameDayAs: today) }

        switch metric {
        case .steps:
            return Double(todaySummary?.totalSteps ?? 0)
        case .sleepHours:
            return Double(todaySummary?.sleepDurationMinutes ?? 0) / 60.0
        case .dailyScore:
            return Double(todaySummary?.dailyScore ?? 0)
        case .workoutCount:
            // 本周训练次数
            let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
            return Double(allWorkouts.filter { $0.startDate >= weekStart }.count)
        case .none:
            return 0
        }
    }

    private func formatValue(_ value: Double, metric: GoalMetricType?) -> String {
        switch metric {
        case .sleepHours: return String(format: "%.1f", value)
        case .steps: return String(format: "%.0f", value)
        default: return String(format: "%.0f", value)
        }
    }
}
