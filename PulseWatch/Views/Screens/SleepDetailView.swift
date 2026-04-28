import SwiftUI
import Charts

/// Premium sleep analysis screen — hypnogram, stage breakdown, insights
struct SleepDetailView: View {

    private let healthManager = HealthKitManager.shared
    @State private var samples: [HealthKitManager.SleepSample] = []
    @State private var isLoading = true
    @State private var chartAppeared = false
    @State private var selectedSleepTime: Date?
    @State private var selectedWeeklyDate: Date?
    @State private var weeklySummary: [HealthKitManager.DailySleepSummary] = []
    @State private var isShowingFallback = false
    @State private var fallbackDate: Date? = nil
    @State private var lastNightMissing = false

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

    // Whether there's any sleep data in the past 7 days
    private var hasAnyWeeklyData: Bool {
        weeklySummary.contains { $0.totalMinutes > 0 }
    }

    // Sleep stage colors — Clinical: grayscale hierarchy by depth
    // Deep = textPrimary (darkest), REM = textSecondary, Core = textTertiary, Awake = textQuaternary
    private let deepColor = PulseTheme.textPrimary
    private let remColor = PulseTheme.textSecondary
    private let coreColor = PulseTheme.textTertiary
    private let awakeColor = PulseTheme.textQuaternary

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
                if totalMinutes == 0 && !hasAnyWeeklyData {
                    // Truly no data in 7 days
                    EmptyStateView(
                        icon: "moon.zzz",
                        title: String(localized: "No Sleep Data"),
                        message: String(localized: "Wear your Apple Watch to bed to track sleep.")
                    )
                    .staggered(index: 0)
                } else {
                    // Reminder banner when last night is missing
                    if lastNightMissing {
                        watchReminderBanner
                            .staggered(index: 0)
                    }

                    // Fallback date banner
                    if isShowingFallback, let fbDate = fallbackDate {
                        fallbackBanner(date: fbDate)
                            .staggered(index: lastNightMissing ? 1 : 0)
                    }

                    let bannerOffset = (lastNightMissing ? 1 : 0) + (isShowingFallback ? 1 : 0)

                    if totalMinutes > 0 {
                        hypnogramChart
                            .staggered(index: bannerOffset)

                        summaryStatsRow
                            .staggered(index: bannerOffset + 1)
                    }

                    // Weekly sleep chart — always shown when there's any weekly data
                    if hasAnyWeeklyData {
                        weeklySleepChart
                            .staggered(index: bannerOffset + (totalMinutes > 0 ? 2 : 0))
                    }

                    if totalMinutes > 0 {
                        let weeklyOffset = hasAnyWeeklyData ? 1 : 0
                        sleepScoreCard
                            .staggered(index: bannerOffset + 3 + weeklyOffset)

                        stageBreakdownCard
                            .staggered(index: bannerOffset + 4 + weeklyOffset)

                        insightsCard
                            .staggered(index: bannerOffset + 5 + weeklyOffset)
                    }
                }

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
        // 1. Try last night (24h)
        let lastNight = try? await healthManager.fetchLastNightSleep()
        let lastNightTotal = lastNight?.total ?? 0

        if lastNightTotal == 0 {
            lastNightMissing = true
            // 2. Fallback: most recent session within 7 days
            let fallback = try? await healthManager.fetchMostRecentSleep()
            if (fallback?.total ?? 0) > 0 {
                isShowingFallback = true
                fallbackDate = healthManager.lastNightSleepStart
                // Fetch hypnogram samples for fallback session
                let fetched = (try? await healthManager.fetchMostRecentSleepSamples()) ?? []
                samples = fetched
            }
        } else {
            // Normal path — last night has data
            lastNightMissing = false
            let fetched = (try? await healthManager.fetchSleepSamples()) ?? []
            samples = fetched
        }

        // 3. Always fetch weekly summary
        weeklySummary = (try? await healthManager.fetchWeekSleepSummary()) ?? []

