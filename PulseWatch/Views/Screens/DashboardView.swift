import SwiftUI
import SwiftData

/// Tab 1: 今日状态总览 — 评分大圆环 + 洞察卡片 + 指标网格 + 趋势图 + 训练建议
struct DashboardView: View {

    @AppStorage("pulse.demo.enabled") private var demoMode = false

    @State private var healthManager = HealthKitManager.shared
    @State private var connectivityManager = WatchConnectivityManager.shared
    @State private var isLoading = true
    @State private var brief: ScoreEngine.DailyBrief?
    @State private var insight: HealthInsight?
    @State private var showLocationSetup = false
    @State private var showShareSheet = false
    @State private var showGymPrompt = false
    @State private var breathe = false

    // 圆环动画状态
    @State private var animatedScore: Int = 0
    @State private var ringProgress: CGFloat = 0
    @State private var ringAnimated = false

    // 演示模式时间线事件
    @State private var demoTimelineEvents: [TimelineEvent] = []

    // Streak
    @State private var currentStreak: Int = 0

    // Strain
    @State private var todayStrain: Int = 0

    // Tri-Score
    @State private var triScore: TriScoreService.TriScore?
    // Health Age
    @State private var healthAgeResult: HealthAgeService.HealthAgeResult?
    @State private var healthAgeExpanded = false

    @Query(sort: \WorkoutRecord.date, order: .reverse) private var recentWorkouts: [WorkoutRecord]
    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @Query private var savedLocations: [SavedLocation]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // HERO — full-bleed atmospheric section
                    if let brief {
                        heroSection(score: brief.score, headline: brief.headline)
                            .staggered(index: 0)
                    } else if isLoading {
                        loadingCard
                            .padding(.horizontal, PulseTheme.spacingM)
                    } else if !healthManager.hasHealthData && !demoMode {
                        VStack(spacing: PulseTheme.spacingM) {
                            healthKitPermissionGuide
                                .staggered(index: 1)
                            Text(String(localized: "Or wear your Apple Watch to collect data"))
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                                .padding(.horizontal, PulseTheme.spacingM)
                                .staggered(index: 2)
                        }
                        .padding(.horizontal, PulseTheme.spacingM)
                    } else {
                        emptyStateCard
                            .staggered(index: 1)
                            .padding(.horizontal, PulseTheme.spacingM)
                    }

