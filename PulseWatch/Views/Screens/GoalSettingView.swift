import SwiftUI
import SwiftData

/// 目标设置页 — 配置每日/每周健康目标
struct GoalSettingView: View {

    @Query(sort: \HealthGoal.createdAt) private var goals: [HealthGoal]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddGoal = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.m) {

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
            .padding(.horizontal, DS.Spacing.m)
            .padding(.top, DS.Spacing.s)
        }
        .background(DS.Color.bg)
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
        HStack(spacing: DS.Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.Color.accent.opacity(0.12))
                    .frame(width: DS.Spacing.xl + DS.Spacing.xs, height: DS.Spacing.xl + DS.Spacing.xs)
                Image(systemName: "target")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Color.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "健康目标"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "设定目标，追踪每日进度"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkDim)
            }

            Spacer()
        }
        .pulseCard()
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: "flag.checkered")
                .font(DS.Typography.title1)
                .foregroundStyle(DS.Color.inkDim.opacity(0.5))
            Text(String(localized: "还没有设定目标"))
                .font(PulseTheme.bodyFont)
                .foregroundStyle(DS.Color.inkMid)
            Text(String(localized: "设定步数、睡眠、训练等目标，让 Pulse 帮你追踪"))
                .font(PulseTheme.captionFont)
                .foregroundStyle(DS.Color.inkDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .pulseCard()
    }

    // MARK: - Goal Row

    private func goalRow(_ goal: HealthGoal) -> some View {
        let metric = GoalMetricType(rawValue: goal.metricType)

        return HStack(spacing: DS.Spacing.m) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.Color.accent.opacity(0.12))
                    .frame(width: DS.Spacing.xxl, height: DS.Spacing.xxl)
                Image(systemName: metric?.icon ?? "questionmark")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Color.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(metric?.label ?? goal.metricType)
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)

                Text(String(localized: "目标: \(formatTarget(goal.targetValue, metric: metric)) \(metric?.unit ?? "")"))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkMid)
            }

            Spacer()

            // 开关
            Toggle("", isOn: Binding(
                get: { goal.isActive },
                set: { goal.isActive = $0 }
            ))
            .labelsHidden()
            .tint(DS.Color.accent)

            // 删除
            Button {
                modelContext.delete(goal)
            } label: {
                Image(systemName: "trash")
                    .font(DS.Typography.bodyS)
                    .foregroundStyle(DS.Color.bad.opacity(0.7))
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
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "plus.circle.fill")
                    .font(DS.Typography.body)
                Text(String(localized: "添加目标"))
                    .font(DS.Typography.body.weight(.medium))
            }
            .foregroundStyle(DS.Color.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.card)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                    .stroke(DS.Color.accent.opacity(0.3), lineWidth: 1)
                    .fill(DS.Color.accent.opacity(0.05))
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
            VStack(spacing: DS.Spacing.l) {
                // 指标选择
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text(String(localized: "选择指标"))
                        .font(DS.Typography.bodyS.weight(.medium))
                        .foregroundStyle(DS.Color.inkDim)

                    ForEach(GoalMetricType.allCases, id: \.rawValue) { metric in
                        Button {
                            selectedMetric = metric
                            targetValue = metric.defaultTarget
                        } label: {
                            HStack(spacing: DS.Spacing.m) {
                                Image(systemName: metric.icon)
                                    .font(DS.Typography.bodyS)
                                    .foregroundStyle(selectedMetric == metric ? DS.Color.accent : DS.Color.inkDim)
                                    .frame(width: 24)

                                Text(metric.label)
                                    .font(PulseTheme.bodyFont)
                                    .foregroundStyle(selectedMetric == metric ? DS.Color.ink : DS.Color.inkMid)

                                Spacer()

                                if selectedMetric == metric {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DS.Color.accent)
                                }
                            }
                            .padding(.vertical, DS.Spacing.s)
                        }
                    }
                }
                .pulseCard()

                // 目标值
                VStack(spacing: DS.Spacing.m) {
                    Text(String(localized: "目标值"))
                        .font(DS.Typography.bodyS.weight(.medium))
                        .foregroundStyle(DS.Color.inkDim)

                    Text("\(formatValue(targetValue)) \(selectedMetric.unit)")
                        .font(DS.Typography.title1)
                        .foregroundStyle(DS.Color.accent)

                    Slider(
                        value: $targetValue,
                        in: selectedMetric.range,
                        step: selectedMetric.step
                    )
                    .tint(DS.Color.accent)
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
            .padding(DS.Spacing.m)
            .background(DS.Color.bg)
            .navigationTitle(String(localized: "新目标"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundStyle(DS.Color.inkMid)
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
