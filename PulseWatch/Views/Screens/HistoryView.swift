import SwiftUI
import SwiftData
import Charts

/// Tab 2: 历史趋势 — 折线图 + 周报对比
struct HistoryView: View {

    @State private var selectedRange: TimeRange = .week
    @State private var showWeeklyReport = false
    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]

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

                    // 评分趋势
                    scoreTrendChart
                        .staggered(index: 1)

                    // 心率趋势
                    heartRateTrendChart
                        .staggered(index: 2)

                    // HRV 趋势
                    hrvTrendChart
                        .staggered(index: 3)

                    // 睡眠趋势
                    sleepTrendChart
                        .staggered(index: 4)

                    // 周报对比
                    weeklyReportCard
                        .staggered(index: 5)

                    // 查看完整周报按钮
                    weeklyReportButton
                        .staggered(index: 6)

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingS)
            }
            .background(PulseTheme.background)
            .navigationTitle("历史趋势")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showWeeklyReport) {
                WeeklyReportView()
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - 时间范围

    enum TimeRange: String, CaseIterable {
        case week = "7天"
        case month = "30天"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            }
        }
    }

    private var rangePicker: some View {
        Picker("时间范围", selection: $selectedRange) {
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
        return allSummaries.filter { $0.date >= startOfDay }
    }

    // MARK: - 评分趋势图

    private var scoreTrendChart: some View {
        let data = filteredSummaries.compactMap { s -> (date: Date, score: Int)? in
            guard let score = s.dailyScore else { return nil }
            return (s.date, score)
        }

        return chartCard(
            icon: "chart.line.uptrend.xyaxis",
            title: "每日评分",
            color: PulseTheme.accent
        ) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(data, id: \.date) { item in
                    LineMark(
                        x: .value("日期", item.date),
                        y: .value("评分", item.score)
                    )
                    .foregroundStyle(PulseTheme.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("日期", item.date),
                        y: .value("评分", item.score)
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
                        x: .value("日期", item.date),
                        y: .value("评分", item.score)
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
                    AxisMarks(values: .stride(by: .day, count: selectedRange == .week ? 1 : 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(PulseTheme.border.opacity(0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - 心率趋势图

    private var heartRateTrendChart: some View {
        let data = filteredSummaries.compactMap { s -> (date: Date, avg: Double, resting: Double)? in
            guard let avg = s.averageHeartRate else { return nil }
            return (s.date, avg, s.restingHeartRate ?? avg)
        }

        return chartCard(
            icon: "heart.fill",
            title: "心率",
            color: PulseTheme.statusPoor
        ) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(data, id: \.date) { item in
                        LineMark(
                            x: .value("日期", item.date),
                            y: .value("平均心率", item.avg),
                            series: .value("类型", "平均")
                        )
                        .foregroundStyle(PulseTheme.statusPoor)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        LineMark(
                            x: .value("日期", item.date),
                            y: .value("静息心率", item.resting),
                            series: .value("类型", "静息")
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
                    AxisMarks(values: .stride(by: .day, count: selectedRange == .week ? 1 : 5)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .chartForegroundStyleScale([
                    "平均": PulseTheme.statusPoor,
                    "静息": PulseTheme.statusPoor.opacity(0.5),
                ])
                .chartLegend(.visible)
                .frame(height: 180)
            }
        }
    }

    // MARK: - HRV 趋势图

    private var hrvTrendChart: some View {
        let data = filteredSummaries.compactMap { s -> (date: Date, value: Double)? in
            guard let hrv = s.averageHRV else { return nil }
            return (s.date, hrv)
        }

        return chartCard(
            icon: "waveform.path.ecg",
            title: "HRV",
            color: PulseTheme.accent
        ) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(data, id: \.date) { item in
                    LineMark(
                        x: .value("日期", item.date),
                        y: .value("HRV", item.value)
                    )
                    .foregroundStyle(PulseTheme.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("日期", item.date),
                        y: .value("HRV", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.accent.opacity(0.15), PulseTheme.accent.opacity(0.02)],
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
                    AxisMarks(values: .stride(by: .day, count: selectedRange == .week ? 1 : 5)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .frame(height: 180)
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

        return chartCard(
            icon: "moon.fill",
            title: "睡眠",
            color: Color(hex: "8B7EC8")
        ) {
            if data.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(data, id: \.date) { item in
                        BarMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("总时长", item.hours)
                        )
                        .foregroundStyle(Color(hex: "8B7EC8").opacity(0.3))
                        .cornerRadius(4)

                        BarMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("深睡", item.deep)
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
                    AxisMarks(values: .stride(by: .day, count: selectedRange == .week ? 1 : 5)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .frame(height: 180)
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
                Text("周报对比")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
            }

            VStack(spacing: 0) {
                // 表头
                HStack {
                    Text("指标")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("本周")
                        .frame(width: 70, alignment: .trailing)
                    Text("上周")
                        .frame(width: 70, alignment: .trailing)
                    Text("变化")
                        .frame(width: 60, alignment: .trailing)
                }
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
                .padding(.bottom, PulseTheme.spacingS)

                reportDivider

                comparisonRow(label: "评分", thisWeek: thisAvgScore, lastWeek: lastAvgScore, suffix: "")
                reportDivider
                comparisonRow(label: "睡眠", thisWeek: thisAvgSleep, lastWeek: lastAvgSleep, suffix: "h")
                reportDivider
                comparisonRow(label: "HRV", thisWeek: thisAvgHRV, lastWeek: lastAvgHRV, suffix: "ms")
                reportDivider
                comparisonRow(label: "步数", thisWeek: thisAvgSteps, lastWeek: lastAvgSteps, suffix: "")
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
                Text("查看完整周报")
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

                Text(title)
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
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
            Text("暂无足够数据")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    // MARK: - 快捷入口

    private var shortcutButtons: some View {
        HStack(spacing: PulseTheme.spacingS) {
            // 训练日历
            NavigationLink {
                TrainingCalendarView()
                    .preferredColorScheme(.dark)
            } label: {
                shortcutButton(icon: "calendar", title: "训练日历")
            }
            .buttonStyle(.plain)

            // 周报
            Button {
                showWeeklyReport = true
            } label: {
                shortcutButton(icon: "doc.richtext", title: "周报")
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
            }

            Text(title)
                .font(PulseTheme.bodyFont.weight(.medium))
                .foregroundStyle(PulseTheme.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PulseTheme.textTertiary)
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
