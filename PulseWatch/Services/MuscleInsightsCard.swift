import SwiftUI

/// 肌群训练与恢复关联洞察卡片
/// 放在 Trends tab 底部，展示"练腿后 HRV 下降 X%"等个人化规律
struct MuscleInsightsCard: View {

    let workouts: [WorkoutHistoryEntry]
    let summaries: [DailySummary]

    private var insights: [MuscleInsightEngine.Insight] {
        MuscleInsightEngine.compute(workouts: workouts, summaries: summaries)
    }

    private var pending: [(MuscleGroup, Int)] {
        MuscleInsightEngine.pendingInsights(workouts: workouts)
    }

    private var taggedWorkoutsCount: Int {
        workouts.filter { !$0.muscleGroupTags.isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // Header
            HStack(spacing: PulseTheme.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PulseTheme.accent.opacity(0.12))
                        .frame(width: 24, height: 24)
                    Image(systemName: "chart.bar.xaxis.ascending")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.accent)
                }
                Text("Recovery Insights")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("by muscle group")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            if taggedWorkoutsCount == 0 {
                // 完全没有 tag 数据
                emptyState
            } else if insights.isEmpty && pending.isEmpty {
                // 有 tag 但都不足 5 次
                Text(String(localized: "Building your personal insights…\nTag your workouts with muscle groups to unlock."))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            } else {
                // 真实洞察
                if !insights.isEmpty {
                    VStack(spacing: PulseTheme.spacingS) {
                        ForEach(insights) { insight in
                            insightRow(insight)
                        }
                    }
                }

                // 积累中的提示
                if !pending.isEmpty {
                    Divider().background(PulseTheme.border)
                    Text(String(localized: "Accumulating data:"))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                    ForEach(pending, id: \.0) { group, count in
                        HStack {
                            Text(group.emoji + " " + group.label)
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(group.color)
                            Spacer()
                            Text(String(format: String(localized: "%d / 5 sessions"), count))
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                }
            }
        }
        .pulseCard()
    }

    // MARK: - Subviews

    private var emptyState: some View {
        HStack(spacing: PulseTheme.spacingM) {
            Image(systemName: "tag.slash")
                .font(.system(size: 20))
                .foregroundStyle(PulseTheme.textTertiary)
            VStack(alignment: .leading, spacing: 4) {
                Text("No muscle groups tagged yet")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                Text("Open a workout and tag which muscles you trained")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
    }

    private func insightRow(_ insight: MuscleInsightEngine.Insight) -> some View {
        HStack(alignment: .top, spacing: PulseTheme.spacingM) {
            // 方向指示
            ZStack {
                Circle()
                    .fill(insight.isPositive ? PulseTheme.statusGood.opacity(0.15) : PulseTheme.statusPoor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: insight.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(insight.isPositive ? PulseTheme.statusGood : PulseTheme.statusPoor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.description)
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(format: String(localized: "Based on %d sessions"), insight.sampleCount))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
    }
}
