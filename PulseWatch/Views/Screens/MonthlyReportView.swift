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
                            .padding(.top, PulseTheme.spacingM)
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingS)
            }
            .background(PulseTheme.background)
            .navigationTitle(String(localized: "月度报告"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "完成")) { dismiss() }
                        .foregroundStyle(PulseTheme.accent)
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
        VStack(spacing: PulseTheme.spacingL) {
            // 标题
            VStack(spacing: 4) {
                Text("Pulse")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.accentTeal)
                    .tracking(2)

                Text(monthLabel)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(String(localized: "月度健康报告"))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
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
        .padding(PulseTheme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow, radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
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

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PulseTheme.spacingM) {
            metricCard(
                icon: "chart.line.uptrend.xyaxis", label: String(localized: "平均评分"),
                value: avgScore.map { "\($0)" } ?? "—",
                color: PulseTheme.accentTeal
            )
            metricCard(
                icon: "waveform.path.ecg", label: "HRV",
                value: avgHRV.map { String(format: "%.0f ms", $0) } ?? "—",
                color: PulseTheme.hrvBlue
            )
            metricCard(
                icon: "moon.fill", label: String(localized: "睡眠"),
                value: avgSleep.map { String(format: "%.1fh", $0) } ?? "—",
                color: PulseTheme.sleepViolet
            )
            metricCard(
                icon: "heart.fill", label: String(localized: "静息心率"),
                value: avgRHR.map { String(format: "%.0f bpm", $0) } ?? "—",
                color: PulseTheme.activityCoral
            )
        }
    }

    private func metricCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                .fill(PulseTheme.surface2)
        )
    }

    // MARK: - Score Heatmap

    private var scoreHeatmap: some View {
        let data = lastMonthSummaries.sorted { $0.date < $1.date }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

        return VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text(String(localized: "每日评分"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(data, id: \.id) { summary in
                    let score = summary.dailyScore ?? 0
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(PulseTheme.statusColor(for: score).opacity(score > 0 ? 0.7 : 0.1))
                        .frame(height: 20)
                        .overlay {
                            if score > 0 {
                                Text("\(score)")
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundStyle(PulseTheme.textSecondary)
                            }
                        }
                }
            }

            // 图例
            HStack(spacing: PulseTheme.spacingM) {
                legendItem(color: PulseTheme.statusPoor, label: "<40")
                legendItem(color: PulseTheme.statusModerate, label: "40-70")
                legendItem(color: PulseTheme.statusGood, label: "70+")
                Spacer()
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color.opacity(0.7))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
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

        return VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text(String(localized: "与上月对比"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)

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
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
            if let (text, positive) = delta {
                Text(text)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(positive ? PulseTheme.accentTeal : PulseTheme.activityCoral)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill((positive ? PulseTheme.accentTeal : PulseTheme.activityCoral).opacity(0.12)))
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
                    .font(.system(size: 12))
                    .foregroundStyle(PulseTheme.statusWarning)
                Text(String(localized: "月度洞察"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
            }

            Text(insight)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                .fill(PulseTheme.statusWarning.opacity(0.06))
        )
    }

    // MARK: - Share

    private var shareButton: some View {
        ShareLink(
            item: Image(uiImage: renderShareImage()),
            preview: SharePreview(String(localized: "Pulse 月度报告"), image: Image(uiImage: renderShareImage()))
        ) {
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "square.and.arrow.up")
                Text(String(localized: "分享月报"))
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(PulseTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.surface2)
            )
        }
    }

    @MainActor
    private func renderShareImage() -> UIImage {
        if let cached = renderedImage { return cached }

        let renderer = ImageRenderer(content:
            reportCard
                .frame(width: 390)
                .padding(PulseTheme.spacingM)
                .background(PulseTheme.background)
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
