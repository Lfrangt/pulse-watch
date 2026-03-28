import SwiftUI
import Charts

/// Premium sleep analysis screen — hypnogram, stage breakdown, insights
struct SleepDetailView: View {

    @State private var healthManager = HealthKitManager.shared
    @State private var samples: [HealthKitManager.SleepSample] = []
    @State private var isLoading = true
    @State private var chartAppeared = false

    // Aggregated durations (minutes)
    private var totalMinutes: Int { healthManager.lastNightSleepMinutes }
    private var deepMinutes: Int { healthManager.lastNightDeepSleepMinutes }
    private var remMinutes: Int { healthManager.lastNightREMSleepMinutes }
    private var coreMinutes: Int { max(0, totalMinutes - deepMinutes - remMinutes) }
    private var awakeMinutes: Int {
        guard let s = sleepStart, let e = sleepEnd else { return 0 }
        let windowMinutes = Int(e.timeIntervalSince(s) / 60)
        return max(0, windowMinutes - totalMinutes)
    }
    private var sleepStart: Date? { healthManager.lastNightSleepStart }
    private var sleepEnd: Date? { healthManager.lastNightSleepEnd }

    // Colors
    private let deepColor = Color(hex: "1E3A5F")
    private let remColor = PulseTheme.sleepAccent // BF94FF
    private let coreColor = Color(hex: "4A6FA5")
    private let awakeColor = Color.white.opacity(0.2)

