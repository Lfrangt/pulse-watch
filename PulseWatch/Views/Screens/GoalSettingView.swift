import SwiftUI
import SwiftData

/// 目标设置页 — 配置每日/每周健康目标
struct GoalSettingView: View {

    @Query(sort: \HealthGoal.createdAt) private var goals: [HealthGoal]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddGoal = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {

                headerCard
                    .staggered(index: 0)

                if goals.isEmpty {
                    emptyCard
                        .staggered(index: 1)
                } else {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        goalRow(goal)
                            .staggered(index: index + 1)
                    }
                }

                // 添加目标按钮
                addGoalButton
                    .staggered(index: goals.count + 1)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingS)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "目标设置"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet { metricType, target in
                let goal = HealthGoal(
                    metricType: metricType.rawValue,
                    targetValue: target,
                    period: metricType.defaultPeriod
                )
                modelContext.insert(goal)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.accentTeal.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PulseTheme.accentTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "健康目标"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "设定目标，追踪每日进度"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()
        }
        .pulseCard()
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(spacing: PulseTheme.spacingM) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 36))
                .foregroundStyle(PulseTheme.textTertiary.opacity(0.5))
            Text(String(localized: "还没有设定目标"))
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
            Text(String(localized: "设定步数、睡眠、训练等目标，让 Pulse 帮你追踪"))
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseTheme.spacingXL)
        .pulseCard()
    }

    // MARK: - Goal Row

    private func goalRow(_ goal: HealthGoal) -> some View {
        let metric = GoalMetricType(rawValue: goal.metricType)

        return HStack(spacing: PulseTheme.spacingM) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: metric?.icon ?? "questionmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(metric?.label ?? goal.metricType)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(String(localized: "目标: \(formatTarget(goal.targetValue, metric: metric)) \(metric?.unit ?? "")"))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
            }

            Spacer()

            // 开关
            Toggle("", isOn: Binding(
                get: { goal.isActive },
                set: { goal.isActive = $0 }
            ))
            .labelsHidden()
            .tint(PulseTheme.accentTeal)

            // 删除
            Button {
                modelContext.delete(goal)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(PulseTheme.statusPoor.opacity(0.7))
            }
        }
        .pulseCard()
    }

    private func formatTarget(_ value: Double, metric: GoalMetricType?) -> String {
        guard let metric else { return String(format: "%.0f", value) }
        switch metric {
        case .steps: return String(format: "%.0f", value)
        case .sleepHours: return String(format: "%.1f", value)
        case .workoutCount: return String(format: "%.0f", value)
        case .dailyScore: return String(format: "%.0f", value)
        }
    }

    // MARK: - Add Button

    private var addGoalButton: some View {
        Button {
            showAddGoal = true
        } label: {
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text(String(localized: "添加目标"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundStyle(PulseTheme.accentTeal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .stroke(PulseTheme.accentTeal.opacity(0.3), lineWidth: 1)
                    .fill(PulseTheme.accentTeal.opacity(0.05))
            )
        }
    }
}

// MARK: - 添加目标 Sheet

struct AddGoalSheet: View {

    let onSave: (GoalMetricType, Double) -> Void

    @State private var selectedMetric: GoalMetricType = .steps
    @State private var targetValue: Double = 10000
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: PulseTheme.spacingL) {
                // 指标选择
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    Text(String(localized: "选择指标"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)

                    ForEach(GoalMetricType.allCases, id: \.rawValue) { metric in
                        Button {
                            selectedMetric = metric
                            targetValue = metric.defaultTarget
                        } label: {
                            HStack(spacing: PulseTheme.spacingM) {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(selectedMetric == metric ? PulseTheme.accentTeal : PulseTheme.textTertiary)
                                    .frame(width: 24)

                                Text(metric.label)
                                    .font(PulseTheme.bodyFont)
                                    .foregroundStyle(selectedMetric == metric ? PulseTheme.textPrimary : PulseTheme.textSecondary)

                                Spacer()

                                if selectedMetric == metric {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PulseTheme.accentTeal)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }
                .pulseCard()

                // 目标值
                VStack(spacing: PulseTheme.spacingM) {
                    Text(String(localized: "目标值"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)

                    Text("\(formatValue(targetValue)) \(selectedMetric.unit)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.accentTeal)

                    Slider(
                        value: $targetValue,
                        in: selectedMetric.range,
                        step: selectedMetric.step
                    )
                    .tint(PulseTheme.accentTeal)
                }
                .pulseCard()

                Spacer()

                // 保存按钮
                Button {
                    onSave(selectedMetric, targetValue)
                    dismiss()
                } label: {
                    Text(String(localized: "设定目标"))
                }
                .buttonStyle(PulseButtonStyle())
            }
            .padding(PulseTheme.spacingM)
            .background(PulseTheme.background)
            .navigationTitle(String(localized: "新目标"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        switch selectedMetric {
        case .sleepHours: return String(format: "%.1f", value)
        default: return String(format: "%.0f", value)
        }
    }
}

#Preview {
    NavigationStack {
        GoalSettingView()
    }
    .preferredColorScheme(.dark)
}
