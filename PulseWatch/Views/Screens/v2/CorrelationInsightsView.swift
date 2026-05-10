import SwiftUI
import SwiftData
import Charts

/// 指标相关性洞察页 — 展示健康指标间的统计关联
struct CorrelationInsightsView: View {

    @AppStorage("pulse.demo.enabled") private var demoMode = false
    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @State private var correlations: [CorrelationResult] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.m) {
                // 说明卡片
                headerCard
                    .staggered(index: 0)

                if correlations.isEmpty {
                    noDataCard
                        .staggered(index: 1)
                } else {
                    ForEach(Array(correlations.prefix(6).enumerated()), id: \.element.id) { index, result in
                        correlationCard(result)
                            .staggered(index: index + 1)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.top, DS.Spacing.s)
        }
        .background(DS.Color.bg)
        .navigationTitle(String(localized: "数据洞察"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if demoMode {
                correlations = DemoDataProvider.makeCorrelations()
            } else {
                correlations = await Task.detached {
                    await CorrelationService.shared.computeCorrelations(summaries: allSummaries)
                }.value
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: DS.Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.sleepViolet.opacity(0.12))
                    .frame(width: DS.Spacing.xl + DS.Spacing.xs, height: DS.Spacing.xl + DS.Spacing.xs)
                Image(systemName: "link")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(PulseTheme.sleepViolet)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "指标关联分析"))
                    .font(DS.Typography.bodyL)
                    .foregroundStyle(DS.Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "基于你 \(allSummaries.count) 天的数据，发现以下健康指标间的关联"))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)
            }

            Spacer()
        }
        .dsCard()
    }

    // MARK: - 无数据

    private var noDataCard: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: "chart.dots.scatter")
                .font(DS.Typography.title1)
                .foregroundStyle(DS.Color.inkDim.opacity(0.5))

            Text(String(localized: "需要至少 14 天数据"))
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.inkMid)

            Text(String(localized: "继续佩戴 Apple Watch，数据积累后将自动分析指标间的关联"))
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .dsCard()
    }

    // MARK: - 相关性卡片

    private func correlationCard(_ result: CorrelationResult) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            // 指标对标题
            HStack(spacing: DS.Spacing.s) {
                metricBadge(result.metricA)
                Image(systemName: result.isPositive ? "arrow.right" : "arrow.left.arrow.right")
                    .font(DS.Typography.mono.weight(.bold))
                    .foregroundStyle(DS.Color.inkDim)
                metricBadge(result.metricB)
                Spacer()
                strengthBadge(result)
            }

            // 自然语言洞察
            Text(result.insight)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.ink)
                .fixedSize(horizontal: false, vertical: true)

            // 相关系数可视化
            correlationBar(result)

            // 样本量
            Text(String(localized: "基于 \(result.sampleSize) 天数据"))
                .font(DS.Typography.mono.weight(.medium))
                .foregroundStyle(DS.Color.inkDim)
        }
        .dsCard()
        .accessibilityElement(children: .combine)
    }

    private func metricBadge(_ metric: CorrelationMetric) -> some View {
        HStack(spacing: 4) {
            Image(systemName: metric.icon)
                .font(DS.Typography.mono.weight(.medium))
            Text(metric.label)
                .font(DS.Typography.caption.weight(.semibold))
        }
        .foregroundStyle(DS.Color.inkMid)
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            Capsule().fill(DS.Color.bgElev)
        )
    }

    private func strengthBadge(_ result: CorrelationResult) -> some View {
        let color: Color = abs(result.coefficient) >= 0.5 ? DS.Color.accent :
                           abs(result.coefficient) >= 0.3 ? DS.Color.warn :
                           DS.Color.inkDim

        return Text(result.strengthLabel)
            .font(DS.Typography.mono.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.s)
            .padding(.vertical, DS.Spacing.m)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - 相关系数条

    // MARK: - 相关系数条（带动画）

    private func correlationBar(_ result: CorrelationResult) -> some View {
        let r = result.coefficient
        let barColor: Color = r > 0 ? DS.Color.accent : PulseTheme.activityCoral

        return VStack(spacing: 4) {
            GeometryReader { geo in
                let midX = geo.size.width / 2
                let barWidth = abs(r) * midX

                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(DS.Color.bgElev)
                        .frame(height: 6)

                    // 中心线
                    Rectangle()
                        .fill(DS.Color.line)
                        .frame(width: DS.Stroke.chartLine, height: DS.Spacing.s + DS.Spacing.xs)
                        .position(x: midX, y: 5)

                    // 相关系数条
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(barColor)
                        .frame(width: barWidth, height: 6)
                        .offset(x: r > 0 ? midX : midX - barWidth)
                }
            }
            .frame(height: 10)

            // 标注
            HStack {
                Text("-1")
                    .font(DS.Typography.mono)
                    .foregroundStyle(DS.Color.inkDim)
                Spacer()
                Text(String(format: "r = %.2f", r))
                    .font(DS.Typography.monoS.weight(.semibold))
                    .foregroundStyle(barColor)
                Spacer()
                Text("+1")
                    .font(DS.Typography.mono)
                    .foregroundStyle(DS.Color.inkDim)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CorrelationInsightsView()
    }
    .preferredColorScheme(.dark)
}