    // Sleep score (simple heuristic)
    private var sleepScore: Int {
        guard totalMinutes > 0 else { return 0 }
        var score = 50
        // Duration component (7-9h ideal)
        if totalMinutes >= 420 && totalMinutes <= 540 { score += 20 }
        else if totalMinutes >= 360 { score += 10 }
        else { score -= 10 }
        // Deep sleep component (13-23% ideal)
        let deepPct = Double(deepMinutes) / Double(totalMinutes) * 100
        if deepPct >= 13 && deepPct <= 23 { score += 15 }
        else if deepPct >= 10 { score += 8 }
        // REM component (20-25% ideal)
        let remPct = Double(remMinutes) / Double(totalMinutes) * 100
        if remPct >= 20 && remPct <= 25 { score += 15 }
        else if remPct >= 15 { score += 8 }
        return min(100, max(0, score))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {
                hypnogramChart
                    .staggered(index: 0)

                summaryStatsRow
                    .staggered(index: 1)

                sleepScoreCard
                    .staggered(index: 2)

                stageBreakdownCard
                    .staggered(index: 3)

                insightsCard
                    .staggered(index: 4)

                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingS)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "Sleep"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Refresh sleep data from HealthKit first
        _ = try? await healthManager.fetchLastNightSleep()

        do {
            let fetched = try await healthManager.fetchSleepSamples()
            samples = fetched
        } catch {
            samples = []
        }
        isLoading = false
        withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
            chartAppeared = true
        }
    }

    // MARK: - 1. Hypnogram Chart

    private var hypnogramChart: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text(String(localized: "Sleep Stages"))
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            Chart(samples) { sample in
                RectangleMark(
                    xStart: .value("Start", sample.start),
                    xEnd: .value("End", sample.end),
                    yStart: .value("StageBottom", stageY(sample.stage)),
                    yEnd: .value("StageTop", stageY(sample.stage) + 1)
                )
                .foregroundStyle(stageColor(sample.stage))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .opacity(chartAppeared ? 1 : 0)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 1)) { value in
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                        .foregroundStyle(PulseTheme.textTertiary)
                    AxisGridLine()
                        .foregroundStyle(PulseTheme.border.opacity(0.3))
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 1, 2, 3]) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(stageLabel(v))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(PulseTheme.border.opacity(0.2))
                }
            }
            .chartYScale(domain: -0.2...4.2)
            .chartPlotStyle { plot in
                plot.frame(height: 180)
            }

            // Bedtime / Wake labels
            if let s = sleepStart, let e = sleepEnd {
                HStack {
                    Label(s.formatted(.dateTime.hour().minute()), systemImage: "bed.double.fill")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                    Spacer()
                    Label(e.formatted(.dateTime.hour().minute()), systemImage: "alarm.fill")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .pulseCard()
    }

    private func stageY(_ stage: HealthKitManager.SleepStage) -> Int {
        switch stage {
        case .deep: return 0
        case .core: return 1
        case .rem: return 2
        case .awake: return 3
        }
    }

    private func stageLabel(_ y: Int) -> String {
        switch y {
        case 0: return String(localized: "Deep")
        case 1: return String(localized: "Core")
        case 2: return "REM"
        case 3: return String(localized: "Awake")
        default: return ""
        }
    }

    private func stageColor(_ stage: HealthKitManager.SleepStage) -> Color {
        switch stage {
        case .deep: return deepColor
        case .rem: return remColor
        case .core: return coreColor
        case .awake: return awakeColor
        }
    }

    // MARK: - 2. Summary Stats Row

    private var summaryStatsRow: some View {
        HStack(spacing: PulseTheme.spacingS) {
            statPill(icon: "moon.fill", value: formatDuration(totalMinutes), label: String(localized: "总睡眠"), color: PulseTheme.textSecondary)
            statPill(icon: "powersleep", value: formatDuration(deepMinutes), label: String(localized: "深睡"), color: deepColor)
            statPill(icon: "brain.head.profile", value: formatDuration(remMinutes), label: "REM", color: remColor)
            statPill(icon: "sleep", value: formatDuration(coreMinutes), label: String(localized: "浅睡"), color: coreColor)
        }
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "111111"))
        )
    }

    // MARK: - 3. Sleep Score Card

    private var sleepScoreCard: some View {
        VStack(spacing: PulseTheme.spacingM) {
            ZStack {
                // Background ring track
                Circle()
                    .stroke(PulseTheme.border.opacity(0.3), lineWidth: 6)
                    .frame(width: 80, height: 80)

                // Score arc
                Circle()
                    .trim(from: 0, to: chartAppeared ? CGFloat(sleepScore) / 100 : 0)
                    .stroke(
                        PulseTheme.accentTeal,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3), value: chartAppeared)

                VStack(spacing: 2) {
                    Text("\(sleepScore)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                }
            }

            Text(String(localized: "睡眠评分"))
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)

            Text(sleepInsight)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .pulseCard()
    }

    private var sleepInsight: String {
        let deepPct = totalMinutes > 0 ? Int(Double(deepMinutes) / Double(totalMinutes) * 100) : 0
        if deepPct >= 20 {
            return String(localized: "深睡比例优秀，恢复充分")
        } else if deepPct >= 13 {
            return String(localized: "深睡占比 \(deepPct)%，处于健康范围")
        } else {
            return String(localized: "深睡偏少，建议改善睡前习惯")
        }
    }

    // MARK: - 4. Stage Breakdown

    private var stageBreakdownCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "Stage Breakdown"))
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            stageRow(name: String(localized: "Deep"), minutes: deepMinutes, color: deepColor)
            stageRow(name: "REM", minutes: remMinutes, color: remColor)
            stageRow(name: String(localized: "Core"), minutes: coreMinutes, color: coreColor)
            stageRow(name: String(localized: "Awake"), minutes: awakeMinutes, color: awakeColor)
        }
        .pulseCard()
    }

    private func stageRow(name: String, minutes: Int, color: Color) -> some View {
        let windowMinutes = max(1, totalMinutes + awakeMinutes)
        let fraction = CGFloat(minutes) / CGFloat(windowMinutes)

        return HStack(spacing: PulseTheme.spacingS) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PulseTheme.textPrimary)
                .frame(width: 50, alignment: .leading)

            Text(formatDuration(minutes))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)
                .frame(width: 56, alignment: .trailing)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
                    .frame(width: chartAppeared ? geo.size.width * fraction : 0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: chartAppeared)
            }
            .frame(height: 8)
        }
    }

    // MARK: - 5. Insights

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "Insights"))
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            insightRow(icon: "moon.stars.fill", text: sleepLatencyInsight)
            insightRow(icon: "bolt.fill", text: deepSleepInsight)
            insightRow(icon: "chart.line.uptrend.xyaxis", text: weeklyTrendInsight)
        }
        .pulseCard()
    }

    private func insightRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: PulseTheme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(PulseTheme.sleepAccent)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)
        }
    }

    private var sleepLatencyInsight: String {
        guard let start = sleepStart, let firstSleep = samples.first(where: { $0.stage != .awake }) else {
            return String(localized: "入睡用时数据不足")
        }
        let latencyMin = Int(firstSleep.start.timeIntervalSince(start) / 60)
        if latencyMin <= 15 {
            return String(localized: "入睡用时约 \(latencyMin) 分钟，快于平均水平")
        } else if latencyMin <= 30 {
            return String(localized: "入睡用时约 \(latencyMin) 分钟，属于正常范围")
        } else {
            return String(localized: "入睡用时约 \(latencyMin) 分钟，建议改善睡前习惯")
        }
    }

    private var deepSleepInsight: String {
        let pct = totalMinutes > 0 ? Int(Double(deepMinutes) / Double(totalMinutes) * 100) : 0
        if pct >= 20 {
            return String(localized: "深睡占比 \(pct)%，表现优秀")
        } else if pct >= 13 {
            return String(localized: "深睡占比 \(pct)%，处于健康范围")
        } else if pct > 0 {
            return String(localized: "深睡占比 \(pct)%，偏低")
        } else {
            return String(localized: "深睡数据不足")
        }
    }

    private var weeklyTrendInsight: String {
        guard totalMinutes > 0 else {
            return String(localized: "暂无本周睡眠趋势数据")
        }
        let hours = String(format: "%.1f", Double(totalMinutes) / 60)
        return String(localized: "昨晚睡眠 \(hours)h")
    }

    // MARK: - Helpers

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    // MARK: - Demo Data

    private static var demoSamples: [HealthKitManager.SleepSample] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let base = cal.date(bySettingHour: 23, minute: 0, second: 0, of: cal.date(byAdding: .day, value: -1, to: today)!)!

        func sample(_ stage: HealthKitManager.SleepStage, startMin: Int, durationMin: Int) -> HealthKitManager.SleepSample {
            let s = base.addingTimeInterval(TimeInterval(startMin * 60))
            let e = s.addingTimeInterval(TimeInterval(durationMin * 60))
            return HealthKitManager.SleepSample(stage: stage, start: s, end: e)
        }

        return [
            sample(.awake, startMin: 0, durationMin: 12),
            sample(.core, startMin: 12, durationMin: 35),
            sample(.deep, startMin: 47, durationMin: 45),
            sample(.core, startMin: 92, durationMin: 25),
            sample(.rem, startMin: 117, durationMin: 30),
            sample(.core, startMin: 147, durationMin: 40),
            sample(.deep, startMin: 187, durationMin: 30),
            sample(.core, startMin: 217, durationMin: 35),
            sample(.rem, startMin: 252, durationMin: 35),
            sample(.awake, startMin: 287, durationMin: 8),
            sample(.core, startMin: 295, durationMin: 30),
            sample(.rem, startMin: 325, durationMin: 25),
            sample(.deep, startMin: 350, durationMin: 20),
            sample(.core, startMin: 370, durationMin: 40),
            sample(.rem, startMin: 410, durationMin: 20),
            sample(.core, startMin: 430, durationMin: 20),
            sample(.awake, startMin: 450, durationMin: 10),
        ]
    }
}

#Preview {
    NavigationStack {
        SleepDetailView()
    }
    .preferredColorScheme(.dark)
}
