import SwiftUI
import SwiftData
import Charts

/// 月度报告详情页 — 月度健康总结 + 趋势 + 分享
struct MonthlyReportView: View {

    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @Query(sort: \WorkoutHistoryEntry.startDate, order: .reverse) private var allWorkouts: [WorkoutHistoryEntry]
    @State private var renderedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if lastMonthSummaries.isEmpty {
                        EmptyStateView(
                            icon: "doc.text",
                            title: String(localized: "No Monthly Report"),
                            message: String(localized: "Reports generate after one month of data.")
                        )
                        .staggered(index: 0)
                    } else {
                        reportCard
                            .staggered(index: 0)

                        shareButton
                            .staggered(index: 1)
                            .padding(.top, DS.Spacing.m)
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, DS.Spacing.m)
                .padding(.top, DS.Spacing.s)
            }
            .background(DS.Color.bg)
            .navigationTitle(String(localized: "月度报告"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "完成")) { dismiss() }
                        .foregroundStyle(DS.Color.accent)
                }
            }
        }
    }

    // MARK: - 数据

    private var lastMonthSummaries: [DailySummary] {
        let cal = Calendar.current
        let thisMonthStart = cal.safeDate(from: cal.dateComponents([.year, .month], from: .now))
        let lastMonthStart = cal.safeDate(byAdding: .month, value: -1, to: thisMonthStart)
        return allSummaries.filter { $0.date >= lastMonthStart && $0.date < thisMonthStart }
    }

    private var prevMonthSummaries: [DailySummary] {
        let cal = Calendar.current
        let thisMonthStart = cal.safeDate(from: cal.dateComponents([.year, .month], from: .now))
        let lastMonthStart = cal.safeDate(byAdding: .month, value: -1, to: thisMonthStart)
        let prevMonthStart = cal.safeDate(byAdding: .month, value: -1, to: lastMonthStart)
        return allSummaries.filter { $0.date >= prevMonthStart && $0.date < lastMonthStart }
    }

    private var monthLabel: String {
        let cal = Calendar.current
        let thisMonthStart = cal.safeDate(from: cal.dateComponents([.year, .month], from: .now))
        let lastMonthStart = cal.safeDate(byAdding: .month, value: -1, to: thisMonthStart)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月"
        return fmt.string(from: lastMonthStart)
    }

    // MARK: - Report Card

    private var reportCard: some View {
        VStack(spacing: DS.Spacing.l) {
            // 标题
            VStack(spacing: 4) {
                Text("Pulse")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.accent)
                    .tracking(2)

                Text(monthLabel)
                    .font(DS.Typography.bodyL.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)

                Text(String(localized: "月度健康报告"))
                    .font(DS.Typography.bodyS)
                    .foregroundStyle(DS.Color.inkDim)
            }

            // 核心指标
            metricsGrid

            // 评分日历热力图
            scoreHeatmap

            // 趋势对比
            trendComparison

            // 洞察
            monthlyInsight
        }
        .padding(DS.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Color.bgElev)
                
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Color.line.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        let data = lastMonthSummaries
        let prev = prevMonthSummaries

        let avgScore = data.compactMap(\.dailyScore).isEmpty ? nil :
            data.compactMap(\.dailyScore).reduce(0, +) / data.compactMap(\.dailyScore).count
        let avgHRV = data.compactMap(\.averageHRV).isEmpty ? nil :
            data.compactMap(\.averageHRV).reduce(0, +) / Double(data.compactMap(\.averageHRV).count)
        let avgSleep = data.compactMap(\.sleepDurationMinutes).isEmpty ? nil :
            Double(data.compactMap(\.sleepDurationMinutes).reduce(0, +)) / Double(data.compactMap(\.sleepDurationMinutes).count) / 60.0
        let avgRHR = data.compactMap(\.restingHeartRate).isEmpty ? nil :
            data.compactMap(\.restingHeartRate).reduce(0, +) / Double(data.compactMap(\.restingHeartRate).count)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.m) {
            metricCard(
                icon: "chart.line.uptrend.xyaxis", label: String(localized: "平均评分"),
                value: avgScore.map { "\($0)" } ?? "—",
                color: DS.Color.accent
            )
            metricCard(
                icon: "waveform.path.ecg", label: "HRV",
                value: avgHRV.map { String(format: "%.0f ms", $0) } ?? "—",
                color: DS.Color.accent
            )
            metricCard(
                icon: "moon.fill", label: String(localized: "睡眠"),
                value: avgSleep.map { String(format: "%.1fh", $0) } ?? "—",
                color: DS.Color.accent
            )
            metricCard(
                icon: "heart.fill", label: String(localized: "静息心率"),
                value: avgRHR.map { String(format: "%.0f bpm", $0) } ?? "—",
                color: DS.Color.accent
            )
        }
    }

    private func metricCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(DS.Typography.bodyS.weight(.medium))
                .foregroundStyle(color)
            Text(value)
                .font(DS.Typography.title2.weight(.bold))
                .foregroundStyle(DS.Color.ink)
            Text(label)
                .font(DS.Typography.caption.weight(.medium))
                .foregroundStyle(DS.Color.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .fill(DS.Color.bgElev)
        )
    }

    // MARK: - Score Heatmap

    private var scoreHeatmap: some View {
        let data = lastMonthSummaries.sorted { $0.date < $1.date }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(String(localized: "每日评分"))
                .font(DS.Typography.bodyS.weight(.semibold))
                .foregroundStyle(DS.Color.inkMid)

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(data, id: \.id) { summary in
                    let score = summary.dailyScore ?? 0
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(PulseTheme.statusColor(for: score).opacity(score > 0 ? 0.7 : 0.1))
                        .frame(height: 20)
                        .overlay {
                            if score > 0 {
                                Text("\(score)")
                                    .font(DS.Typography.monoS.weight(.bold))
                                    .foregroundStyle(DS.Color.inkMid)
                            }
                        }
                }
            }

            // 图例
            HStack(spacing: DS.Spacing.m) {
                legendItem(color: DS.Color.bad, label: "<40")
                legendItem(color: DS.Color.warn, label: "40-70")
                legendItem(color: DS.Color.good, label: "70+")
                Spacer()
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color.opacity(0.7))
                .frame(width: DS.Spacing.s + DS.Spacing.xs, height: DS.Spacing.s + DS.Spacing.xs)
            Text(label)
                .font(DS.Typography.monoS)
                .foregroundStyle(DS.Color.inkDim)
        }
    }

    // MARK: - Trend Comparison

    private var trendComparison: some View {
        let cur = lastMonthSummaries
        let prev = prevMonthSummaries

        func avgScore(_ s: [DailySummary]) -> Int? {
            let v = s.compactMap(\.dailyScore)
            return v.isEmpty ? nil : v.reduce(0, +) / v.count
        }

        let curScore = avgScore(cur)
        let prevScore = avgScore(prev)
        let workouts = allWorkouts.filter { w in
            let cal = Calendar.current
            let thisMonthStart = cal.safeDate(from: cal.dateComponents([.year, .month], from: .now))
            let lastMonthStart = cal.safeDate(byAdding: .month, value: -1, to: thisMonthStart)
            return w.startDate >= lastMonthStart && w.startDate < thisMonthStart
        }.count

        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(String(localized: "与上月对比"))
                .font(DS.Typography.bodyS.weight(.semibold))
                .foregroundStyle(DS.Color.inkMid)

            HStack(spacing: 0) {
                comparisonItem(
                    label: String(localized: "评分"),
                    current: curScore.map { "\($0)" } ?? "—",
                    delta: scoreDelta(cur: curScore, prev: prevScore)
                )
                comparisonItem(
                    label: String(localized: "训练"),
                    current: "\(workouts)",
                    delta: nil
                )
                comparisonItem(
                    label: String(localized: "数据天数"),
                    current: "\(cur.count)",
                    delta: nil
                )
            }
        }
    }

    private func comparisonItem(label: String, current: String, delta: (String, Bool)?) -> some View {
        VStack(spacing: 4) {
            Text(current)
                .font(DS.Typography.bodyL.weight(.bold))
                .foregroundStyle(DS.Color.ink)
            Text(label)
                .font(DS.Typography.mono.weight(.medium))
                .foregroundStyle(DS.Color.inkDim)
            if let (text, positive) = delta {
                Text(text)
                    .font(DS.Typography.mono.weight(.semibold))
                    .foregroundStyle(positive ? DS.Color.accent : DS.Color.accent)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.m)
                    .background(Capsule().fill((positive ? DS.Color.accent : DS.Color.accent).opacity(0.12)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreDelta(cur: Int?, prev: Int?) -> (String, Bool)? {
        guard let c = cur, let p = prev, abs(c - p) > 1 else { return nil }
        let diff = c - p
        return (diff > 0 ? "+\(diff)" : "\(diff)", diff > 0)
    }

    // MARK: - Monthly Insight

    private var monthlyInsight: some View {
        let data = lastMonthSummaries
        let scores = data.compactMap(\.dailyScore)
        let bestDay = data.compactMap { s -> (Date, Int)? in s.dailyScore.map { (s.date, $0) } }.max(by: { $0.1 < $1.1 })

        let insight: String = {
            guard !scores.isEmpty else { return String(localized: "数据不足，继续佩戴 Apple Watch") }

            var lines: [String] = []
            let avg = scores.reduce(0, +) / scores.count

            if avg >= 75 {
                lines.append(String(localized: "这个月整体状态不错，继续保持！"))
            } else if avg >= 55 {
                lines.append(String(localized: "状态中等，关注睡眠和恢复"))
            } else {
                lines.append(String(localized: "需要更多休息，减少训练强度"))
            }

            if let best = bestDay {
                let fmt = DateFormatter()
                fmt.dateFormat = "M/d"
                lines.append(String(format: String(localized: "最佳状态: %@ (%d分)"), fmt.string(from: best.0), best.1))
            }

            return lines.joined(separator: "\n")
        }()

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.warn)
                Text(String(localized: "月度洞察"))
                    .font(DS.Typography.bodyS.weight(.semibold))
                    .foregroundStyle(DS.Color.inkMid)
            }

            Text(insight)
                .font(DS.Typography.bodyS)
                .foregroundStyle(DS.Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .fill(DS.Color.warn.opacity(0.06))
        )
    }

    // MARK: - Share

    private var shareButton: some View {
        ShareLink(
            item: Image(uiImage: renderShareImage()),
            preview: SharePreview(String(localized: "Pulse 月度报告"), image: Image(uiImage: renderShareImage()))
        ) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "square.and.arrow.up")
                Text(String(localized: "分享月报"))
            }
            .font(DS.Typography.body.weight(.medium))
            .foregroundStyle(DS.Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.card)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                    .fill(DS.Color.bgElev)
            )
        }
    }

    @MainActor
    private func renderShareImage() -> UIImage {
        if let cached = renderedImage { return cached }

        let renderer = ImageRenderer(content:
            reportCard
                .frame(width: 390)
                .padding(DS.Spacing.m)
                .background(DS.Color.bg)
        )
        renderer.scale = 3
        let image = renderer.uiImage ?? UIImage()
        renderedImage = image
        return image
    }
}

#Preview {
    MonthlyReportView()
        .preferredColorScheme(.dark)
}
