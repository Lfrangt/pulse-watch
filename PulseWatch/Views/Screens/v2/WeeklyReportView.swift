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
                        .padding(.top, DS.Spacing.m)

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, DS.Spacing.m)
                .padding(.top, DS.Spacing.s)
            }
            .background(DS.Color.bg)
            .navigationTitle(String(localized: "Weekly Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                        .foregroundStyle(DS.Color.accent)
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
        VStack(spacing: DS.Spacing.l) {
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
        .padding(DS.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DS.Color.bgElev,
                            DS.Color.bgElev,
                            DS.Color.bgElev
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [DS.Color.accent.opacity(0.3), DS.Color.line.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - 头部

    private var reportHeader: some View {
        VStack(spacing: DS.Spacing.s) {
            HStack {
                Image(systemName: "doc.richtext")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Color.accent)
                Text("Pulse Weekly")
                    .font(DS.Typography.bodyL.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)
                Spacer()
            }

            HStack {
                Text(dateRangeTitle)
                    .font(DS.Typography.bodyS.weight(.medium))
                    .foregroundStyle(DS.Color.inkMid)
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

        return HStack(alignment: .bottom, spacing: DS.Spacing.m) {
            // 左侧：大评分
            VStack(alignment: .leading, spacing: 2) {
                Text("Avg Score")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)

                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                    Text("\(thisAvg ?? 0)")
                        .font(DS.Typography.display3)
                        .foregroundStyle(PulseTheme.statusColor(for: thisAvg ?? 50))

                    // 对比箭头
                    if let delta {
                        HStack(spacing: 2) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(DS.Typography.bodyS.weight(.bold))
                            Text("\(abs(delta))")
                                .font(DS.Typography.body.weight(.semibold))
                        }
                        .foregroundStyle(delta >= 0 ? DS.Color.good : DS.Color.bad)
                        .padding(.horizontal, DS.Spacing.s)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(
                            Capsule()
                                .fill((delta >= 0 ? DS.Color.good : DS.Color.bad).opacity(0.12))
                        )
                    }
                }
            }

            Spacer()

            // 右侧：状态标签
            if let avg = thisAvg {
                Text(PulseTheme.statusLabel(for: avg))
                    .font(DS.Typography.bodyS.weight(.medium))
                    .foregroundStyle(PulseTheme.statusColor(for: avg))
                    .padding(.horizontal, DS.Spacing.s)
                    .padding(.vertical, DS.Spacing.xs)
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

        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Daily Score")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkDim)

            if data.isEmpty {
                emptyPlaceholder(String(localized: "No data this week"))
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(data, id: \.dayLabel) { item in
                        VStack(spacing: 4) {
                            // 分数标签
                            Text("\(item.score)")
                                .font(DS.Typography.mono.weight(.medium))
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
                                .font(DS.Typography.mono)
                                .foregroundStyle(item.isToday ? DS.Color.accent : DS.Color.inkDim)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 140)
                .padding(.vertical, DS.Spacing.s)
            }
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                .fill(DS.Color.bgElev)
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

        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Key Metrics vs Last Week")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkDim)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: DS.Spacing.s),
                GridItem(.flexible(), spacing: DS.Spacing.s)
            ], spacing: DS.Spacing.s) {
                metricTile(
                    icon: "heart.fill",
                    label: String(localized: "Resting HR"),
                    value: thisHR.map { "\(Int($0))" } ?? "--",
                    unit: "bpm",
                    delta: percentDelta(thisHR, lastHR),
                    invertDelta: true, // 心率降低是好事
                    color: DS.Color.bad
                )

                metricTile(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: thisHRV.map { "\(Int($0))" } ?? "--",
                    unit: "ms",
                    delta: percentDelta(thisHRV, lastHRV),
                    color: DS.Color.accent
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
                    color: DS.Color.good
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
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(DS.Typography.caption)
                    .foregroundStyle(color)
                Text(label)
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Color.inkDim)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(DS.Typography.title2.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.inkDim)
                }
            }

            // 对比 delta
            if let delta {
                let isGood = invertDelta ? delta <= 0 : delta >= 0
                HStack(spacing: 2) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(DS.Typography.monoS.weight(.bold))
                    Text(String(format: "%.0f%%", abs(delta)))
                        .font(DS.Typography.mono.weight(.medium))
                }
                .foregroundStyle(isGood ? DS.Color.good : DS.Color.bad)
            } else {
                Text("--")
                    .font(DS.Typography.mono)
                    .foregroundStyle(DS.Color.inkDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .fill(DS.Color.bgElev)
        )
    }

    // MARK: - AI 洞察总结

    private var aiInsightsSection: some View {
        let insights = generateWeeklyInsights()

        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Color.accent)
                Text("AI Insights")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: DS.Spacing.s) {
                        Circle()
                            .fill(DS.Color.accent)
                            .frame(width: DS.Spacing.xs, height: DS.Spacing.xs)
                            .padding(.top, DS.Spacing.xs)
                        Text(insight)
                            .font(DS.Typography.bodyS)
                            .foregroundStyle(DS.Color.inkMid)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(DS.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Color.accent.opacity(0.05))
            )
        }
    }

    // MARK: - 下周建议

    private var nextWeekAdvice: some View {
        let advice = generateNextWeekAdvice()

        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "lightbulb.fill")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Color.warn)
                Text("Next Week's Advice")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ForEach(advice, id: \.self) { tip in
                    HStack(alignment: .top, spacing: DS.Spacing.s) {
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.monoS.weight(.bold))
                            .foregroundStyle(DS.Color.warn)
                            .padding(.top, DS.Spacing.m)
                        Text(tip)
                            .font(DS.Typography.bodyS)
                            .foregroundStyle(DS.Color.inkMid)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(DS.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Color.warn.opacity(0.05))
            )
        }
    }

    // MARK: - 底部品牌

    private var reportFooter: some View {
        HStack {
            Spacer()
            Text("Pulse Watch")
                .font(DS.Typography.caption.weight(.medium))
                .foregroundStyle(DS.Color.inkDim.opacity(0.5))
            Image(systemName: "heart.text.clipboard")
                .font(DS.Typography.mono)
                .foregroundStyle(DS.Color.accent.opacity(0.5))
            Spacer()
        }
        .padding(.top, DS.Spacing.s)
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
                HStack(spacing: DS.Spacing.s) {
                    Image(systemName: "square.and.arrow.up")
                        .font(DS.Typography.body.weight(.medium))
                    Text("Share Report")
                        .font(DS.Typography.body.weight(.medium))
                }
                .foregroundStyle(DS.Color.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                        .fill(DS.Color.accent)
                        
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: DS.Spacing.s) {
                ProgressView()
                    .tint(DS.Color.inkDim)
                    .scaleEffect(0.8)
                Text("Generating share image...")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.m)
        }
    }

    // MARK: - 渲染分享图片

    @MainActor
    private func renderShareImage() {
        Analytics.trackShareTapped(source: "weekly_report")
        let renderer = ImageRenderer(content:
            reportCardForShare
                .frame(width: 390)
                .background(DS.Color.bg)
        )
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            renderedUIImage = uiImage
            reportImage = Image(uiImage: uiImage)
        }
    }

    /// 分享用的报告卡片（不含交互元素）
    private var reportCardForShare: some View {
        VStack(spacing: DS.Spacing.l) {
            reportHeader
            scoreOverview
            dailyScoreChart
            metricsComparison
            aiInsightsSection
            nextWeekAdvice
            reportFooter
        }
        .padding(DS.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Color.bgElev)
        )
        .padding(DS.Spacing.m)
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
        let labels = [String(localized: "Mon"), String(localized: "Tue"), String(localized: "Wed"), String(localized: "Thu"), String(localized: "Fri"), String(localized: "Sat"), String(localized: "Sun")]

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
            return [String(localized: "Insufficient data — keep wearing your device")]
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
                insights.append(String(localized: "Overall improvement — keep up the rhythm"))
            } else if diff < -5 {
                insights.append(String(localized: "Slight decline this week — adjust rest and training"))
            } else {
                insights.append(String(localized: "Stable — your body is adapting well"))
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

        return insights.isEmpty ? [String(localized: "Building data — more detailed analysis next week")] : insights
    }

    // MARK: - 下周建议生成

    private func generateNextWeekAdvice() -> [String] {
        var advice: [String] = []
        let summaries = thisWeekSummaries
        let scores = summaries.compactMap(\.dailyScore)

        guard !scores.isEmpty else {
            return [String(localized: "Keep wearing your device to build a baseline")]
        }

        let avgScore = scores.reduce(0, +) / scores.count

        // 基于评分趋势建议
        if avgScore >= 75 {
            advice.append(String(localized: "Excellent — push harder or try something new"))
        } else if avgScore >= 55 {
            advice.append(String(localized: "Maintain your pace, focus on recovery and nutrition"))
        } else {
            advice.append(String(localized: "Reduce intensity, prioritize sleep quality"))
        }

        // 睡眠建议
        let sleeps = summaries.compactMap(\.sleepDurationMinutes).filter { $0 > 0 }
        if sleeps.count >= 3 {
            let avg = Double(sleeps.reduce(0, +)) / Double(sleeps.count) / 60.0
            if avg < 7 {
                advice.append(String(localized: "Goal: ≥ 7 hours nightly, try a consistent bedtime"))
            }
        }

        // HRV 趋势建议
        let hrvValues = summaries.compactMap(\.averageHRV)
        if hrvValues.count >= 3 {
            let trend = hrvValues.enumerated().reduce(0.0) { acc, pair in
                acc + (pair.element - (hrvValues.first ?? 0)) / max(1, Double(pair.offset))
            } / Double(hrvValues.count)

            if trend < -2 {
                advice.append(String(localized: "HRV trending down — manage stress and recovery"))
            }
        }

        return advice.isEmpty ? [String(localized: "Keep up the good habits")] : advice
    }

    // MARK: - 空占位

    private func emptyPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Color.inkDim)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
    }
}

#Preview {
    WeeklyReportView()
        .preferredColorScheme(.dark)
}
