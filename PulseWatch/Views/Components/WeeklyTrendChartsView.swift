import SwiftUI
import SwiftData
import Charts

/// 7天健康趋势图组件 — 心率、HRV、睡眠三合一紧凑卡片
/// 用于 Dashboard 展示近7天数据变化趋势
struct WeeklyTrendChartsView: View {

    let summaries: [DailySummary]
    let demoMode: Bool

    /// 过滤出最近7天的数据
    private var recentSummaries: [DailySummary] {
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        return summaries
            .filter { $0.date >= startOfDay }
            .sorted { $0.date < $1.date }
    }

    /// 演示模式的模拟数据
    private var displayData: [TrendDataPoint] {
        if demoMode {
            return Self.demoTrendData()
        }
        return recentSummaries.map { s in
            TrendDataPoint(
                date: s.date,
                heartRate: s.averageHeartRate,
                restingHR: s.restingHeartRate,
                hrv: s.averageHRV,
                sleepHours: s.sleepDurationMinutes.map { Double($0) / 60.0 },
                deepSleepHours: s.deepSleepMinutes.map { Double($0) / 60.0 }
            )
        }
    }

    private var hasData: Bool {
        !displayData.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // 标题
            HStack(spacing: PulseTheme.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PulseTheme.accent.opacity(0.12))
                        .frame(width: 24, height: 24)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.accent)
                }

                Text(String(localized: "7日趋势"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                // 日期范围副标题
                if hasData, let first = displayData.first, let last = displayData.last {
                    Text(dateRangeLabel(from: first.date, to: last.date))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            if hasData {
                // 心率趋势
                heartRateChart

                // HRV 趋势
                hrvChart

                // 睡眠趋势
                sleepChart
            } else {
                // 无数据占位符
                noDataPlaceholder
            }
        }
        .pulseCard()
    }
    
    // MARK: - No Data Placeholder
    
    private var noDataPlaceholder: some View {
        VStack(spacing: PulseTheme.spacingM) {
            // 占位符图表轮廓
            placeholderChartSilhouette
            
            VStack(spacing: PulseTheme.spacingS) {
                Text(String(localized: "Start wearing Apple Watch to collect data"))
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                
                Text(String(localized: "Trends will appear here once you have a few days of health data"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, PulseTheme.spacingL)
        .accessibilityElement(children: .combine)
    }
    
    private var placeholderChartSilhouette: some View { /* decorative only */
        VStack(spacing: PulseTheme.spacingS) {
            // 模拟的图表轮廓
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let heights: [CGFloat] = [20, 35, 25, 40, 30, 45, 35]
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(PulseTheme.border.opacity(0.3))
                        .frame(width: 8, height: heights[i])
                }
            }
            
            // 模拟的折线图
            ZStack {
                // 背景网格
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundStyle(PulseTheme.border.opacity(0.2))
                        Spacer()
                    }
                }
                .frame(height: 40)
                
                // 占位符线条
                Path { path in
                    let points: [CGPoint] = [
                        CGPoint(x: 0, y: 30),
                        CGPoint(x: 40, y: 20),
                        CGPoint(x: 80, y: 35),
                        CGPoint(x: 120, y: 15),
                        CGPoint(x: 160, y: 25)
                    ]
                    
                    if let first = points.first {
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(PulseTheme.border.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 160, height: 40)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 静息心率折线图

    private var heartRateChart: some View {
        // 只用静息心率，排除运动期间的高心率干扰
        let hrData = displayData.compactMap { d -> (Date, Double)? in
            guard let rhr = d.restingHR else { return nil }
            return (d.date, rhr)
        }

        return VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
            chartHeader(
                icon: "heart.fill",
                title: String(localized: "静息心率"),
                color: PulseTheme.activityAccent,
                summary: hrData.isEmpty ? nil : restingHRSummary(hrData)
            )

            if hrData.isEmpty {
                miniEmptyPlaceholder
            } else {
                Chart {
                    ForEach(hrData, id: \.0) { item in
                        LineMark(
                            x: .value("Date", item.0),
                            y: .value("Resting HR", item.1)
                        )
                        .foregroundStyle(PulseTheme.activityAccent)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .symbol {
                            Circle()
                                .fill(PulseTheme.activityAccent)
                                .frame(width: 4, height: 4)
                        }

                        AreaMark(
                            x: .value("Date", item.0),
                            y: .value("Resting HR", item.1)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [PulseTheme.activityAccent.opacity(0.15), PulseTheme.activityAccent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(PulseTheme.border)
                        AxisValueLabel()
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 9))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .frame(height: 120)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Resting Heart Rate trend chart"))
                .accessibilityValue(hrData.isEmpty ? String(localized: "No data") : restingHRSummary(hrData))
            }
        }
    }

    // MARK: - HRV 折线图

    private var hrvChart: some View {
        let hrvData = displayData.compactMap { d -> (Date, Double)? in
            guard let hrv = d.hrv else { return nil }
            return (d.date, hrv)
        }

        return VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
            chartHeader(
                icon: "waveform.path.ecg",
                title: "HRV",
                color: PulseTheme.accent,
                summary: hrvData.isEmpty ? nil : hrvSummary(hrvData)
            )

            if hrvData.isEmpty {
                miniEmptyPlaceholder
            } else {
                Chart(hrvData, id: \.0) { item in
                    LineMark(
                        x: .value("Date", item.0),
                        y: .value("HRV", item.1)
                    )
                    .foregroundStyle(PulseTheme.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol {
                        Circle()
                            .fill(PulseTheme.accent)
                            .frame(width: 4, height: 4)
                    }

                    AreaMark(
                        x: .value("Date", item.0),
                        y: .value("HRV", item.1)
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
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(PulseTheme.border)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(PulseTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 9))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .frame(height: 120)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "HRV trend chart"))
                .accessibilityValue(hrvData.isEmpty ? String(localized: "No data") : hrvSummary(hrvData))
            }
        }
    }

    // MARK: - 睡眠柱状图

    private var sleepChart: some View {
        let sleepData = displayData.compactMap { d -> (Date, Double, Double)? in
            guard let total = d.sleepHours, total > 0 else { return nil }
            return (d.date, total, d.deepSleepHours ?? 0)
        }

        return VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
            chartHeader(
                icon: "moon.fill",
                title: String(localized: "Sleep"),
                color: PulseTheme.sleepAccent,
                summary: sleepData.isEmpty ? nil : sleepSummary(sleepData)
            )

            if sleepData.isEmpty {
                miniEmptyPlaceholder
            } else {
                Chart {
                    ForEach(sleepData, id: \.0) { item in
                        // 总睡眠 — 浅色柱
                        BarMark(
                            x: .value("Date", item.0, unit: .day),
                            y: .value("Total", item.1)
                        )
                        .foregroundStyle(PulseTheme.sleepAccent.opacity(0.3))
                        .cornerRadius(4)

                        // 深睡 — 深色柱叠加
                        BarMark(
                            x: .value("Date", item.0, unit: .day),
                            y: .value("Deep", item.2)
                        )
                        .foregroundStyle(PulseTheme.sleepAccent)
                        .cornerRadius(4)
                    }

                    // 7h 参考线
                    RuleMark(y: .value("Target", 7))
                        .foregroundStyle(PulseTheme.textTertiary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("7h")
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                            .foregroundStyle(PulseTheme.border)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0fh", v))
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(PulseTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 9))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .frame(height: 120)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Sleep trend chart"))
                .accessibilityValue(sleepData.isEmpty ? String(localized: "No data") : sleepSummary(sleepData))
            }
        }
    }

    // MARK: - 辅助组件

    private func chartHeader(icon: String, title: String, color: Color, summary: String?) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if let summary {
                Text(summary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var miniEmptyPlaceholder: some View {
        HStack {
            Spacer()
            Text(String(localized: "Insufficient data"))
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
            Spacer()
        }
        .frame(height: 60)
        .accessibilityLabel(String(localized: "Insufficient data to display chart"))
    }

    // MARK: - Summary 计算

    private func restingHRSummary(_ data: [(Date, Double)]) -> String {
        let avg = data.map(\.1).reduce(0, +) / Double(data.count)
        return String(localized: "Avg \(Int(avg)) bpm")
    }

    private func hrvSummary(_ data: [(Date, Double)]) -> String {
        let avg = data.map(\.1).reduce(0, +) / Double(data.count)
        // 趋势方向
        if data.count >= 3 {
            let recent = data.suffix(3).map(\.1).reduce(0, +) / 3.0
            let earlier = data.prefix(3).map(\.1).reduce(0, +) / 3.0
            let arrow = recent > earlier * 1.05 ? " ↑" : (recent < earlier * 0.95 ? " ↓" : "")
            return String(localized: "Avg \(Int(avg))ms\(arrow)")
        }
        return String(localized: "Avg \(Int(avg))ms")
    }

    private func sleepSummary(_ data: [(Date, Double, Double)]) -> String {
        let avg = data.map(\.1).reduce(0, +) / Double(data.count)
        return String(localized: "Avg \(String(format: "%.1f", avg))h")
    }

    private func dateRangeLabel(from start: Date, to end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    // MARK: - 演示数据

    static func demoTrendData() -> [TrendDataPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        let heartRates:  [Double] = [74, 71, 68, 73, 70, 69, 72]
        let restingHRs:  [Double] = [60, 59, 57, 61, 58, 57, 58]
        let hrvs:        [Double] = [42, 44, 48, 45, 50, 52, 48]
        let sleepHours:  [Double] = [6.8, 7.2, 7.5, 6.5, 7.8, 7.0, 7.2]
        let deepHours:   [Double] = [1.5, 1.8, 2.0, 1.3, 2.1, 1.6, 1.8]

        return (0..<7).map { i in
            let date = cal.date(byAdding: .day, value: -(6 - i), to: today)!
            return TrendDataPoint(
                date: date,
                heartRate: heartRates[i],
                restingHR: restingHRs[i],
                hrv: hrvs[i],
                sleepHours: sleepHours[i],
                deepSleepHours: deepHours[i]
            )
        }
    }
}

// MARK: - 数据模型

struct TrendDataPoint {
    let date: Date
    let heartRate: Double?
    let restingHR: Double?
    let hrv: Double?
    let sleepHours: Double?
    let deepSleepHours: Double?
}

#Preview {
    ScrollView {
        WeeklyTrendChartsView(
            summaries: [],
            demoMode: true
        )
        .padding()
    }
    .background(PulseTheme.background)
    .preferredColorScheme(.dark)
}
