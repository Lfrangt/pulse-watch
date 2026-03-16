import SwiftUI
import SwiftData
import Charts

/// Tab 2: 历史趋势 — 折线图 + 周报对比
struct HistoryView: View {

    @State private var selectedRange: TimeRange = .week
    @State private var showWeeklyReport = false
    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @Query(sort: \WorkoutHistoryEntry.startDate, order: .reverse) private var allWorkouts: [WorkoutHistoryEntry]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseTheme.spacingM) {
                    // 快捷入口
                    shortcutButtons
                        .staggered(index: 0)

                    // 时间范围切换
                    rangePicker
                        .staggered(index: 0)

                    // 时段摘要对比
                    periodSummaryCard
                        .staggered(index: 1)

                    // 数据不足提示
                    if dataInsufficient {
                        insufficientDataHint
                            .staggered(index: 1)
                    }

                    // 评分趋势
                    scoreTrendChart
                        .staggered(index: 2)

                    // 心率趋势
                    heartRateTrendChart
                        .staggered(index: 3)

                    // HRV 趋势
                    hrvTrendChart
                        .staggered(index: 4)

                    // 睡眠趋势
                    sleepTrendChart
                        .staggered(index: 5)

                    // 周报对比
                    weeklyReportCard
                        .staggered(index: 5)

                    // 查看完整周报按钮
                    weeklyReportButton
                        .staggered(index: 6)

                    // 肌群恢复关联洞察
                    MuscleInsightsCard(workouts: allWorkouts, summaries: allSummaries)
                        .staggered(index: 7)

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingS)
            }
            .background(PulseTheme.background)
            .navigationTitle("Historical Trends")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showWeeklyReport) {
                WeeklyReportView()
                    .preferredColorScheme(.dark)
                    .onAppear { Analytics.trackWeeklyReportViewed() }
            }
            .onAppear {
                // In-App Review: 查看趋势图时检查是否有 7 天完整数据
                let calendar = Calendar.current
                let sevenDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: .now)!)
                let recentWithScores = allSummaries.filter { $0.date >= sevenDaysAgo && $0.dailyScore != nil }
                let hasSevenDayData = recentWithScores.count >= 7
                ReviewRequestManager.shared.recordTrendsViewed(hasSevenDayData: hasSevenDayData)
            }
        }
    }

    // MARK: - 时间范围

    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case quarter = "90D"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            }
        }

        /// 是否需要按周聚合（避免图表过密）
        var shouldAggregate: Bool {
            self == .quarter
        }

        var xAxisStride: Int {
            switch self {
            case .week: return 1
            case .month: return 5
            case .quarter: return 14
            }
        }
    }

    private var rangePicker: some View {
        Picker(String(localized: "Time Range"), selection: $selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, PulseTheme.spacingS)
    }

    // MARK: - 数据过滤

    private var filteredSummaries: [DailySummary] {
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: .now)!
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let raw = allSummaries.filter { $0.date >= startOfDay }
        return raw
    }

    /// 上一个同等时段的数据（用于对比）
    private var previousPeriodSummaries: [DailySummary] {
        let days = selectedRange.days
        let periodEnd = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let periodStart = Calendar.current.date(byAdding: .day, value: -days * 2, to: .now)!
        return allSummaries.filter { $0.date >= periodStart && $0.date < periodEnd }
    }

    /// 数据不足提示
    private var dataInsufficient: Bool {
        filteredSummaries.count < selectedRange.days / 2
    }

    // MARK: - 时段摘要对比

    private var periodSummaryCard: some View {
        let current = filteredSummaries
        let previous = previousPeriodSummaries

        func avgScore(_ summaries: [DailySummary]) -> Int? {
            let scores = summaries.compactMap(\.dailyScore)
            guard !scores.isEmpty else { return nil }
            return scores.reduce(0, +) / scores.count
        }

        func avgHRV(_ summaries: [DailySummary]) -> Double? {
            let vals = summaries.compactMap(\.averageHRV)
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        }

        func avgSleep(_ summaries: [DailySummary]) -> Double? {
            let vals = summaries.compactMap(\.sleepDurationMinutes).map { Double($0) / 60.0 }
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        }

        let curScore = avgScore(current)
        let prevScore = avgScore(previous)
        let curHRV = avgHRV(current)
        let prevHRV = avgHRV(previous)
        let curSleep = avgSleep(current)
        let prevSleep = avgSleep(previous)

        return HStack(spacing: 0) {
            periodMetric(
                label: String(localized: "Avg Score"),
                value: curScore.map { "\($0)" } ?? "—",
                delta: delta(cur: curScore.map(Double.init), prev: prevScore.map(Double.init)),
                icon: "heart.fill"
            )
            periodMetric(
                label: "HRV",
                value: curHRV.map { String(format: "%.0f", $0) } ?? "—",
                delta: delta(cur: curHRV, prev: prevHRV),
                icon: "waveform.path.ecg"
            )
            periodMetric(
                label: String(localized: "Sleep"),
                value: curSleep.map { String(format: "%.1fh", $0) } ?? "—",
                delta: delta(cur: curSleep, prev: prevSleep),
                icon: "moon.fill"
            )
        }
        .pulseCard()
    }

    private func periodMetric(label: String, value: String, delta: (String, Bool)?, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(PulseTheme.textTertiary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(PulseTheme.textTertiary)
            if let (text, positive) = delta {
                Text(text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(positive ? Color(hex: "7FC75C") : Color(hex: "C75C5C"))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func delta(cur: Double?, prev: Double?) -> (String, Bool)? {
        guard let c = cur, let p = prev, p > 0 else { return nil }
        let diff = c - p
        guard abs(diff) > 0.5 else { return nil }
        let sign = diff > 0 ? "+" : ""
        return ("\(sign)\(String(format: "%.0f", diff)) 📈", diff > 0)
    }

    private func deltaPct(cur: Double?, prev: Double?) -> (String, Bool)? {
        guard let c = cur, let p = prev, p > 0 else { return nil }
        let pct = ((c - p) / p) * 100
        guard abs(pct) > 1 else { return nil }
        let sign = pct > 0 ? "+" : ""
        let emoji = pct > 0 ? "📈" : "📉"
        return ("\(sign)\(String(format: "%.0f%%", pct)) \(emoji)", pct > 0)
    }

    private var insufficientDataHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 13))
                .foregroundStyle(PulseTheme.accent)
            Text("Keep wearing your Watch — more data unlocks better trends")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                .fill(PulseTheme.accent.opacity(0.06))
        )
    }

    // MARK: - 评分趋势图

    private var scoreTrendChart: some View {
        let data = filteredSummaries.compactMap { s -> (date: Date, score: Int)? in
            guard let score = s.dailyScore else { return nil }
            return (s.date, score)
        }

        let latestScore = data.last?.score
        let prevAvg = previousPeriodSummaries.compactMap(\.dailyScore)
        let prevAvgVal = prevAvg.isEmpty ? nil : prevAvg.reduce(0,+) / prevAvg.count
        let curAvg = data.isEmpty ? nil : data.map(\.score).reduce(0,+) / data.count
        let scoreDelta = deltaPct(cur: curAvg.map(Double.init), prev: prevAvgVal.map(Double.init))

        return chartCard(
            icon: "chart.line.uptrend.xyaxis",
            title: String(localized: "Daily Score"),
            color: PulseTheme.accent,
            currentValue: latestScore.map { "\($0)" },
            changeText: scoreDelta?.0,
            changePositive: scoreDelta?.1 ?? true
        ) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(data, id: \.date) { item in
                    LineMark(
                        x: .value(String(localized: "Date"), item.date),
                        y: .value(String(localized: "Score"), item.score)
                    )
                    .foregroundStyle(PulseTheme.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value(String(localized: "Date"), item.date),
                        y: .value(String(localized: "Score"), item.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.accent.opacity(0.2), PulseTheme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value(String(localized: "Date"), item.date),
                        y: .value(String(localized: "Score"), item.score)
                    )
                    .foregroundStyle(PulseTheme.accent)
                    .symbolSize(20)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(PulseTheme.border)
                        AxisValueLabel()
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedRange.xAxisStride)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(PulseTheme.border.opacity(0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Daily score trend"))
                .accessibilityValue({
                    let avg = data.map(\.score).reduce(0, +) / max(data.count, 1)
                    return String(localized: "Average score \(avg) over \(data.count) days")
                }())
            }
        }
    }

    // MARK: - 心率趋势图

    private var heartRateTrendChart: some View {
        let data = filteredSummaries.compactMap { s -> (date: Date, avg: Double, resting: Double)? in
            guard let avg = s.averageHeartRate else { return nil }
            return (s.date, avg, s.restingHeartRate ?? avg)
        }

        let latestHR = data.last.map { "\(Int($0.resting)) bpm" }
        let curAvgHR = data.isEmpty ? nil : data.map(\.resting).reduce(0,+) / Double(data.count)
        let prevHR = previousPeriodSummaries.compactMap(\.restingHeartRate)
        let prevAvgHR = prevHR.isEmpty ? nil : prevHR.reduce(0,+) / Double(prevHR.count)
        // For HR, lower is better, so invert
        let hrDelta = deltaPct(cur: curAvgHR, prev: prevAvgHR)
        let hrPositive = hrDelta.map { $0.0.contains("-") } ?? true  // negative HR change = good

        return chartCard(
            icon: "heart.fill",
            title: String(localized: "Heart Rate"),
            color: Color(hex: "C75C5C"),
            currentValue: latestHR,
            changeText: hrDelta?.0,
            changePositive: hrPositive
        ) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(data, id: \.date) { item in
                        LineMark(
                            x: .value(String(localized: "Date"), item.date),
                            y: .value(String(localized: "Avg Heart Rate"), item.avg),
                            series: .value(String(localized: "Type"), String(localized: "Average"))
                        )
                        .foregroundStyle(PulseTheme.statusPoor)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        LineMark(
                            x: .value(String(localized: "Date"), item.date),
                            y: .value(String(localized: "Resting HR"), item.resting),
                            series: .value(String(localized: "Type"), String(localized: "Resting"))
                        )
                        .foregroundStyle(PulseTheme.statusPoor.opacity(0.5))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(PulseTheme.border)
                        AxisValueLabel()
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedRange.xAxisStride)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .chartForegroundStyleScale([
                    String(localized: "Average"): PulseTheme.statusPoor,
                    String(localized: "Resting"): PulseTheme.statusPoor.opacity(0.5),
                ])
                .chartLegend(.visible)
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Heart rate trend"))
                .accessibilityValue({
                    let avg = Int(data.map(\.avg).reduce(0, +) / max(Double(data.count), 1))
                    return String(localized: "Average \(avg) bpm over \(data.count) days")
                }())
            }
        }
    }

    // MARK: - HRV 趋势图

    private var hrvTrendChart: some View {
        let data = filteredSummaries.compactMap { s -> (date: Date, value: Double)? in
            guard let hrv = s.averageHRV else { return nil }
            return (s.date, hrv)
        }

        let latestHRV = data.last.map { "\(Int($0.value)) ms" }
        let curAvgHRV = data.isEmpty ? nil : data.map(\.value).reduce(0,+) / Double(data.count)
        let prevHRVs = previousPeriodSummaries.compactMap(\.averageHRV)
        let prevAvgHRV2 = prevHRVs.isEmpty ? nil : prevHRVs.reduce(0,+) / Double(prevHRVs.count)
        let hrvDelta = deltaPct(cur: curAvgHRV, prev: prevAvgHRV2)
        let hrvColor = Color(hex: "5C7BC7")  // 蓝色系

        return chartCard(
            icon: "waveform.path.ecg",
            title: "HRV",
            color: hrvColor,
            currentValue: latestHRV,
            changeText: hrvDelta?.0,
            changePositive: hrvDelta?.1 ?? true
        ) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(data, id: \.date) { item in
                    LineMark(
                        x: .value(String(localized: "Date"), item.date),
                        y: .value("HRV", item.value)
                    )
                    .foregroundStyle(hrvColor)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value(String(localized: "Date"), item.date),
                        y: .value("HRV", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [hrvColor.opacity(0.15), hrvColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(PulseTheme.border)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))ms")
                                    .foregroundStyle(PulseTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedRange.xAxisStride)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "HRV trend"))
                .accessibilityValue({
                    let avg = Int(data.map(\.value).reduce(0, +) / max(Double(data.count), 1))
                    return String(localized: "Average \(avg) milliseconds over \(data.count) days")
                }())
            }
        }
    }

    // MARK: - 睡眠趋势图

    private var sleepTrendChart: some View {
        let data = filteredSummaries.compactMap { s -> (date: Date, hours: Double, deep: Double, rem: Double)? in
            guard let total = s.sleepDurationMinutes, total > 0 else { return nil }
            let deepH = Double(s.deepSleepMinutes ?? 0) / 60.0
            let remH = Double(s.remSleepMinutes ?? 0) / 60.0
            return (s.date, Double(total) / 60.0, deepH, remH)
        }

        let latestSleep = data.last.map { String(format: "%.1fh", $0.hours) }
        let curAvgSleep2 = data.isEmpty ? nil : data.map(\.hours).reduce(0,+) / Double(data.count)
        let prevSleeps = previousPeriodSummaries.compactMap(\.sleepDurationMinutes).map { Double($0) / 60.0 }
        let prevAvgSleep2 = prevSleeps.isEmpty ? nil : prevSleeps.reduce(0,+) / Double(prevSleeps.count)
        let sleepDelta2 = deltaPct(cur: curAvgSleep2, prev: prevAvgSleep2)

        return chartCard(
            icon: "moon.fill",
            title: String(localized: "Sleep"),
            color: Color(hex: "4B3D8F"),
            currentValue: latestSleep,
            changeText: sleepDelta2?.0,
            changePositive: sleepDelta2?.1 ?? true
        ) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(data, id: \.date) { item in
                        BarMark(
                            x: .value(String(localized: "Date"), item.date, unit: .day),
                            y: .value(String(localized: "Total Duration"), item.hours)
                        )
                        .foregroundStyle(Color(hex: "8B7EC8").opacity(0.3))
                        .cornerRadius(4)

                        BarMark(
                            x: .value(String(localized: "Date"), item.date, unit: .day),
                            y: .value(String(localized: "Deep"), item.deep)
                        )
                        .foregroundStyle(Color(hex: "8B7EC8"))
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(PulseTheme.border)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0fh", v))
                                    .foregroundStyle(PulseTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedRange.xAxisStride)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Sleep trend"))
                .accessibilityValue({
                    let avg = data.map(\.hours).reduce(0, +) / max(Double(data.count), 1)
                    return String(localized: "Average \(String(format: "%.1f", avg)) hours over \(data.count) days")
                }())
            }
        }
    }

    // MARK: - 周报对比卡片

    private var weeklyReportCard: some View {
        let thisWeek = summariesForWeek(offset: 0)
        let lastWeek = summariesForWeek(offset: -1)

        let thisAvgScore = averageScore(thisWeek)
        let lastAvgScore = averageScore(lastWeek)
        let thisAvgSleep = averageSleep(thisWeek)
        let lastAvgSleep = averageSleep(lastWeek)
        let thisAvgHRV = averageHRV(thisWeek)
        let lastAvgHRV = averageHRV(lastWeek)
        let thisAvgSteps = averageSteps(thisWeek)
        let lastAvgSteps = averageSteps(lastWeek)

        return VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
                    .accessibilityHidden(true)
                Text("Weekly Comparison")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: 0) {
                // 表头
                HStack {
                    Text("Metrics")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("This Week")
                        .frame(width: 70, alignment: .trailing)
                    Text("Last Week")
                        .frame(width: 70, alignment: .trailing)
                    Text("Change")
                        .frame(width: 60, alignment: .trailing)
                }
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
                .padding(.bottom, PulseTheme.spacingS)

                reportDivider

                comparisonRow(label: String(localized: "Score"), thisWeek: thisAvgScore, lastWeek: lastAvgScore, suffix: "")
                reportDivider
                comparisonRow(label: String(localized: "Sleep"), thisWeek: thisAvgSleep, lastWeek: lastAvgSleep, suffix: "h")
                reportDivider
                comparisonRow(label: "HRV", thisWeek: thisAvgHRV, lastWeek: lastAvgHRV, suffix: "ms")
                reportDivider
                comparisonRow(label: String(localized: "Steps"), thisWeek: thisAvgSteps, lastWeek: lastAvgSteps, suffix: "")
            }
        }
        .pulseCard()
    }

    private var reportDivider: some View {
        Rectangle()
            .fill(PulseTheme.border.opacity(0.3))
            .frame(height: 0.5)
    }

    private func comparisonRow(label: String, thisWeek: Double?, lastWeek: Double?, suffix: String) -> some View {
        let delta: Double? = {
            guard let t = thisWeek, let l = lastWeek, l != 0 else { return nil }
            return ((t - l) / l) * 100
        }()

        return HStack {
            Text(label)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(thisWeek.map { formatComparisonValue($0, suffix: suffix) } ?? "--")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
                .frame(width: 70, alignment: .trailing)

            Text(lastWeek.map { formatComparisonValue($0, suffix: suffix) } ?? "--")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)
                .frame(width: 70, alignment: .trailing)

            Group {
                if let delta {
                    HStack(spacing: 2) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%.0f%%", abs(delta)))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(delta >= 0 ? PulseTheme.statusGood : PulseTheme.statusPoor)
                } else {
                    Text("--")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            let thisText = thisWeek.map { formatComparisonValue($0, suffix: suffix) } ?? String(localized: "No data")
            let lastText = lastWeek.map { formatComparisonValue($0, suffix: suffix) } ?? String(localized: "No data")
            return "\(label): \(String(localized: "This week")) \(thisText), \(String(localized: "Last week")) \(lastText)"
        }())
    }

    private func formatComparisonValue(_ value: Double, suffix: String) -> String {
        if suffix == "h" {
            return String(format: "%.1f%@", value, suffix)
        } else if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return "\(Int(value))\(suffix)"
        }
    }

    // MARK: - 完整周报入口

    private var weeklyReportButton: some View {
        Button {
            showWeeklyReport = true
        } label: {
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 15, weight: .medium))
                Text("View Full Report")
                    .font(PulseTheme.bodyFont.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .foregroundStyle(PulseTheme.accent)
            .padding(PulseTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                            .stroke(PulseTheme.accent.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 通用图表卡片容器

    private func chartCard<Content: View>(
        icon: String,
        title: String,
        color: Color,
        currentValue: String? = nil,
        changeText: String? = nil,
        changePositive: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack(spacing: PulseTheme.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 24, height: 24)

                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(color)
                }
                .accessibilityHidden(true)

                Text(title)
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if let val = currentValue {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(val)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                        if let change = changeText {
                            Text(change)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(changePositive ? Color(hex: "7FC75C") : Color(hex: "C75C5C"))
                        }
                    }
                }
            }

            content()
        }
        .pulseCard()
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: PulseTheme.spacingS) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(PulseTheme.textTertiary)
            Text("Insufficient data")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    // MARK: - 快捷入口

    private var shortcutButtons: some View {
        VStack(spacing: PulseTheme.spacingS) {
            HStack(spacing: PulseTheme.spacingS) {
                // 训练日历
                NavigationLink {
                    TrainingCalendarView()
                        .preferredColorScheme(.dark)
                } label: {
                    shortcutButton(icon: "calendar", title: String(localized: "Training Calendar"))
                }
                .buttonStyle(.plain)

                // 周报
                Button {
                    showWeeklyReport = true
                } label: {
                    shortcutButton(icon: "doc.richtext", title: String(localized: "Weekly Report"))
                }
                .buttonStyle(.plain)
            }

            // 训练历史
            NavigationLink {
                WorkoutHistoryListView()
                    .preferredColorScheme(.dark)
            } label: {
                shortcutButton(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", title: String(localized: "Workout History"))
            }
            .buttonStyle(.plain)
        }
    }

    private func shortcutButton(icon: String, title: String) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(PulseTheme.bodyFont.weight(.medium))
                .foregroundStyle(PulseTheme.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PulseTheme.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(PulseTheme.spacingM)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow.opacity(0.3), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.accent.opacity(0.15), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - 数据计算

    private func summariesForWeek(offset: Int) -> [DailySummary] {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7  // 周一为起始

        guard let thisMonday = cal.date(byAdding: .day, value: -daysSinceMonday, to: cal.startOfDay(for: now)),
              let startDate = cal.date(byAdding: .weekOfYear, value: offset, to: thisMonday),
              let endDate = cal.date(byAdding: .day, value: 7, to: startDate) else {
            return []
        }

        return allSummaries.filter { $0.date >= startDate && $0.date < endDate }
    }

    private func averageScore(_ summaries: [DailySummary]) -> Double? {
        let scores = summaries.compactMap(\.dailyScore)
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private func averageSleep(_ summaries: [DailySummary]) -> Double? {
        let values = summaries.compactMap(\.sleepDurationMinutes).filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count) / 60.0
    }

    private func averageHRV(_ summaries: [DailySummary]) -> Double? {
        let values = summaries.compactMap(\.averageHRV)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func averageSteps(_ summaries: [DailySummary]) -> Double? {
        let values = summaries.compactMap(\.totalSteps)
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}
