import SwiftUI
import SwiftData
import Charts

/// 周报详情页 — 可分享的周报卡片，包含评分、图表、AI 洞察
struct WeeklyReportView: View {

    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @State private var reportImage: Image?
    @State private var renderedUIImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 可分享的报告卡片
                    reportCard
                        .staggered(index: 0)

                    // 分享按钮
                    shareButton
                        .staggered(index: 1)
                        .padding(.top, PulseTheme.spacingM)

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingS)
            }
            .background(PulseTheme.background)
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PulseTheme.accent)
                }
            }
            .task {
                renderShareImage()
            }
        }
    }

    // MARK: - 周数据

    private var thisWeekSummaries: [DailySummary] {
        summariesForWeek(offset: 0)
    }

    private var lastWeekSummaries: [DailySummary] {
        summariesForWeek(offset: -1)
    }

    private func summariesForWeek(offset: Int) -> [DailySummary] {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7

        guard let thisMonday = cal.date(byAdding: .day, value: -daysSinceMonday, to: cal.startOfDay(for: now)),
              let startDate = cal.date(byAdding: .weekOfYear, value: offset, to: thisMonday),
              let endDate = cal.date(byAdding: .day, value: 7, to: startDate) else {
            return []
        }

        return allSummaries.filter { $0.date >= startDate && $0.date < endDate }
    }

    // MARK: - 日期范围标题

    private var dateRangeTitle: String {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7

        guard let monday = cal.date(byAdding: .day, value: -daysSinceMonday, to: cal.startOfDay(for: now)),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else {
            return String(localized: "This Week")
        }

        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateStyle = .medium

        return "\(fmt.string(from: monday)) - \(fmt.string(from: sunday))"
    }

    // MARK: - 报告卡片

    @ViewBuilder
    private var reportCard: some View {
        VStack(spacing: PulseTheme.spacingL) {
            // 头部：日期范围 + 品牌
            reportHeader

            // 平均评分 + 对比
            scoreOverview

            // 每日评分柱状图
            dailyScoreChart

            // 关键指标对比
            metricsComparison

            // AI 洞察总结
            aiInsightsSection

            // 下周建议
            nextWeekAdvice

            // 底部品牌
            reportFooter
        }
        .padding(PulseTheme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PulseTheme.cardBackground,
                            Color(hex: "1C1915"),
                            PulseTheme.cardBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: PulseTheme.cardShadow, radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [PulseTheme.accent.opacity(0.3), PulseTheme.border.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - 头部

    private var reportHeader: some View {
        VStack(spacing: PulseTheme.spacingS) {
            HStack {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
                Text("Pulse Weekly")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
            }

            HStack {
                Text(dateRangeTitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - 评分总览

    private var scoreOverview: some View {
        let thisAvg = averageScore(thisWeekSummaries)
        let lastAvg = averageScore(lastWeekSummaries)
        let delta: Int? = {
            guard let t = thisAvg, let l = lastAvg else { return nil }
            return t - l
        }()

        return HStack(alignment: .bottom, spacing: PulseTheme.spacingM) {
            // 左侧：大评分
            VStack(alignment: .leading, spacing: 2) {
                Text("Avg Score")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)

                HStack(alignment: .firstTextBaseline, spacing: PulseTheme.spacingS) {
                    Text("\(thisAvg ?? 0)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.statusColor(for: thisAvg ?? 50))

                    // 对比箭头
                    if let delta {
                        HStack(spacing: 2) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 14, weight: .bold))
                            Text("\(abs(delta))")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(delta >= 0 ? PulseTheme.statusGood : PulseTheme.statusPoor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill((delta >= 0 ? PulseTheme.statusGood : PulseTheme.statusPoor).opacity(0.12))
                        )
                    }
                }
            }

            Spacer()

            // 右侧：状态标签
            if let avg = thisAvg {
                Text(PulseTheme.statusLabel(for: avg))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.statusColor(for: avg))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(PulseTheme.statusColor(for: avg).opacity(0.12))
                    )
            }
        }
    }

    // MARK: - 每日评分柱状图

    private var dailyScoreChart: some View {
        let data = buildDailyChartData()

        return VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Daily Score")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)

            if data.isEmpty {
                emptyPlaceholder(String(localized: "No data this week"))
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(data, id: \.dayLabel) { item in
                        VStack(spacing: 4) {
                            // 分数标签
                            Text("\(item.score)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(PulseTheme.statusColor(for: item.score))

                            // 柱子
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            PulseTheme.statusColor(for: item.score),
                                            PulseTheme.statusColor(for: item.score).opacity(0.5)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: CGFloat(item.score) / 100.0 * 100)

                            // 星期标签
                            Text(item.dayLabel)
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundStyle(item.isToday ? PulseTheme.accent : PulseTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 140)
                .padding(.vertical, PulseTheme.spacingS)
            }
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.surface)
        )
    }

    // MARK: - 关键指标对比

    private var metricsComparison: some View {
        let thisHR = averageValue(thisWeekSummaries, keyPath: \.restingHeartRate)
        let lastHR = averageValue(lastWeekSummaries, keyPath: \.restingHeartRate)
        let thisHRV = averageValue(thisWeekSummaries, keyPath: \.averageHRV)
        let lastHRV = averageValue(lastWeekSummaries, keyPath: \.averageHRV)
        let thisSleep = averageSleepHours(thisWeekSummaries)
        let lastSleep = averageSleepHours(lastWeekSummaries)
        let thisSteps = averageSteps(thisWeekSummaries)
        let lastSteps = averageSteps(lastWeekSummaries)

        return VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Key Metrics vs Last Week")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: PulseTheme.spacingS),
                GridItem(.flexible(), spacing: PulseTheme.spacingS)
            ], spacing: PulseTheme.spacingS) {
                metricTile(
                    icon: "heart.fill",
                    label: String(localized: "Resting HR"),
                    value: thisHR.map { "\(Int($0))" } ?? "--",
                    unit: "bpm",
                    delta: percentDelta(thisHR, lastHR),
                    invertDelta: true, // 心率降低是好事
                    color: PulseTheme.statusPoor
                )

                metricTile(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: thisHRV.map { "\(Int($0))" } ?? "--",
                    unit: "ms",
                    delta: percentDelta(thisHRV, lastHRV),
                    color: PulseTheme.accent
                )

                metricTile(
                    icon: "moon.fill",
                    label: String(localized: "Sleep"),
                    value: thisSleep.map { String(format: "%.1f", $0) } ?? "--",
                    unit: String(localized: "hour"),
                    delta: percentDelta(thisSleep, lastSleep),
                    color: PulseTheme.sleepAccent
                )

                metricTile(
                    icon: "figure.walk",
                    label: String(localized: "Steps"),
                    value: thisSteps.map { formatSteps(Int($0)) } ?? "--",
                    unit: "",
                    delta: percentDelta(thisSteps, lastSteps),
                    color: PulseTheme.statusGood
                )
            }
        }
    }

    private func metricTile(
        icon: String,
        label: String,
        value: String,
        unit: String,
        delta: Double?,
        invertDelta: Bool = false,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            // 对比 delta
            if let delta {
                let isGood = invertDelta ? delta <= 0 : delta >= 0
                HStack(spacing: 2) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.0f%%", abs(delta)))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundStyle(isGood ? PulseTheme.statusGood : PulseTheme.statusPoor)
            } else {
                Text("--")
                    .font(.system(size: 10))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                .fill(PulseTheme.surface)
        )
    }

    // MARK: - AI 洞察总结

    private var aiInsightsSection: some View {
        let insights = generateWeeklyInsights()

        return VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack(spacing: PulseTheme.spacingXS) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
                Text("AI Insights")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: PulseTheme.spacingS) {
                        Circle()
                            .fill(PulseTheme.accent)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        Text(insight)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(PulseTheme.textSecondary)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(PulseTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.05))
            )
        }
    }

    // MARK: - 下周建议

    private var nextWeekAdvice: some View {
        let advice = generateNextWeekAdvice()

        return VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack(spacing: PulseTheme.spacingXS) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PulseTheme.statusModerate)
                Text("Next Week's Advice")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                ForEach(advice, id: \.self) { tip in
                    HStack(alignment: .top, spacing: PulseTheme.spacingS) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(PulseTheme.statusModerate)
                            .padding(.top, 5)
                        Text(tip)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(PulseTheme.textSecondary)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(PulseTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                    .fill(PulseTheme.statusModerate.opacity(0.05))
            )
        }
    }

    // MARK: - 底部品牌

    private var reportFooter: some View {
        HStack {
            Spacer()
            Text("Pulse Watch")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary.opacity(0.5))
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 10))
                .foregroundStyle(PulseTheme.accent.opacity(0.5))
            Spacer()
        }
        .padding(.top, PulseTheme.spacingS)
    }

    // MARK: - 分享按钮

    @ViewBuilder
    private var shareButton: some View {
        if let uiImage = renderedUIImage {
            let image = Image(uiImage: uiImage)
            ShareLink(
                item: image,
                preview: SharePreview(String(localized: "Pulse Weekly"), image: image)
            ) {
                HStack(spacing: PulseTheme.spacingS) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                    Text("Share Report")
                        .font(PulseTheme.bodyFont.weight(.medium))
                }
                .foregroundStyle(PulseTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .fill(PulseTheme.accent)
                        .shadow(color: PulseTheme.accent.opacity(0.3), radius: 8, y: 4)
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: PulseTheme.spacingS) {
                ProgressView()
                    .tint(PulseTheme.textTertiary)
                    .scaleEffect(0.8)
                Text("Generating share image...")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 渲染分享图片

    @MainActor
    private func renderShareImage() {
        Analytics.trackShareTapped(source: "weekly_report")
        let renderer = ImageRenderer(content:
            reportCardForShare
                .frame(width: 390)
                .background(PulseTheme.background)
        )
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            renderedUIImage = uiImage
            reportImage = Image(uiImage: uiImage)
        }
    }

    /// 分享用的报告卡片（不含交互元素）
    private var reportCardForShare: some View {
        VStack(spacing: PulseTheme.spacingL) {
            reportHeader
            scoreOverview
            dailyScoreChart
            metricsComparison
            aiInsightsSection
            nextWeekAdvice
            reportFooter
        }
        .padding(PulseTheme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
        .padding(PulseTheme.spacingM)
    }

    // MARK: - 数据计算

    private struct DayChartItem {
        let dayLabel: String
        let score: Int
        let isToday: Bool
    }

    private func buildDailyChartData() -> [DayChartItem] {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        guard let monday = cal.date(byAdding: .day, value: -daysSinceMonday, to: cal.startOfDay(for: now)) else {
            return []
        }

        var items: [DayChartItem] = []
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: i, to: monday) else { continue }
            let dayStart = cal.startOfDay(for: day)
            let summary = thisWeekSummaries.first { cal.isDate($0.date, inSameDayAs: dayStart) }
            let score = summary?.dailyScore ?? 0
            let isToday = cal.isDateInToday(day)

            // 只显示过去和今天的数据
            if day <= now {
                items.append(DayChartItem(dayLabel: labels[i], score: score, isToday: isToday))
            }
        }
        return items
    }

    private func averageScore(_ summaries: [DailySummary]) -> Int? {
        let scores = summaries.compactMap(\.dailyScore)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    private func averageValue(_ summaries: [DailySummary], keyPath: KeyPath<DailySummary, Double?>) -> Double? {
        let values = summaries.compactMap { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func averageSleepHours(_ summaries: [DailySummary]) -> Double? {
        let values = summaries.compactMap(\.sleepDurationMinutes).filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count) / 60.0
    }

    private func averageSteps(_ summaries: [DailySummary]) -> Double? {
        let values = summaries.compactMap(\.totalSteps)
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private func percentDelta(_ current: Double?, _ previous: Double?) -> Double? {
        guard let c = current, let p = previous, p != 0 else { return nil }
        return ((c - p) / p) * 100
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 10000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        } else {
            return "\(steps)"
        }
    }

    // MARK: - AI 洞察生成

    private func generateWeeklyInsights() -> [String] {
        var insights: [String] = []
        let summaries = thisWeekSummaries
        let scores = summaries.compactMap(\.dailyScore)

        guard !scores.isEmpty else {
            return ["Insufficient data — keep wearing your device"]
        }

        // 最佳/最差日分析
        if let bestDay = summaries.filter({ $0.dailyScore != nil }).max(by: { ($0.dailyScore ?? 0) < ($1.dailyScore ?? 0) }),
           let worstDay = summaries.filter({ $0.dailyScore != nil }).min(by: { ($0.dailyScore ?? 0) < ($1.dailyScore ?? 0) }) {

            let fmt = DateFormatter()
            fmt.locale = Locale.current
            fmt.dateFormat = "EEEE"

            let bestLabel = fmt.string(from: bestDay.date)
            let worstLabel = fmt.string(from: worstDay.date)

            // 最佳日原因
            var bestReason = ""
            if let sleep = bestDay.sleepDurationMinutes, sleep >= 420 {
                bestReason = "(Good sleep \(sleep / 60)h\(sleep % 60)m)"
            } else if let hrv = bestDay.averageHRV, hrv > 50 {
                bestReason = "(Good HRV \(Int(hrv))ms)"
            }
            insights.append("Best: \(bestLabel) \(bestDay.dailyScore ?? 0)pts\(bestReason)")

            // 最差日原因
            if bestDay.dateString != worstDay.dateString {
                var worstReason = ""
                if let sleep = worstDay.sleepDurationMinutes, sleep > 0, sleep < 360 {
                    worstReason = "(Low sleep \(sleep / 60)h\(sleep % 60)m)"
                } else if let rhr = worstDay.restingHeartRate, rhr > 70 {
                    worstReason = "(Elevated RHR \(Int(rhr))bpm)"
                }
                insights.append("Worst: \(worstLabel) \(worstDay.dailyScore ?? 0)pts\(worstReason)")
            }
        }

        // 整体趋势
        let avgScore = scores.reduce(0, +) / scores.count
        let lastAvg = averageScore(lastWeekSummaries)
        if let lastAvg {
            let diff = avgScore - lastAvg
            if diff > 5 {
                insights.append("Overall improvement — keep up the rhythm")
            } else if diff < -5 {
                insights.append("Slight decline this week — adjust rest and training")
            } else {
                insights.append("Stable — your body is adapting well")
            }
        }

        // 睡眠规律性
        let sleeps = summaries.compactMap(\.sleepDurationMinutes).filter { $0 > 0 }
        if sleeps.count >= 3 {
            let avg = Double(sleeps.reduce(0, +)) / Double(sleeps.count) / 60.0
            if avg < 6.5 {
                insights.append("Avg sleep \(String(format: "%.1f", avg))h this week — consider sleeping more")
            }
        }

        return insights.isEmpty ? ["Building data — more detailed analysis next week"] : insights
    }

    // MARK: - 下周建议生成

    private func generateNextWeekAdvice() -> [String] {
        var advice: [String] = []
        let summaries = thisWeekSummaries
        let scores = summaries.compactMap(\.dailyScore)

        guard !scores.isEmpty else {
            return ["Keep wearing your device to build a baseline"]
        }

        let avgScore = scores.reduce(0, +) / scores.count

        // 基于评分趋势建议
        if avgScore >= 75 {
            advice.append("Excellent — push harder or try something new")
        } else if avgScore >= 55 {
            advice.append("Maintain your pace, focus on recovery and nutrition")
        } else {
            advice.append("Reduce intensity, prioritize sleep quality")
        }

        // 睡眠建议
        let sleeps = summaries.compactMap(\.sleepDurationMinutes).filter { $0 > 0 }
        if sleeps.count >= 3 {
            let avg = Double(sleeps.reduce(0, +)) / Double(sleeps.count) / 60.0
            if avg < 7 {
                advice.append("Goal: ≥ 7 hours nightly, try a consistent bedtime")
            }
        }

        // HRV 趋势建议
        let hrvValues = summaries.compactMap(\.averageHRV)
        if hrvValues.count >= 3 {
            let trend = hrvValues.enumerated().reduce(0.0) { acc, pair in
                acc + (pair.element - (hrvValues.first ?? 0)) / max(1, Double(pair.offset))
            } / Double(hrvValues.count)

            if trend < -2 {
                advice.append("HRV trending down — manage stress and recovery")
            }
        }

        return advice.isEmpty ? ["Keep up the good habits"] : advice
    }

    // MARK: - 空占位

    private func emptyPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(PulseTheme.captionFont)
            .foregroundStyle(PulseTheme.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
    }
}

#Preview {
    WeeklyReportView()
        .preferredColorScheme(.dark)
}
