import SwiftUI
import SwiftData
import Charts

/// 指标相关性洞察页 — 展示健康指标间的统计关联
struct CorrelationInsightsView: View {

    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @State private var correlations: [CorrelationResult] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {
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
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingS)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "数据洞察"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            correlations = await Task.detached {
                await CorrelationService.shared.computeCorrelations(summaries: allSummaries)
            }.value
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.sleepViolet.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PulseTheme.sleepViolet)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "指标关联分析"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(String(localized: "基于你 \(allSummaries.count) 天的数据，发现以下健康指标间的关联"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()
        }
        .pulseCard()
    }

    // MARK: - 无数据

    private var noDataCard: some View {
        VStack(spacing: PulseTheme.spacingM) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 36))
                .foregroundStyle(PulseTheme.textTertiary.opacity(0.5))

            Text(String(localized: "需要至少 14 天数据"))
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)

            Text(String(localized: "继续佩戴 Apple Watch，数据积累后将自动分析指标间的关联"))
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseTheme.spacingXL)
        .pulseCard()
    }

    // MARK: - 相关性卡片

    private func correlationCard(_ result: CorrelationResult) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // 指标对标题
            HStack(spacing: PulseTheme.spacingS) {
                metricBadge(result.metricA)
                Image(systemName: result.isPositive ? "arrow.right" : "arrow.left.arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PulseTheme.textTertiary)
                metricBadge(result.metricB)
                Spacer()
                strengthBadge(result)
            }

            // 自然语言洞察
            Text(result.insight)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // 相关系数可视化
            correlationBar(result)

            // 样本量
            Text(String(localized: "基于 \(result.sampleSize) 天数据"))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .pulseCard()
        .accessibilityElement(children: .combine)
    }

    private func metricBadge(_ metric: CorrelationMetric) -> some View {
        HStack(spacing: 4) {
            Image(systemName: metric.icon)
                .font(.system(size: 10, weight: .medium))
            Text(metric.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(PulseTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(PulseTheme.surface2)
        )
    }

    private func strengthBadge(_ result: CorrelationResult) -> some View {
        let color: Color = abs(result.coefficient) >= 0.5 ? PulseTheme.accentTeal :
                           abs(result.coefficient) >= 0.3 ? PulseTheme.statusWarning :
                           PulseTheme.textTertiary

        return Text(result.strengthLabel)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - 相关系数条

    private func correlationBar(_ result: CorrelationResult) -> some View {
        let r = result.coefficient
        let barColor: Color = r > 0 ? PulseTheme.accentTeal : PulseTheme.activityCoral

        return VStack(spacing: 4) {
            GeometryReader { geo in
                let midX = geo.size.width / 2
                let barWidth = abs(r) * midX

                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(PulseTheme.surface2)
                        .frame(height: 6)

                    // 中心线
                    Rectangle()
                        .fill(PulseTheme.border)
                        .frame(width: 1, height: 10)
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
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(PulseTheme.textTertiary)
                Spacer()
                Text(String(format: "r = %.2f", r))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(barColor)
                Spacer()
                Text("+1")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(PulseTheme.textTertiary)
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
