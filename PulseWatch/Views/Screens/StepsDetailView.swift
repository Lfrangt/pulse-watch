import SwiftUI
import Charts
import SwiftData

struct StepsDetailView: View {
    @State private var healthManager = HealthKitManager.shared
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]

    private var steps: Int { healthManager.todaySteps }
    private var goal: Int { 8000 }
    private var progress: Double { min(1.0, Double(steps) / Double(goal)) }

    private var statusLabel: String {
        switch steps {
        case 0..<3000: return "活动不足"
        case 3000..<6000: return "低活动"
        case 6000..<8000: return "接近目标"
        case 8000..<10000: return "达标"
        default: return "超额完成"
        }
    }
    private var statusColor: Color {
        steps >= 8000 ? PulseTheme.accentTeal : steps >= 5000 ? PulseTheme.statusWarning : PulseTheme.activityCoral
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {
                heroCard
                weeklyChart
                infoCard
                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)
        }
        .background(PulseTheme.background.ignoresSafeArea())
        .navigationTitle("步数")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(steps)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("步")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(y: -8)
            }

            // Progress ring-style bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [statusColor.opacity(0.7), statusColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 8)

            HStack {
                Text(statusLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(statusColor.opacity(0.13)))
                Spacer()
                Text("目标 \(goal) 步")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(PulseTheme.spacingM)
        .background(glassCard)
    }

    private var weeklyChart: some View {
        let data = summaries.prefix(14).reversed().compactMap { s -> (date: Date, steps: Int)? in
            guard let st = s.totalSteps, st > 0 else { return nil }
            return (s.date, st)
        }
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("14日步数趋势", icon: "figure.run")
            if data.isEmpty {
                emptyHint
            } else {
                Chart(data, id: \.date) { item in
                    BarMark(x: .value("Date", item.date, unit: .day), y: .value("Steps", item.steps), width: .ratio(0.6))
                        .foregroundStyle(item.steps >= goal ? PulseTheme.accentTeal.opacity(0.8) : PulseTheme.activityCoral.opacity(0.6))
                        .cornerRadius(4)
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(PulseTheme.accentTeal.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.defaultDigits).day()).font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.4)) } }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4])).foregroundStyle(Color.white.opacity(0.07)); AxisValueLabel().font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.4)) } }
                .frame(height: 160)
            }
        }
        .padding(PulseTheme.spacingM)
        .background(glassCard)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("为什么步数重要？", icon: "info.circle")
            tipRow("每天 8000 步与全因死亡率显著降低相关（JAMA研究）")
            tipRow("步行是最简单的有氧运动，保护心血管健康")
            tipRow("长期久坐可用每小时起身走动 2-3 分钟来补偿")
        }
        .padding(PulseTheme.spacingM)
        .background(glassCard)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(PulseTheme.accentTeal)
            Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).tracking(0.5).foregroundStyle(PulseTheme.textTertiary)
        }
    }
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(PulseTheme.accentTeal.opacity(0.5)).frame(width: 5, height: 5).padding(.top, 5)
            Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var emptyHint: some View {
        Text("暂无历史数据").font(.system(size: 13)).foregroundStyle(.white.opacity(0.3)).frame(maxWidth: .infinity).padding()
    }
    private var glassCard: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}