        isLoading = false
        withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
            chartAppeared = true
        }
    }

    // MARK: - Watch Reminder Banner

    private var watchReminderBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PulseTheme.sleepAccent)
            Text("昨晚没有检测到睡眠，记得戴手表睡觉哦")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PulseTheme.sleepAccent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(PulseTheme.sleepAccent.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Fallback Date Banner

    private func fallbackBanner(date: Date) -> some View {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale.current
            f.dateFormat = "M月d日"
            return f
        }()
        return HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PulseTheme.textTertiary)
            Text("显示最近一次睡眠记录 (\(formatter.string(from: date)))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PulseTheme.border.opacity(0.15))
        )
    }

    // MARK: - Weekly Sleep Bar Chart

    private var weeklySleepChart: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PulseTheme.sleepAccent)

                Text(String(localized: "本周睡眠"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Spacer()

                let avgHours = weeklyAverageHours
                if avgHours > 0 {
                    Text(String(format: "均 %.1fh", avgHours))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }

            Chart {
                ForEach(weeklySummary, id: \.date) { day in
                    if day.totalMinutes > 0 {
                        // Total sleep bar (lighter)
                        BarMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Total", Double(day.totalMinutes) / 60.0)
                        )
                        .foregroundStyle(PulseTheme.sleepAccent.opacity(0.3))
                        .cornerRadius(4)

                        // Deep sleep overlay (darker)
                        BarMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Deep", Double(day.deepMinutes) / 60.0)
                        )
                        .foregroundStyle(PulseTheme.sleepAccent)
                        .cornerRadius(4)
                    } else {
                        // Empty day — dashed outline placeholder
                        BarMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Placeholder", 0.15)
                        )
                        .foregroundStyle(Color.clear)
                        .annotation(position: .top, spacing: 0) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(PulseTheme.border.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                .frame(height: 50)
                        }
                    }
                }

                // 7h reference line
                RuleMark(y: .value("Target", 7))
                    .foregroundStyle(PulseTheme.textTertiary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("7h")
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }

                if let selectedWeeklyDate {
                    RuleMark(x: .value("Selected", selectedWeeklyDate, unit: .day))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 0.5))
                }
            }
            .chartYScale(domain: 0...(max(10, weeklyMaxHours + 1)))
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
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(Locale.current))
                        .font(.system(size: 9))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let plotFrame = geo[proxy.plotAreaFrame]
                                let x = value.location.x - plotFrame.origin.x
                                guard let date: Date = proxy.value(atX: x) else { return }
                                let cal = Calendar.current
                                if let nearest = weeklySummary.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                    let newDate = cal.startOfDay(for: nearest.date)
                                    if selectedWeeklyDate != newDate {
                                        selectedWeeklyDate = newDate
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.25)) { selectedWeeklyDate = nil }
                            }
                        )
                }
            }
            .overlay(alignment: .top) {
                if let sel = selectedWeeklyDate,
                   let day = weeklySummary.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
                    let weekdayFmt: DateFormatter = {
                        let f = DateFormatter()
                        f.locale = Locale.current
                        f.dateFormat = "EEEE"
                        return f
                    }()
                    VStack(spacing: 2) {
                        if day.totalMinutes > 0 {
                            Text(String(format: "%.1fh / %.1fh deep", Double(day.totalMinutes) / 60.0, Double(day.deepMinutes) / 60.0))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(PulseTheme.textPrimary)
                        } else {
                            Text("无数据")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(PulseTheme.textSecondary)
                        }
                        Text(weekdayFmt.string(from: day.date))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(PulseTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedWeeklyDate)
                }
            }
            .frame(height: 150)
        }
        .pulseCard()
    }

    private var weeklyAverageHours: Double {
        let daysWithData = weeklySummary.filter { $0.totalMinutes > 0 }
        guard !daysWithData.isEmpty else { return 0 }
        let total = daysWithData.map(\.totalMinutes).reduce(0, +)
        return Double(total) / Double(daysWithData.count) / 60.0
    }

    private var weeklyMaxHours: Double {
        let maxMinutes = weeklySummary.map(\.totalMinutes).max() ?? 0
        return Double(maxMinutes) / 60.0
    }

    // MARK: - 1. Hypnogram Chart

    private var hypnogramChart: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text(String(localized: "Sleep Stages"))
                .pulseEyebrow()

            Chart {
                ForEach(samples) { sample in
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

                if let selected = selectedSleepTime {
                    RuleMark(x: .value("Selected", selected))
                        .foregroundStyle(PulseTheme.textSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartXScale(domain: (samples.map(\.start).min() ?? Date())...(samples.map(\.end).max() ?? Date()))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)).locale(Locale.current))
                        .font(.system(size: 9))
                        .foregroundStyle(PulseTheme.textTertiary)
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
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let origin = geo[proxy.plotFrame!].origin
                                    let x = drag.location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        if date != selectedSleepTime {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                        selectedSleepTime = date
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        selectedSleepTime = nil
                                    }
                                }
                        )
                }
            }
            .overlay(alignment: .top) {
                if let selected = selectedSleepTime,
                   let stage = samples.first(where: { selected >= $0.start && selected < $0.end }) {
                    sleepTooltip(stage: stage.stage, time: selected)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedSleepTime)
                }
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

    private func stageName(_ stage: HealthKitManager.SleepStage) -> String {
        switch stage {
        case .deep: return String(localized: "Deep")
        case .core: return String(localized: "Core")
        case .rem: return "REM"
        case .awake: return String(localized: "Awake")
        }
    }

    private func sleepTooltip(stage: HealthKitManager.SleepStage, time: Date) -> some View {
        VStack(spacing: 4) {
            Text(stageName(stage))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PulseTheme.textPrimary)
            Text(time.formatted(.dateTime.hour().minute().locale(Locale.current)))
                .font(.system(size: 12))
                .foregroundStyle(PulseTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
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
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Stage Breakdown"))
                .pulseEyebrow()
                .padding(.bottom, PulseTheme.spacingM)

            stageRow(name: String(localized: "Deep"), minutes: deepMinutes, color: deepColor, isFirst: true)
            stageRow(name: "REM", minutes: remMinutes, color: remColor, isFirst: false)
            stageRow(name: String(localized: "Core"), minutes: coreMinutes, color: coreColor, isFirst: false)
            stageRow(name: String(localized: "Awake"), minutes: awakeMinutes, color: awakeColor, isFirst: false)
        }
        .pulseCard()
    }

    private func stageRow(name: String, minutes: Int, color: Color, isFirst: Bool) -> some View {
        let windowMinutes = max(1, totalMinutes + awakeMinutes)
        let pct = Int(round(Double(minutes) / Double(windowMinutes) * 100))

        return HStack(spacing: 14) {
            // Hairline swatch (Clinical: 4×32 vertical bar)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(color)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PulseTheme.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(minutes))
                    .font(PulseTheme.metricSFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Text("\(pct)%")
                    .font(PulseTheme.monoFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle()
                    .fill(PulseTheme.border)
                    .frame(height: PulseTheme.hairline)
            }
        }
    }

    // MARK: - 5. Insights

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "Insights"))
                .pulseEyebrow()

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
        if isShowingFallback {
            return String(localized: "最近一次睡眠 \(hours)h")
        }
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