                    // BELOW HERO — cards with padding
                    VStack(spacing: PulseTheme.spacingM) {
                        // Sleep & Activity summary cards
                        if let tri = triScore {
                            ouraSleepActivityCards(tri)
                                .staggered(index: 1)
                        }

                        // Streak badge
                        if currentStreak >= 3 {
                            streakBadge(streak: currentStreak)
                                .staggered(index: 2)
                        }

                        // Strain vs Recovery
                        if todayStrain > 0 || (brief != nil && demoMode) {
                            strainRecoveryCard(
                                strain: todayStrain,
                                recovery: insight?.recoveryScore ?? brief?.score ?? 0
                            )
                            .staggered(index: 3)
                        }

                        // Health Age
                        if let result = healthAgeResult {
                            healthAgeCard(result: result)
                                .staggered(index: 3)
                        }

                        // Insights
                        if let insight, !insight.insights.isEmpty {
                            let mergedInsights: [String] = {
                                var list = insight.insights
                                if let tri = triScore {
                                    list[0] = tri.readiness.advice
                                }
                                return list
                            }()
                            insightCards(mergedInsights)
                                .staggered(index: 2)
                        }

                        // Metrics grid
                        if hasAnyMetric {
                            metricsGrid
                                .staggered(index: 3)
                        }

                        // Weekly trends
                        WeeklyTrendChartsView(
                            summaries: allSummaries,
                            demoMode: demoMode
                        )
                        .staggered(index: 4)

                        // Recovery timeline
                        recoveryTimelineSection
                            .staggered(index: 5)

                        // Training advice
                        if let advice = insight?.trainingAdvice {
                            trainingAdviceCard(advice: advice)
                                .staggered(index: 6)
                        } else if let plan = brief?.trainingPlan, plan.targetMuscleGroup != "rest" {
                            TrainingCard(plan: plan)
                                .staggered(index: 6)
                        }

                        // Recovery note
                        if let note = brief?.recoveryNote {
                            RecoveryCard(note: note)
                                .staggered(index: 7)
                        }

                        // Recent workouts
                        if !recentWorkouts.isEmpty {
                            recentWorkoutsSection
                                .staggered(index: 8)
                        }

                        // Gym setup
                        if !hasGymLocation {
                            gymSetupPrompt
                                .staggered(index: 9)
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, PulseTheme.spacingM)
                    .padding(.top, PulseTheme.spacingM)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if brief != nil {
                            Button {
                                showShareSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16))
                                    .foregroundStyle(PulseTheme.textTertiary)
                            }
                        }
                        Button {
                            showLocationSetup = true
                        } label: {
                            Image(systemName: "location.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let brief, let image = ShareCardView(
                    workoutName: brief.headline,
                    workoutIcon: "heart.circle.fill",
                    workoutColorHex: brief.score >= 70 ? "7FB069" : (brief.score >= 40 ? "D4A056" : "C75C5C"),
                    durationMinutes: 0,
                    calories: nil,
                    averageHeartRate: nil,
                    maxHeartRate: nil,
                    distance: nil,
                    heartRateZones: [],
                    date: .now
                ).renderImage(for: .story) {
                    ShareSheet(items: [image])
                        .onAppear { Analytics.trackShareTapped(source: "dashboard") }
                }
            }
            .sheet(isPresented: $showLocationSetup) {
                LocationSetupView()
            }
            .fullScreenCover(isPresented: $showGymPrompt) {
                GymArrivalFlowView(
                    readinessScore: insight?.recoveryScore ?? brief?.score ?? 50,
                    strainScore: todayStrain
                )
                .preferredColorScheme(.dark)
            }
            .task {
                await loadData()
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
            .refreshable {
                await loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didEnterSavedRegion)) { notification in
                handleGeofenceEntry(notification)
            }
        }
    }

    // MARK: - Hero Section (Oura-style)

    private func heroSection(score: Int, headline: String) -> some View {
        VStack(spacing: PulseTheme.spacingL) {
                // Score pills row
                if let tri = triScore {
                    scorePillsRow(
                        total: score,
                        sleep: tri.sleep.score,
                        activity: tri.activity.score,
                        readiness: tri.readiness.score
                    )
                } else {
                    scorePillsRow(total: score, sleep: nil, activity: nil, readiness: nil)
                }

                // Arc gauge + score
                ZStack {
                    // Arc track — 200° semicircle
                    arcTrack()
                        .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 220, height: 220)

                    // Arc progress
                    arcTrack()
                        .trim(from: 0, to: ringProgress)
                        .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 220, height: 220)

                    // Marker dot at score position
                    arcMarkerDot(progress: ringProgress, radius: 110)

                    // Score number + label
                    VStack(spacing: 6) {
                        Text("\(animatedScore)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)

                        Text("READINESS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .offset(y: 10)
                }
                .frame(height: 200)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Recovery Score"))
                .accessibilityValue(String(localized: "\(score) out of 100, \(headline)"))
                .onAppear {
                    guard !ringAnimated else { return }
                    ringAnimated = true
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3)) {
                        ringProgress = CGFloat(score) / 100.0
                    }
                    animateScoreCounter(to: score)
                }

                // Headline
                Text(heroHeadline(for: score))
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Insight text
                if let brief {
                    Text(brief.insight)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, PulseTheme.spacingXL)
                }

                // "Learn more" pill button
                Button {} label: {
                    Text("Learn more")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                Spacer().frame(height: PulseTheme.spacingM)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .background {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "0A1628"), location: 0),
                        .init(color: Color(hex: "0F2A3D"), location: 0.25),
                        .init(color: Color(hex: "134E5E"), location: 0.45),
                        .init(color: Color(hex: "0D3B4A"), location: 0.65),
                        .init(color: Color(hex: "0A1A24"), location: 0.85),
                        .init(color: Color.black, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 32,
                        bottomTrailingRadius: 32,
                        topTrailingRadius: 0
                    )
                )
                .ignoresSafeArea(.all, edges: .top)
            }
    }

    // MARK: - Score Pills Row

    private func scorePillsRow(total: Int, sleep: Int?, activity: Int?, readiness: Int?) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            scorePill(icon: "heart.circle.fill", label: "TriScore", value: total, color: PulseTheme.accent)
            if let sleep {
                scorePill(icon: "moon.fill", label: "Sleep", value: sleep, color: PulseTheme.sleepAccent)
            }
            if let activity {
                scorePill(icon: "flame.fill", label: "Activity", value: activity, color: PulseTheme.activityAccent)
            }
            if let readiness {
                scorePill(icon: "bolt.heart.fill", label: "Ready", value: readiness, color: PulseTheme.accent)
            }
        }
    }

    private func scorePill(icon: String, label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "1A1A1A").opacity(0.8))
        )
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Arc Gauge Helpers

    /// 200° arc shape, open at the bottom — from 170° to 370° (= 10°)
    private func arcTrack() -> some Shape {
        Arc(startAngle: .degrees(170), endAngle: .degrees(370), clockwise: false)
    }

    private func arcMarkerDot(progress: CGFloat, radius: CGFloat) -> some View {
        let totalAngle: Double = 200
        let startAngle: Double = 170
        let angle = startAngle + totalAngle * Double(progress)
        let radians = angle * .pi / 180
        let x = cos(radians) * radius
        let y = sin(radians) * radius

        return Circle()
            .fill(.white)
            .frame(width: 8, height: 8)
            .shadow(color: .white.opacity(0.6), radius: 4)
            .offset(x: x, y: y)
    }

    private func heroHeadline(for score: Int) -> String {
        switch score {
        case 0..<30: return String(localized: "Take it easy today")
        case 30..<50: return String(localized: "Listen to your body")
        case 50..<70: return String(localized: "A balanced day ahead")
        case 70..<85: return String(localized: "You're doing great!")
        default: return String(localized: "Go get 'em!")
        }
    }

    // MARK: - Sleep & Activity Summary Cards (Oura-style)

    private func ouraSleepActivityCards(_ tri: TriScoreService.TriScore) -> some View {
        VStack(spacing: PulseTheme.spacingS) {
            ouraSummaryRow(
                icon: "moon.fill",
                iconColor: PulseTheme.sleepAccent,
                title: String(localized: "Sleep"),
                statusLabel: ouraStatusLabel(for: tri.sleep.score),
                statusColor: ouraStatusColor(for: tri.sleep.score),
                score: tri.sleep.score
            )
            ouraSummaryRow(
                icon: "flame.fill",
                iconColor: PulseTheme.activityAccent,
                title: String(localized: "Activity"),
                statusLabel: ouraStatusLabel(for: tri.activity.score),
                statusColor: ouraStatusColor(for: tri.activity.score),
                score: tri.activity.score
            )
        }
    }

    private func ouraSummaryRow(icon: String, iconColor: Color, title: String, statusLabel: String, statusColor: Color, score: Int) -> some View {
        HStack(spacing: PulseTheme.spacingM) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 36)

            // Title
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            // Status badge
            Text(statusLabel.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(statusColor)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, PulseTheme.spacingM)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(Color(hex: "1A1A1A"))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(statusLabel)")
    }

    private func ouraStatusLabel(for score: Int) -> String {
        switch score {
        case 0..<30: return String(localized: "Poor")
        case 30..<50: return String(localized: "Fair")
        case 50..<70: return String(localized: "Good")
        case 70..<85: return String(localized: "Great")
        default: return String(localized: "Optimal")
        }
    }

    private func ouraStatusColor(for score: Int) -> Color {
        switch score {
        case 0..<40: return PulseTheme.activityAccent
        case 40..<70: return Color(hex: "FFD700")
        default: return PulseTheme.statusGood
        }
    }

    /// 数字从0递增到目标值的计数动画
    private func animateScoreCounter(to target: Int) {
        animatedScore = 0
        let steps = target
        guard steps > 0 else { return }
        let totalDuration: Double = 0.8
        let interval = totalDuration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + interval * Double(i)) {
                withAnimation(.easeOut(duration: 0.05)) {
                    animatedScore = i
                }
            }
        }
    }

    // MARK: - 空数据状态

    @State private var emptyPulse = false

    private var emptyStateCard: some View {
        VStack(spacing: PulseTheme.spacingM) {
            ZStack {
                // 脉冲圆环占位符
                Circle()
                    .stroke(PulseTheme.border, lineWidth: 12)
                    .frame(width: 220, height: 220)
                    .scaleEffect(emptyPulse ? 1.04 : 1.0)
                    .opacity(emptyPulse ? 0.5 : 0.8)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: emptyPulse
                    )

                Circle()
                    .fill(PulseTheme.border.opacity(0.05))
                    .frame(width: 260, height: 260)
                    .blur(radius: 30)
            }
            .accessibilityHidden(true)
            .onAppear {
                emptyPulse = true
            }

            Text("☀️ Put on your watch to start tracking")
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, PulseTheme.spacingXL)
        .frame(maxWidth: .infinity)
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

    // MARK: - 今日洞察卡片（简化标题）

    private func insightCards(_ insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Today's Insights")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(insights.prefix(3).enumerated()), id: \.offset) { _, text in
                HStack(alignment: .top, spacing: PulseTheme.spacingS) {
                    Circle()
                        .fill(PulseTheme.accent.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                        .accessibilityHidden(true)

                    Text(text)
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .pulseCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: - 关键指标网格（隐藏空值瓷砖）

    /// 是否有任何有效指标数据
    private var hasAnyMetric: Bool {
        healthManager.latestHeartRate != nil ||
        healthManager.latestHRV != nil ||
        brief?.sleepSummary != nil ||
        healthManager.todaySteps > 0 ||
        healthManager.todayActiveCalories > 0 ||
        healthManager.latestBloodOxygen != nil
    }

    // MARK: - 演示模式指标值

    /// 当前心率（演示或真实）
    private var currentHeartRate: Double? {
        healthManager.latestHeartRate
    }
    private var currentHRV: Double? {
        healthManager.latestHRV
    }
    private var currentSleep: String? {
        brief?.sleepSummary
    }
    private var currentSteps: Int {
        healthManager.todaySteps
    }
    private var currentCalories: Double {
        healthManager.todayActiveCalories
    }
    private var currentBloodOxygen: Double? {
        healthManager.latestBloodOxygen
    }

    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: PulseTheme.spacingM),
            GridItem(.flexible(), spacing: PulseTheme.spacingM),
        ]

        return LazyVGrid(columns: columns, spacing: PulseTheme.spacingM) {
            // 心率
            if let hr = currentHeartRate {
                metricTile(
                    icon: "heart.fill",
                    label: String(localized: "Heart Rate"),
                    value: "\(Int(hr))",
                    unit: "bpm",
                    color: PulseTheme.statusPoor,
                    trend: metricStatus(hr, good: 55...70, ok: 50...80),
                    animated: true
                )
            }

            // HRV
            if let hrv = currentHRV {
                metricTile(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: "\(Int(hrv))",
                    unit: "ms",
                    color: PulseTheme.accent,
                    trend: metricStatus(hrv, good: 45...200, ok: 30...45),
                    animated: false
                )
            }

            // 睡眠
            if let sleep = currentSleep {
                metricTile(
                    icon: "moon.fill",
                    label: String(localized: "Sleep"),
                    value: sleep,
                    unit: "",
                    color: PulseTheme.sleepAccent,
                    trend: .good,
                    animated: false
                )
            }

            // 步数
            if currentSteps > 0 {
                metricTile(
                    icon: "figure.run",
                    label: String(localized: "Steps"),
                    value: formatSteps(currentSteps),
                    unit: "",
                    color: PulseTheme.statusGood,
                    trend: currentSteps >= 8000 ? .good : (currentSteps >= 5000 ? .ok : .poor),
                    animated: true
                )
            }

            // 卡路里
            if currentCalories > 0 {
                metricTile(
                    icon: "flame.fill",
                    label: String(localized: "Calories"),
                    value: "\(Int(currentCalories))",
                    unit: "kcal",
                    color: PulseTheme.statusModerate,
                    trend: currentCalories >= 300 ? .good : .ok,
                    animated: false
                )
            }

            // 血氧
            if let spo2 = currentBloodOxygen {
                metricTile(
                    icon: "lungs.fill",
                    label: String(localized: "Blood Oxygen"),
                    value: "\(Int(spo2))%",
                    unit: "",
                    color: PulseTheme.statusGood,
                    trend: spo2 >= 96 ? .good : (spo2 >= 93 ? .ok : .poor),
                    animated: false
                )
            }
        }
    }

    // MARK: - 指标状态

    enum MetricStatus {
        case good, ok, poor

        var arrow: String {
            switch self {
            case .good: return "arrow.up.right"
            case .ok:   return "arrow.right"
            case .poor: return "arrow.down.right"
            }
        }

        var color: Color {
            switch self {
            case .good: return PulseTheme.statusGood
            case .ok:   return PulseTheme.statusModerate
            case .poor: return PulseTheme.statusPoor
            }
        }
    }

    /// 根据值域判断指标状态
    private func metricStatus(_ value: Double, good: ClosedRange<Double>, ok: ClosedRange<Double>) -> MetricStatus {
        if good.contains(value) { return .good }
        if ok.contains(value) { return .ok }
        return .poor
    }

    private func metricTile(icon: String, label: String, value: String, unit: String, color: Color, trend: MetricStatus, animated: Bool) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // Top row: icon + label
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, options: .repeating, isActive: animated)

                Spacer()

                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            // Value row
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(PulseTheme.metricFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if !unit.isEmpty {
                    Text(unit)
                        .font(PulseTheme.metricLabelFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                // Trend arrow
                Image(systemName: trend.arrow)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(trend.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.cardElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(unit.isEmpty ? value : "\(value) \(unit)")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - 训练建议卡片

    private func trainingAdviceCard(advice: TrainingAdvice) -> some View {
        let adviceColor: Color = {
            switch advice {
            case .intense:  return PulseTheme.statusPoor
            case .moderate: return PulseTheme.statusModerate
            case .light:    return PulseTheme.statusGood
            case .rest:     return PulseTheme.textTertiary
            }
        }()

        return HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(adviceColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: advice.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(adviceColor)
            }

            VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                Text("Training Advice")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)

                Text(advice.label)
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
            }

            Spacer()

            // 强度指示器
            HStack(spacing: 3) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < adviceLevel(advice) ? adviceColor : PulseTheme.border)
                        .frame(width: 6, height: CGFloat(12 + i * 4))
                }
            }
        }
        .pulseCard()
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: PulseTheme.radiusL,
                bottomLeadingRadius: PulseTheme.radiusL
            )
            .fill(adviceColor.opacity(0.3))
            .frame(width: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Training Advice"))
        .accessibilityValue(advice.label)
    }

    private func adviceLevel(_ advice: TrainingAdvice) -> Int {
        switch advice {
        case .rest: return 0
        case .light: return 1
        case .moderate: return 2
        case .intense: return 4
        }
    }

    // (triScoreCard and triScoreRing replaced by heroSection + ouraSleepActivityCards)

    // MARK: - 🔥 Streak Badge

    private func streakBadge(streak: Int) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            // 火焰图标
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.activityAccent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text("🔥")
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "%d-Day Streak"), streak))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(String(localized: "Keep going — don't break the chain!"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()

            // Best streak badge (if current is best)
            if streak >= StreakService.shared.bestStreak && streak > 1 {
                Text(String(localized: "Best"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PulseTheme.activityAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(PulseTheme.activityAccent.opacity(0.15))
                    )
            }
        }
        .pulseCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "%d-Day Streak"), streak))
    }

    // MARK: - Strain vs Recovery Card

    private func strainRecoveryCard(strain: Int, recovery: Int) -> some View {
        let strainLevel = StrainScoreService.StrainLevel(score: strain)
        let strainColor = Color(hex: strainLevel.color)
        let recoveryColor = PulseTheme.statusColor(for: recovery)
        let warning = StrainScoreService.overtrainWarning(strain: strain, recovery: recovery)

        return VStack(spacing: PulseTheme.spacingM) {
            // 双指标并排
            HStack(spacing: PulseTheme.spacingL) {
                // Strain
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.border, lineWidth: 6)
                            .frame(width: 72, height: 72)
                        Circle()
                            .trim(from: 0, to: CGFloat(strain) / 100)
                            .stroke(strainColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(-90))
                        Text("\(strain)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
                    Text("Strain Score")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                    Text(strainLevel.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(strainColor)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(PulseTheme.border)
                    .frame(width: 1, height: 60)

                // Recovery
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.border, lineWidth: 6)
                            .frame(width: 72, height: 72)
                        Circle()
                            .trim(from: 0, to: CGFloat(recovery) / 100)
                            .stroke(recoveryColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(-90))
                        Text("\(recovery)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
                    Text("Recovery")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                    Text(PulseTheme.statusLabel(for: recovery))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(recoveryColor)
                }
                .frame(maxWidth: .infinity)
            }

            // Overtrain warning
            if let warning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(PulseTheme.activityAccent)
                    Text(warning)
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                }
                .padding(.horizontal, PulseTheme.spacingS)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PulseTheme.activityAccent.opacity(0.1))
                )
            }
        }
        .pulseCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "Strain %d, Recovery %d"), strain, recovery))
    }

    // MARK: - Health Age 卡片

    private func healthAgeCard(result: HealthAgeService.HealthAgeResult) -> some View {
        let diff = result.difference
        let isYounger = diff < -0.5
        let accentColor = isYounger ? PulseTheme.statusGood : PulseTheme.activityAccent
        let ageInt = Int(result.healthAge.rounded())

        return VStack(spacing: PulseTheme.spacingM) {
            // 主展示
            Button {
                withAnimation(.spring(response: 0.4)) { healthAgeExpanded.toggle() }
            } label: {
                HStack(spacing: PulseTheme.spacingM) {
                    // 年龄大数字
                    VStack(spacing: 2) {
                        Text("\(ageInt)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("Health Age")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }

                    Spacer()

                    // 差值标签
                    VStack(alignment: .trailing, spacing: 4) {
                        if abs(diff) > 0.5 {
                            HStack(spacing: 4) {
                                Image(systemName: isYounger ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                    .font(.system(size: 16))
                                Text(String(format: String(localized: "%d years %@"), Int(abs(diff).rounded()),
                                            isYounger ? String(localized: "younger") : String(localized: "older")))
                                    .font(PulseTheme.bodyFont.weight(.semibold))
                            }
                            .foregroundStyle(accentColor)
                        }

                        Text(String(format: String(localized: "Actual age: %d"), result.chronologicalAge))
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)

                        Text(String(format: String(localized: "Based on %d days of data"), result.daysOfData))
                            .font(.system(size: 10))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }

                    Image(systemName: healthAgeExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // 置信度提示
            if result.daysOfData < 7 {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.accent)
                    Text("More data = better accuracy. Keep wearing your Watch 📈")
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            // 展开详情
            if healthAgeExpanded {
                Divider().background(PulseTheme.border)

                VStack(spacing: PulseTheme.spacingS) {
                    ForEach(result.metrics, id: \.metric) { metric in
                        healthAgeMetricRow(metric)
                    }
                }
            }
        }
        // 免责声明
        Text("Estimated using population-average baselines. Not a medical assessment.")
            .font(.system(size: 10))
            .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, PulseTheme.spacingS)
        .pulseCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "Health Age %d"), ageInt))
    }

    private func healthAgeMetricRow(_ metric: HealthAgeService.MetricScore) -> some View {
        let isGood = metric.ageImpact < -0.3
        let isBad = metric.ageImpact > 0.3
        let color: Color = isGood ? PulseTheme.statusGood : (isBad ? PulseTheme.activityAccent : PulseTheme.textSecondary)

        return HStack(alignment: .top, spacing: PulseTheme.spacingS) {
            Image(systemName: metric.metric.icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(metric.metric.label)
                        .font(PulseTheme.captionFont.weight(.medium))
                        .foregroundStyle(PulseTheme.textPrimary)
                    Spacer()
                    Text(formatMetricValue(metric))
                        .font(PulseTheme.captionFont.weight(.semibold))
                        .foregroundStyle(color)
                }
                Text(metric.advice)
                    .font(.system(size: 11))
                    .foregroundStyle(PulseTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func formatMetricValue(_ m: HealthAgeService.MetricScore) -> String {
        switch m.metric {
        case .restingHR:      return String(format: "%.0f bpm", m.value)
        case .hrv:            return String(format: "%.0f ms", m.value)
        case .sleep:          return String(format: "%.1fh", m.value)
        case .steps:          return String(format: "%.0f", m.value)
        case .activeMinutes:  return String(format: "%.0f min", m.value)
        }
    }

    // MARK: - 最近训练

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Recent Workouts")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .padding(.leading, PulseTheme.spacingXS)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(recentWorkouts.prefix(3)), id: \.id) { workout in
                workoutRow(workout)
            }
        }
    }

    private func workoutRow(_ workout: WorkoutRecord) -> some View {
        HStack(spacing: PulseTheme.spacingM) {
            // 分类图标
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: workoutCategoryIcon(workout.category))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
            }

            // 名称 + 日期
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutCategoryName(workout.category))
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(relativeDate(workout.date))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()

            // 时长
            Text("(workout.durationMinutes) min")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow.opacity(0.2), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(workoutCategoryName(workout.category)), \(relativeDate(workout.date))")
        .accessibilityValue("\(workout.durationMinutes) \(String(localized: "minutes"))")
    }

    /// 训练分类 -> SF Symbol 图标
    private func workoutCategoryIcon(_ category: String) -> String {
        switch category {
        case "chest": return "figure.strengthtraining.traditional"
        case "back": return "figure.rowing"
        case "legs": return "figure.step.training"
        case "shoulders": return "figure.arms.open"
        case "arms": return "dumbbell.fill"
        case "cardio": return "figure.run"
        default: return "figure.mixed.cardio"
        }
    }

    /// 训练分类 -> 中文名称
    private func workoutCategoryName(_ category: String) -> String {
        switch category {
        case "chest": return String(localized: "Chest")
        case "back": return String(localized: "Back")
        case "legs": return String(localized: "Legs")
        case "shoulders": return String(localized: "Shoulders")
        case "arms": return String(localized: "Arms")
        case "cardio": return String(localized: "Cardio")
        default: return category
        }
    }

    /// 相对日期：今天、昨天、N天前
    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        switch days {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Yesterday")
        default: return "(days)d ago"
        }
    }

    // MARK: - 健身房设置

    private var gymSetupPrompt: some View {
        Button {
            showLocationSetup = true
        } label: {
            HStack(spacing: PulseTheme.spacingM) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PulseTheme.accent.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: "mappin.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PulseTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Gym Location")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)

                    Text("Auto-remind when arriving")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .padding(PulseTheme.spacingM)
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
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Set Gym Location"))
        .accessibilityHint(String(localized: "Opens gym location setup for automatic arrival reminders"))
    }

    // MARK: - 身体时间线

    @ViewBuilder
    private var recoveryTimelineSection: some View {
        if demoMode {
            // 演示模式 — 使用模拟时间线
            RecoveryTimelineView(events: demoTimelineEvents)
        } else {
            RecoveryTimelineSection()
        }
    }

    // MARK: - 辅助

    private var loadingCard: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
            .fill(PulseTheme.cardBackground)
            .frame(height: 200)
            .shadow(color: PulseTheme.cardShadow, radius: 16, y: 6)
            .overlay(
                ProgressView()
                    .tint(PulseTheme.accent)
            )
    }

    private var hasGymLocation: Bool {
        savedLocations.contains { $0.locationType == "gym" && $0.isActive }
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }

    // MARK: - 数据加载

    private func loadData() async {
        isLoading = true

        #if DEBUG
        if demoMode {
            // 演示模式 — 仅 DEBUG 构建 + 明确开启时
            brief = DemoDataProvider.makeBrief()
            insight = DemoDataProvider.makeInsight()
            demoTimelineEvents = DemoDataProvider.makeTimelineEvents()
            StreakService.shared.setDemoStreak(12)
            currentStreak = StreakService.shared.currentStreak
            todayStrain = StrainScoreService.demoStrain
            healthAgeResult = HealthAgeService.demoResult
            triScore = TriScoreService.demoTriScore
            ringAnimated = false
            isLoading = false
            return
        }
        #endif

        do {
            try await healthManager.requestAuthorization()
            await healthManager.refreshAll()

            let sleep = try await healthManager.fetchLastNightSleep()

            brief = ScoreEngine.generateBrief(
                hrv: healthManager.latestHRV,
                restingHR: healthManager.latestRestingHR,
                bloodOxygen: healthManager.latestBloodOxygen,
                sleepMinutes: sleep.total,
                deepSleepMinutes: sleep.deep,
                remSleepMinutes: sleep.rem,
                steps: healthManager.todaySteps,
                recentWorkouts: recentWorkouts
            )

            if let brief {
                Analytics.trackScoreViewed(score: brief.score)
            }

            // 同步 workout 总数到 ReviewRequestManager
            ReviewRequestManager.shared.syncWorkoutCount(recentWorkouts.count)

            // 生成 AI 洞察
            insight = await MainActor.run {
                HealthAnalyzer.shared.generateInsight()
            }

            // 同步到手表
            if let brief {
                connectivityManager.sendHealthSummary(
                    score: brief.score,
                    headline: brief.headline,
                    insight: brief.insight,
                    heartRate: Int(healthManager.latestHeartRate ?? 0),
                    steps: healthManager.todaySteps
                )

                // 重新触发圆环动画（刷新后）
                ringAnimated = false
            }
        } catch {
            #if DEBUG
            print("Dashboard load error: \(error)")
            #endif
        }

        // Streak 计算
        StreakService.shared.refresh(modelContext: modelContext)
        currentStreak = StreakService.shared.currentStreak

        // Strain Score
        todayStrain = StrainScoreService.shared.todayStrain(modelContext: modelContext)

        // Health Age
        healthAgeResult = HealthAgeService.shared.compute(modelContext: modelContext)

        // Tri-Score
        triScore = TriScoreService.shared.compute(modelContext: modelContext)

        isLoading = false
    }

    // MARK: - 地理围栏

    private func handleGeofenceEntry(_ notification: Notification) {
        guard let regionId = notification.userInfo?["regionId"] as? String else { return }

        guard let location = savedLocations.first(where: {
            $0.id.uuidString == regionId && $0.locationType == "gym"
        }) else { return }

        let group = brief?.trainingPlan?.targetMuscleGroup ?? "chest"
        let reason = brief?.trainingPlan?.reason ?? "Arrived at \(location.name)"

        connectivityManager.sendGymArrival(muscleGroup: group, reason: reason)
        showGymPrompt = true
    }

    // MARK: - HealthKit Permission Guide (Inline)
    
    private var healthKitPermissionGuide: some View {
        VStack(spacing: PulseTheme.spacingL) {
            // Heart icon with pulse animation
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(PulseTheme.accent)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            VStack(spacing: PulseTheme.spacingM) {
                Text(String(localized: "Enable Health Access"))
                    .font(PulseTheme.titleFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(String(localized: "Pulse Watch needs access to your health data to provide personalized insights, recovery scores, and training recommendations."))
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button {
                openAppSettings()
            } label: {
                HStack(spacing: PulseTheme.spacingS) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .medium))
                    Text(String(localized: "Open Settings"))
                        .font(PulseTheme.bodyFont.weight(.semibold))
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
            .accessibilityLabel(String(localized: "Open Settings"))
            .accessibilityHint(String(localized: "Opens system settings to enable Health data access"))
        }
        .padding(.vertical, PulseTheme.spacingXL)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow, radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .stroke(PulseTheme.accent.opacity(0.15), lineWidth: 0.5)
        )
    }
    
    private func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func localizedGroup(_ group: String) -> String {
        switch group {
        case "chest": return String(localized: "Chest")
        case "back": return String(localized: "Back")
        case "legs": return String(localized: "Legs")
        case "shoulders": return String(localized: "Shoulders")
        default: return group
        }
    }
}

// MARK: - Arc Shape (200° semicircle gauge)

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        return path
    }
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}
