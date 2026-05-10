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
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            // Header
            HStack(spacing: DS.Spacing.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DS.Color.accent.opacity(0.12))
                        .frame(width: DS.Spacing.l + DS.Spacing.xs, height: DS.Spacing.l + DS.Spacing.xs)
                    Image(systemName: "chart.bar.xaxis.ascending")
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Color.accent)
                }
                Text("Recovery Insights")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("by muscle group")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkDim)
            }

            if taggedWorkoutsCount == 0 {
                // 完全没有 tag 数据
                emptyState
            } else if insights.isEmpty && pending.isEmpty {
                // 有 tag 但都不足 5 次
                Text(String(localized: "Building your personal insights…\nTag your workouts with muscle groups to unlock."))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkMid)
                    .multilineTextAlignment(.leading)
            } else {
                // 真实洞察
                if !insights.isEmpty {
                    VStack(spacing: DS.Spacing.s) {
                        ForEach(insights) { insight in
                            insightRow(insight)
                        }
                    }
                }

                // 积累中的提示
                if !pending.isEmpty {
                    Divider().background(DS.Color.line)
                    Text(String(localized: "Accumulating data:"))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(DS.Color.inkDim)
                    ForEach(pending, id: \.0) { group, count in
                        HStack {
                            Text(group.emoji + " " + group.label)
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(group.color)
                            Spacer()
                            Text(String(format: String(localized: "%d / 5 sessions"), count))
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(DS.Color.inkDim)
                        }
                    }
                }
            }
        }
        .pulseCard()
    }

    // MARK: - Subviews

    private var emptyState: some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: "tag.slash")
                .font(DS.Typography.bodyL)
                .foregroundStyle(DS.Color.inkDim)
            VStack(alignment: .leading, spacing: 4) {
                Text("No muscle groups tagged yet")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(DS.Color.inkMid)
                Text("Open a workout and tag which muscles you trained")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkDim)
            }
        }
    }

    private func insightRow(_ insight: MuscleInsightEngine.Insight) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            // 方向指示
            ZStack {
                Circle()
                    .fill(insight.isPositive ? DS.Color.good.opacity(0.15) : DS.Color.bad.opacity(0.15))
                    .frame(width: DS.Spacing.xl, height: DS.Spacing.xl)
                Image(systemName: insight.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(DS.Typography.body)
                    .foregroundStyle(insight.isPositive ? DS.Color.good : DS.Color.bad)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.description)
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(DS.Color.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(format: String(localized: "Based on %d sessions"), insight.sampleCount))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkDim)
            }
        }
    }
}
