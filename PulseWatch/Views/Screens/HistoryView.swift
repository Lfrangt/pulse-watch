import SwiftUI
import SwiftData
import Charts

/// Tab 2: 历史趋势 — 折线图 + 周报对比
struct HistoryView: View {

    @State private var selectedRange: TimeRange = .week
    @State private var showWeeklyReport = false
    @State private var chartAnimated = false
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
                // Chart animation trigger
                withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                    chartAnimated = true
                }
                // In-App Review: 查看趋势图时检查是否有 7 天完整数据
                let calendar = Calendar.current
                let sevenDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: .now)!)
                let recentWithScores = allSummaries.filter { $0.date >= sevenDaysAgo && $0.dailyScore != nil }
                let hasSevenDayData = recentWithScores.count >= 7
                ReviewRequestManager.shared.recordTrendsViewed(hasSevenDayData: hasSevenDayData)
            }
            .onChange(of: selectedRange) {
                chartAnimated = false
                withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                    chartAnimated = true
                }
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
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(PulseTheme.accentTeal)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
            if let (text, positive) = delta {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(positive ? PulseTheme.accentTeal : PulseTheme.activityCoral)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill((positive ? PulseTheme.accentTeal : PulseTheme.activityCoral).opacity(0.12)))
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

        let scoreInsight: String? = {
            guard let cur = curAvg, let prev = prevAvgVal else { return nil }
            let diff = cur - prev
            if abs(diff) < 2 { return String(localized: "Your score has been steady this period") }
            return diff > 0
                ? String(format: String(localized: "Your score is up %d points vs last period"), abs(diff))
                : String(format: String(localized: "Your score is down %d points vs last period"), abs(diff))
        }()

        return chartCard(
            icon: "chart.line.uptrend.xyaxis",
            title: String(localized: "Daily Score"),
            color: PulseTheme.accent,
            currentValue: latestScore.map { "\($0)" },
            changeText: scoreDelta?.0,
            changePositive: scoreDelta?.1 ?? true,
            insight: scoreInsight
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
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(PulseTheme.border.opacity(0.4))
                        AxisValueLabel()
                            .font(.system(size: 10))
                            .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedRange.xAxisStride)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(PulseTheme.border.opacity(0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 9))
                            .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
                    }
                }
                .frame(height: 180)
                .opacity(chartAnimated ? 1 : 0)
                .animation(.easeOut(duration: 1.0), value: chartAnimated)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Daily score trend"))
                .accessibilityValue({
                    let avg = data.map(\.score).reduce(0, +) / max(data.count, 1)
                    return String(localized: "Average score \(avg) over \(data.count) days")
                }())
            }
        }
    }

    // MARK: - 心率趋势图 (静息心率折线)

    private var heartRateTrendChart: some View {
        let data = filteredSummaries.compactMap { s -> (date: Date, resting: Double)? in
            guard let rhr = s.restingHeartRate else { return nil }
            return (s.date, rhr)
        }

        let latestRHR = data.last.map { "\(Int($0.resting)) bpm" }
        let curAvgHR = data.isEmpty ? nil : data.map(\.resting).reduce(0,+) / Double(data.count)
        let prevHR = previousPeriodSummaries.compactMap(\.restingHeartRate)
        let prevAvgHR = prevHR.isEmpty ? nil : prevHR.reduce(0,+) / Double(prevHR.count)
        let hrDelta = deltaPct(cur: curAvgHR, prev: prevAvgHR)
        let hrPositive = hrDelta.map { $0.0.contains("-") } ?? true

        let hrInsight: String? = {
            guard let cur = curAvgHR else { return nil }
            if let prev = prevAvgHR {
                let diff = cur - prev
                if abs(diff) < 1 { return String(localized: "Resting heart rate has been stable") }
                return diff < 0
                    ? String(format: String(localized: "Resting HR dropped %.0f bpm — good sign"), abs(diff))
                    : String(format: String(localized: "Resting HR up %.0f bpm — watch recovery"), diff)
            }
            return String(format: String(localized: "Average resting HR: %.0f bpm"), cur)
        }()

        let hrColor = PulseTheme.activityAccent

        return chartCard(
            icon: "heart.fill",
            title: String(localized: "Resting Heart Rate"),
            color: hrColor,
            currentValue: latestRHR,
            changeText: hrDelta?.0,
            changePositive: hrPositive,
            insight: hrInsight
        ) {
            if data.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 24))
                        .foregroundStyle(PulseTheme.textTertiary.opacity(0.5))
                    Text("No heart rate data — wear your Apple Watch")
                        .font(.system(size: 12))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else {
                Chart(data, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("RHR", item.resting)
                    )
                    .foregroundStyle(hrColor)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("RHR", item.resting)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [hrColor.opacity(0.15), hrColor.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("RHR", item.resting)
                    )
                    .foregroundStyle(hrColor)
                    .symbolSize(20)
                }
                .chartYScale(domain: {
                    let lo = max(30, (data.map(\.resting).min() ?? 40) - 5)
                    let hi = (data.map(\.resting).max() ?? 80) + 5
                    return lo...hi
                }())
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(PulseTheme.border.opacity(0.4))
                        AxisValueLabel()
                            .font(.system(size: 10))
                            .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedRange.xAxisStride)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 9))
                            .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
                    }
                }
                .frame(height: 180)
                .opacity(chartAnimated ? 1 : 0)
                .animation(.easeOut(duration: 1.0), value: chartAnimated)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Resting heart rate trend"))
                .accessibilityValue({
                    let avg = Int(data.map(\.resting).reduce(0, +) / max(Double(data.count), 1))
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

        let hrvInsight: String? = {
            guard let cur = curAvgHRV else { return nil }
            if let prev = prevAvgHRV2 {
                let pct = ((cur - prev) / prev) * 100
                if abs(pct) < 3 { return String(localized: "HRV has been stable this period") }
                return pct > 0
                    ? String(format: String(localized: "HRV is up %.0f%% — your body is adapting well"), pct)
                    : String(format: String(localized: "HRV dropped %.0f%% — prioritize recovery"), abs(pct))
            }
            return String(format: String(localized: "Average HRV: %.0f ms"), cur)
        }()

        return chartCard(
            icon: "waveform.path.ecg",
            title: "HRV",
            color: hrvColor,
            currentValue: latestHRV,
            changeText: hrvDelta?.0,
            changePositive: hrvDelta?.1 ?? true,
            insight: hrvInsight
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
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(PulseTheme.border.opacity(0.4))
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
                            .font(.system(size: 9))
                            .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
                    }
                }
                .frame(height: 180)
                .opacity(chartAnimated ? 1 : 0)
                .animation(.easeOut(duration: 1.0), value: chartAnimated)
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

        let sleepInsight: String? = {
            guard let latest = data.last else { return nil }
            if let avg = curAvgSleep2 {
                let diff = latest.hours - avg
                if abs(diff) < 0.3 { return String(localized: "Last night was about average for you") }
                return diff > 0
                    ? String(format: String(localized: "Last night you slept %.1fh — above your average"), latest.hours)
                    : String(format: String(localized: "Last night was %.1fh — below your average"), latest.hours)
            }
            return nil
        }()

        return chartCard(
            icon: "moon.fill",
            title: String(localized: "Sleep"),
            color: Color(hex: "4B3D8F"),
            currentValue: latestSleep,
            changeText: sleepDelta2?.0,
            changePositive: sleepDelta2?.1 ?? true,
            insight: sleepInsight
        ) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                let avgHours = data.map(\.hours).reduce(0, +) / Double(data.count)

                Chart {
                    ForEach(data, id: \.date) { item in
                        BarMark(
                            x: .value(String(localized: "Date"), item.date, unit: .day),
                            y: .value(String(localized: "Total Duration"), item.hours),
                            width: .ratio(0.4)
                        )
                        .foregroundStyle(PulseTheme.sleepAccent.opacity(0.3))
                        .cornerRadius(4)

                        BarMark(
                            x: .value(String(localized: "Date"), item.date, unit: .day),
                            y: .value(String(localized: "Deep"), item.deep),
                            width: .ratio(0.4)
                        )
                        .foregroundStyle(PulseTheme.sleepAccent)
                        .cornerRadius(4)
                    }

                    // Average baseline
                    RuleMark(y: .value("Avg", avgHours))
                        .foregroundStyle(PulseTheme.accent.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text(String(format: "avg %.1fh", avgHours))
                                .font(.system(size: 9))
                                .foregroundStyle(PulseTheme.accent.opacity(0.8))
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(PulseTheme.border.opacity(0.4))
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
                            .font(.system(size: 9))
                            .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
                    }
                }
                .frame(height: 180)
                .opacity(chartAnimated ? 1 : 0)
                .animation(.easeOut(duration: 1.0), value: chartAnimated)
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
        insight: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title row
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                }
                .accessibilityHidden(true)

                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(PulseTheme.textTertiary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if let change = changeText {
                    Text(change)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(changePositive ? PulseTheme.accentTeal : PulseTheme.activityCoral)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill((changePositive ? PulseTheme.accentTeal : PulseTheme.activityCoral).opacity(0.12)))
                }
            }

            // Big value
            if let val = currentValue {
                Text(val)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .contentTransition(.numericText())
            }

            // Natural language insight
            if let insight {
                Text(insight)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(2)
            }

            content()
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                )
        )
    }

    private var emptyChartPlaceholder: some View {
        ZStack {
            // Dashed outline chart skeleton
            Path { path in
                let w: CGFloat = 300
                let h: CGFloat = 120
                let points: [(CGFloat, CGFloat)] = [
                    (0, 0.6), (0.15, 0.4), (0.3, 0.55), (0.45, 0.35),
                    (0.6, 0.5), (0.75, 0.3), (0.9, 0.45), (1.0, 0.25)
                ]
                for (i, p) in points.enumerated() {
                    let pt = CGPoint(x: p.0 * w, y: p.1 * h)
                    if i == 0 { path.move(to: pt) }
                    else { path.addLine(to: pt) }
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            .foregroundStyle(PulseTheme.border.opacity(0.4))
            .frame(height: 120)

            VStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24))
                    .foregroundStyle(PulseTheme.textTertiary.opacity(0.5))
                Text("Keep wearing your Watch to see trends")
                    .font(.system(size: 12))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    // MARK: - 快捷入口

    private var shortcutButtons: some View {
        HStack(spacing: PulseTheme.spacingS) {
            NavigationLink {
                TrainingCalendarView().preferredColorScheme(.dark)
            } label: {
                shortcutTile(icon: "calendar", color: PulseTheme.accentTeal, title: String(localized: "Training Calendar"))
            }
            .buttonStyle(.plain)

            Button { showWeeklyReport = true } label: {
                shortcutTile(icon: "doc.richtext", color: PulseTheme.sleepViolet, title: String(localized: "Weekly Report"))
            }
            .buttonStyle(.plain)

            NavigationLink {
                WorkoutHistoryListView().preferredColorScheme(.dark)
            } label: {
                shortcutTile(icon: "clock.fill", color: PulseTheme.activityCoral, title: String(localized: "Workout History"))
            }
            .buttonStyle(.plain)
        }
    }

    private func shortcutTile(icon: String, color: Color, title: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                )
        )
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
