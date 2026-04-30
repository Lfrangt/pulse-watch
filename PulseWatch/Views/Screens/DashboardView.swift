import SwiftUI
import SwiftData
import os

/// Tab 1: 今日状态总览 — 评分大圆环 + 洞察卡片 + 指标网格 + 趋势图 + 训练建议
struct DashboardView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "DashboardView")

    @AppStorage("pulse.demo.enabled") private var demoMode = false

    private let healthManager = HealthKitManager.shared
    private let connectivityManager = WatchConnectivityManager.shared
    @State private var isLoading = true
    @State private var brief: ScoreEngine.DailyBrief?
    @State private var insight: HealthInsight?
    @State private var showLocationSetup = false
    @State private var showGymPrompt = false
    @State private var breathe = false

    @State private var animatedScore: Int = 0
    @State private var ringAnimated = false

    // 演示模式时间线事件
    @State private var demoTimelineEvents: [TimelineEvent] = []

    // Strain
    @State private var todayStrain: Int = 0

    // Tri-Score
    @State private var triScore: TriScoreService.TriScore?
    // Health Age
    @State private var healthAgeResult: HealthAgeService.HealthAgeResult?
    @State private var healthAgeExpanded = false
    @State private var showShareSnapshot = false

    @Query(sort: \WorkoutRecord.date, order: .reverse) private var recentWorkouts: [WorkoutRecord]
    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @Query private var savedLocations: [SavedLocation]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Clinical: flat surface, no gradient, no glow
                PulseTheme.background
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // HEADER — date eyebrow + Today title (matches Today.jsx)
                        dashboardHeader
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        // HERO — content-driven height, no GeometryReader
                        if let brief {
                            heroSection(score: brief.score, headline: brief.headline)
                                .staggered(index: 0)
                        } else if isLoading {
                            heroLoadingPlaceholder
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
                        VStack(spacing: 24) {

                            // ── JSX Today.jsx layout ──────────────────────

                            // Vitals grid — HRV / RHR / SpO2 / Steps
                            if hasAnyMetric {
                                VitalsGrid(
                                    hrv: currentHRV,
                                    restingHR: healthManager.latestRestingHR,
                                    spo2: currentBloodOxygen,
                                    steps: currentSteps > 0 ? currentSteps : nil
                                )
                                .staggered(index: 2)
                            }

                            // Sleep band — Last Night
                            if healthManager.lastNightSleepMinutes > 0 {
                                NavigationLink(destination: SleepDetailView()) {
                                    SleepBandCard(
                                        totalMinutes: healthManager.lastNightSleepMinutes,
                                        deepMinutes: healthManager.lastNightDeepSleepMinutes,
                                        remMinutes: healthManager.lastNightREMSleepMinutes,
                                        coreMinutes: max(0, healthManager.lastNightSleepMinutes
                                                              - healthManager.lastNightDeepSleepMinutes
                                                              - healthManager.lastNightREMSleepMinutes),
                                        awakeMinutes: 0,
                                        bedTime: healthManager.lastNightSleepStart,
                                        wakeTime: healthManager.lastNightSleepEnd
                                    )
                                }
                                .buttonStyle(.plain)
                                .staggered(index: 3)
                            }

                            // Training suggestion
                            if let plan = brief?.trainingPlan, plan.targetMuscleGroup != "rest" {
                                SuggestionCard(
                                    intensity: plan.intensity.rawValue,
                                    intensityColor: intensityColor(for: plan.intensity),
                                    workoutTitle: workoutTitle(for: plan),
                                    subtitle: plan.reason,
                                    exercises: plan.suggestedExercises.map { ex in
                                        SuggestionCard.Exercise(
                                            name: ex.name,
                                            sets: "\(ex.sets) × \(ex.reps)",
                                            weight: ex.suggestedWeight.map { String(format: "%.0f kg", $0) } ?? ""
                                        )
                                    }
                                )
                                .staggered(index: 4)
                            }

                            // 7-day readiness chart
                            WeeklyReadinessChart(scores: sevenDayAllScores())
                                .staggered(index: 5)

                            // ── Pulse-specific extras divider ─────────────

                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(PulseTheme.border)
                                    .frame(height: PulseTheme.hairline)
                                Text(String(localized: "More from Pulse"))
                                    .pulseEyebrow()
                                    .layoutPriority(1)
                                Rectangle()
                                    .fill(PulseTheme.border)
                                    .frame(height: PulseTheme.hairline)
                            }
                            .padding(.top, 8)
                            .staggered(index: 6)

                            // Energy Bank
                            energyBankCard
                                .staggered(index: 6)

                            // Nutrition — coming soon teaser
                            nutritionCard
                                .staggered(index: 7)

                            // Weekly trends (legacy chart — keep for now)
                            WeeklyTrendChartsView(
                                summaries: allSummaries,
                                demoMode: demoMode
                            )
                            .staggered(index: 7)

                            // Health Age — compact, tap to detail
                            if let result = healthAgeResult {
                                NavigationLink(destination: HealthAgeDetailView(result: result)) {
                                    healthAgeCardCompact(result: result)
                                }
                                .buttonStyle(.plain)
                                .staggered(index: 8)
                            }

                            // Recovery timeline
                            recoveryTimelineSection
                                .staggered(index: 9)

                            // Goal progress
                            GoalProgressCard()
                                .staggered(index: 7)

                            // Share snapshot button
                            Button { showShareSnapshot = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 13, weight: .medium))
                                    Text(String(localized: "分享今日快照"))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(PulseTheme.accentTeal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                                        .fill(PulseTheme.accentTeal.opacity(0.08))
                                )
                            }
                            .staggered(index: 7)

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

                            Spacer(minLength: 16)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, PulseTheme.spacingM)
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            } // end ZStack
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLocationSetup) {
                LocationSetupView()
            }
            .sheet(isPresented: $showShareSnapshot) {
                HealthSnapshotShareScreen()
                    .preferredColorScheme(.dark)
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
        .preferredColorScheme(.dark)
    }

    // MARK: - Dashboard Header — date eyebrow + Today title (Today.jsx pattern)

    private var dashboardHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerDateString)
                    .pulseEyebrow()
                Text(String(localized: "Today"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
            }
            Spacer()
            Button {
                // Tap = scroll to top / refresh
            } label: {
                Image(systemName: "clock")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(PulseTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
        }
    }

    private var headerDateString: String {
        let fmt = DateFormatter()
        fmt.locale = .current
        fmt.dateFormat = "EEE · MMM d"
        return fmt.string(from: .now)
    }

    // MARK: - Hero Section — Clinical ReadinessCard
    // 72pt big number, eyebrow label, status chip, 7-day sparkline. No ring.

    private func heroSection(score: Int, headline: String) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // Top row: eyebrow + status chip
            HStack {
                Text(String(localized: "Readiness"))
                    .pulseEyebrow()
                Spacer()
                statusChip(for: score)
            }

            // Big number + delta
            HStack(alignment: .firstTextBaseline, spacing: PulseTheme.spacingS) {
                Text("\(animatedScore)")
                    .font(PulseTheme.metricXLFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .contentTransition(.numericText())

                Text("/ 100")
                    .font(PulseTheme.calloutFont)
                    .foregroundStyle(PulseTheme.textTertiary)

                Spacer()

                let baseline = sevenDayBaseline()
                VStack(alignment: .trailing, spacing: 2) {
                    if let baseline {
                        let diff = score - baseline
                        Text(diff >= 0 ? "+\(diff) vs 7-day avg" : "\(diff) vs 7-day avg")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(diff >= 0 ? PulseTheme.statusGood : PulseTheme.statusPoor)
                            .monospacedDigit()
                        Text("baseline \(baseline)")
                            .font(PulseTheme.monoFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
            }

            // 7-day sparkline
            ReadinessSparkline(todayScore: score, priorScores: sevenDayPriorScores())

            // Headline + insight
            if !headline.isEmpty {
                VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                    Text(headline)
                        .font(PulseTheme.title2Font)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let insight = brief?.insight {
                        Text(insight)
                            .font(PulseTheme.calloutFont)
                            .foregroundStyle(PulseTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }
                }
                .padding(.top, PulseTheme.spacingXS)
            }
        }
        .pulseCard(padding: PulseTheme.spacingL)
        .padding(.horizontal, PulseTheme.spacingM)
        .padding(.top, PulseTheme.spacingS)
        .onAppear {
            guard !ringAnimated else { return }
            ringAnimated = true
            animateScoreCounter(to: score)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Recovery Score \(score), \(headline)"))
    }

    private func statusChip(for score: Int) -> some View {
        let label: String
        let color: Color
        switch score {
        case 0..<40:  label = String(localized: "Poor");     color = PulseTheme.statusPoor
        case 40..<70: label = String(localized: "Moderate"); color = PulseTheme.statusModerate
        case 70..<85: label = String(localized: "Good");     color = PulseTheme.statusGood
        default:      label = String(localized: "Peak");     color = PulseTheme.statusGood
        }
        return Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusXS, style: .continuous)
                    .stroke(color, lineWidth: PulseTheme.hairline)
            )
    }

    /// Six prior days, oldest → most recent. nil for days without data.
    private func sevenDayPriorScores() -> [Int?] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (1...6).reversed().map { offset -> Int? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return allSummaries.first { cal.isDate($0.date, inSameDayAs: d) }?.dailyScore
        }
    }

    /// All 7 days including today, oldest → most recent.
    private func sevenDayAllScores() -> [Int?] {
        sevenDayPriorScores() + [brief?.score]
    }

    private func intensityColor(for intensity: TrainingPlan.Intensity) -> Color {
        switch intensity {
        case .light:    return PulseTheme.statusGood
        case .moderate: return PulseTheme.accent
        case .heavy:    return PulseTheme.statusWarning
        }
    }

    private func workoutTitle(for plan: TrainingPlan) -> String {
        switch plan.targetMuscleGroup.lowercased() {
        case "chest":     return String(localized: "Push — Chest & Triceps")
        case "back":      return String(localized: "Pull — Back & Biceps")
        case "legs":      return String(localized: "Legs — Quads, Hams & Glutes")
        case "shoulders": return String(localized: "Shoulders & Core")
        case "arms":      return String(localized: "Arms — Biceps & Triceps")
        case "core":      return String(localized: "Core & Mobility")
        default:          return plan.targetMuscleGroup.capitalized
        }
    }

    private func sevenDayBaseline() -> Int? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let prior6 = (1...6).compactMap { offset -> Int? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return allSummaries.first { cal.isDate($0.date, inSameDayAs: d) }?.dailyScore
        }
        guard !prior6.isEmpty else { return nil }
        return prior6.reduce(0, +) / prior6.count
    }

    // MARK: - Oura Score Disc Row

    private func ouraScoreDiscRow(total: Int, sleep: Int?, activity: Int?, readiness: Int?) -> some View {
        HStack(spacing: 0) {
            if let sleep {
                NavigationLink(destination: SleepDetailView()) {
                    ouraScoreDisc(icon: "moon.fill", iconColor: PulseTheme.sleepViolet, label: String(localized: "睡眠"), value: sleep)
                }
                .buttonStyle(.plain)
            }
            if let activity {
                NavigationLink(destination: ActivityDetailView()) {
                    ouraScoreDisc(icon: "figure.run", iconColor: PulseTheme.activityCoral, label: String(localized: "活动"), value: activity)
                }
                .buttonStyle(.plain)
            }
            // HRV disc
            if let hrv = currentHRV {
                NavigationLink(destination: HRVDetailView()) {
                    ouraScoreDisc(icon: "waveform.path.ecg", iconColor: PulseTheme.accentTeal, label: "HRV", value: Int(hrv), unit: "ms")
                }
                .buttonStyle(.plain)
            } else if let hr = currentHeartRate {
                NavigationLink(destination: HeartRateDetailView()) {
                    ouraScoreDisc(icon: "heart.fill", iconColor: PulseTheme.activityCoral, label: String(localized: "心率"), value: Int(hr), unit: "bpm")
                }
                .buttonStyle(.plain)
            }
            // Stress disc
            NavigationLink(destination: StressDetailView()) {
                ouraScoreDisc(
                    icon: "brain.head.profile",
                    iconColor: currentStressColor,
                    label: String(localized: "压力"),
                    value: currentStressScore
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }

    private func ouraScoreDisc(icon: String, iconColor: Color = PulseTheme.textPrimary, label: String, value: Int, unit: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .pulseEyebrow()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)")
                    .font(PulseTheme.metricSFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(PulseTheme.unitFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseTheme.spacingM)
        .background(PulseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.border, lineWidth: PulseTheme.hairline)
        )
        .padding(.horizontal, 4)
        .accessibilityLabel("\(label) \(value) \(unit)")
    }

    // MARK: - Score Pills Row

    private func scorePillsRow(total: Int, sleep: Int?, activity: Int?, readiness: Int?) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            scorePill(icon: "bolt.fill", label: "TriScore", value: total, color: PulseTheme.accentTeal)
            if let sleep {
                scorePill(icon: "moon.fill", label: "Sleep", value: sleep, color: PulseTheme.sleepAccent)
            }
            if let activity {
                scorePill(icon: "flame.fill", label: "Activity", value: activity, color: PulseTheme.activityAccent)
            }
            if let readiness {
                scorePill(icon: "heart.fill", label: "Ready", value: readiness, color: PulseTheme.textSecondary)
            }
        }
    }

    private func scorePill(icon: String, label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(PulseTheme.highlight)
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 0.5)
                )
        )
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Arc Gauge Helpers

    /// 200° arc shape, open at the bottom — from 170° to 370° (= 10°)
    private func arcTrack() -> some Shape {
        Arc(startAngle: .degrees(170), endAngle: .degrees(370), clockwise: false)
    }

    /// Arc progress stroke with a smooth teal-to-transparent tail at the start
    @ViewBuilder
    private func arcGaugeProgress(progress: CGFloat) -> some View {
        let teal = PulseTheme.accentTeal
        ZStack {
            // Faded tail: short segment at the start fades from clear → teal
            arcTrack()
                .trim(from: 0, to: min(progress, 0.15))
                .stroke(
                    LinearGradient(
                        colors: [teal.opacity(0), teal.opacity(0.55)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 160, height: 160)

            // Main body: from fade-in point to end
            if progress > 0.12 {
                arcTrack()
                    .trim(from: 0.12, to: progress)
                    .stroke(teal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 160, height: 160)
            }
        }
    }

    private func arcMarkerDot(progress: CGFloat, radius: CGFloat) -> some View {
        let totalAngle: Double = 200
        let startAngle: Double = 170
        let angle = startAngle + totalAngle * Double(progress)
        let radians = angle * .pi / 180
        let x = cos(radians) * radius
        let y = sin(radians) * radius

        return Circle()
            .fill(PulseTheme.textPrimary)
            .frame(width: 8, height: 8)
            .shadow(color: PulseTheme.textSecondary, radius: 4)
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
            NavigationLink(destination: SleepDetailView()) {
                ouraSummaryRow(
                    icon: "moon.fill",
                    iconColor: PulseTheme.sleepAccent,
                    title: String(localized: "Sleep"),
                    statusLabel: ouraStatusLabel(for: tri.sleep.score),
                    statusColor: ouraStatusColor(for: tri.sleep.score),
                    score: tri.sleep.score
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ActivityDetailView()) {
                ouraSummaryRow(
                    icon: "flame.fill",
                    iconColor: PulseTheme.activityAccent,
                    title: String(localized: "Activity"),
                    statusLabel: ouraStatusLabel(for: tri.activity.score),
                    statusColor: ouraStatusColor(for: tri.activity.score),
                    score: tri.activity.score
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func ouraSummaryRow(icon: String, iconColor: Color, title: String, statusLabel: String, statusColor: Color, score: Int) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            // Title + score
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                // Mini bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PulseTheme.highlight).frame(height: 3)
                        Capsule()
                            .fill(LinearGradient(colors: [iconColor.opacity(0.6), iconColor], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(score) / 100, height: 3)
                    }
                }
                .frame(height: 3)
                Text("\(score) / 100")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()

            // Status badge
            Text(statusLabel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(statusColor.opacity(0.13)))

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PulseTheme.textQuaternary)
        }
        .padding(.horizontal, PulseTheme.spacingM)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.highlight)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .stroke(PulseTheme.highlight, lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(statusLabel) \(score)")
    }

    private func ouraStatusLabel(for score: Int) -> String {
        switch score {
        case 0..<30: return String(localized: "Poor")
        case 30..<50: return String(localized: "Average")
        case 50..<70: return String(localized: "Fair")
        case 70..<85: return String(localized: "Good")
        default: return String(localized: "Excellent")
        }
    }

    private func ouraStatusColor(for score: Int) -> Color {
        switch score {
        case 0..<40: return PulseTheme.statusPoor
        case 40..<70: return PulseTheme.statusWarning
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
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(String(localized: "Today's Insights"))
                    .pulseEyebrow()
                Spacer()
            }

            // Insight rows
            ForEach(Array(insights.prefix(3).enumerated()), id: \.offset) { idx, text in
                HStack(alignment: .top, spacing: 12) {
                    // Numbered badge
                    ZStack {
                        Circle()
                            .fill(PulseTheme.accentTeal.opacity(0.12))
                            .frame(width: 22, height: 22)
                        Text("\(idx + 1)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.accentTeal)
                    }
                    .padding(.top, 1)

                    Text(text)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(PulseTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                if idx < min(insights.prefix(3).count, 3) - 1 {
                    Divider()
                        .background(PulseTheme.highlight)
                }
            }
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.highlight)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .stroke(PulseTheme.highlight, lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Energy Bank

    /// Computed energy level (0-100) from available health data
    private var energyLevel: Int {
        var total: Double = 0
        var factors: Double = 0

        // Sleep contribution (40% weight) — use readiness score as proxy
        if let score = brief?.score {
            total += Double(score) * 0.4
            factors += 0.4
        }

        // HRV contribution (35% weight) — higher HRV = more energy
        if let hrv = healthManager.latestHRV {
            let hrvScore = min(max((hrv - 15) / (80 - 15), 0), 1) * 100
            total += hrvScore * 0.35
            factors += 0.35
        }

        // Activity contribution (25% weight) — moderate steps = good, extreme = draining
        let steps = healthManager.todaySteps
        if steps > 0 {
            let stepScore: Double
            if steps < 3000 {
                stepScore = Double(steps) / 3000 * 50 // low activity = low-ish
            } else if steps <= 10000 {
                stepScore = 50 + (Double(steps - 3000) / 7000) * 50 // sweet spot
            } else {
                stepScore = max(50, 100 - Double(steps - 10000) / 200) // diminishing
            }
            total += stepScore * 0.25
            factors += 0.25
        }

        guard factors > 0 else {
            // No data — return readiness score or 50
            return brief?.score ?? 50
        }

        return Int(total / factors)
    }

    private var energyRecommendation: (text: String, icon: String) {
        let level = energyLevel
        if level > 70 {
            return (String(localized: "High energy — great day for intensity"), "bolt.fill")
        } else if level >= 40 {
            return (String(localized: "Moderate energy — steady effort recommended"), "gauge.with.dots.needle.50percent")
        } else {
            return (String(localized: "Low energy — focus on recovery today"), "bed.double.fill")
        }
    }

    private var energyBankCard: some View {
        let level = energyLevel
        let rec = energyRecommendation

        return VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: "battery.100.bolt")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(energyColor(for: level).opacity(0.8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Energy Bank"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)

                    Text(String(localized: "Your energy today"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PulseTheme.textTertiary)
                }

                Spacer()

                // Level number
                Text("\(level)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
            }

            // Minimal progress bar — thin, single color
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PulseTheme.highlight)
                        .frame(height: 4)

                    Capsule()
                        .fill(PulseTheme.textTertiary)
                        .frame(width: geo.size.width * CGFloat(level) / 100, height: 4)
                        .animation(.easeOut(duration: 0.3), value: level)
                }
            }
            .frame(height: 4)

            // Recommendation — subdued
            HStack(spacing: 8) {
                Image(systemName: rec.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PulseTheme.textTertiary)

                Text(rec.text)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.highlight)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .stroke(PulseTheme.highlight, lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Energy Bank"))
        .accessibilityValue("\(level), \(rec.text)")
    }

    private func energyColor(for level: Int) -> Color {
        if level > 70 { return PulseTheme.statusGood }
        if level >= 40 { return PulseTheme.statusWarning }
        return PulseTheme.statusPoor
    }

    // MARK: - Nutrition Card (Coming Soon teaser)

    private var nutritionCard: some View {
        NavigationLink(destination: NutritionView()) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PulseTheme.accentSoft)
                        .frame(width: 44, height: 44)

                    Image(systemName: "fork.knife")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(PulseTheme.accent)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(String(localized: "Nutrition Tracking"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)

                        Text(String(localized: "Soon"))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .foregroundStyle(PulseTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(PulseTheme.accentSoft)
                            )
                    }

                    Text(String(localized: "Meals, macros & recovery impact"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(PulseTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .padding(PulseTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.highlight)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                            .stroke(PulseTheme.highlight, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Nutrition Tracking"))
        .accessibilityHint(String(localized: "Coming soon — tap to preview"))
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
    private var currentStressScore: Int {
        healthManager.calculateStressScore()
    }
    private var currentStressColor: Color {
        StressLevel.from(score: currentStressScore).color
    }

    // MARK: - Vitals Strip (HRV + Heart Rate)

    private var vitalsStrip: some View {
        HStack(spacing: 0) {
            // Heart Rate only — HRV already shown in disc row above
            if let hr = currentHeartRate {
                NavigationLink(destination: HeartRateDetailView()) {
                    vitalsCell(
                        icon: "heart.fill",
                        label: String(localized: "Heart Rate"),
                        value: "\(Int(hr))",
                        unit: "bpm",
                        color: PulseTheme.statusPoor,
                        trend: metricStatus(hr, good: 55...70, ok: 50...80)
                    )
                    .padding(PulseTheme.spacingL)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.highlight)
                .shadow(color: PulseTheme.cardShadow, radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
        )
        .padding(.horizontal, PulseTheme.spacingM)
    }

    private func vitalsCell(icon: String, label: String, value: String, unit: String, color: Color, trend: MetricStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: icon + trend badge
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                        .symbolEffect(.pulse, options: .repeating, isActive: icon == "heart.fill")
                }
                Spacer()
                Image(systemName: trend.arrow)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(trend.color)
                    .padding(6)
                    .background(Circle().fill(trend.color.opacity(0.12)))
            }

            // Big number + unit
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            // Label
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PulseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: PulseTheme.spacingM),
            GridItem(.flexible(), spacing: PulseTheme.spacingM),
        ]

        return LazyVGrid(columns: columns, spacing: PulseTheme.spacingM) {
            // 睡眠
            NavigationLink(destination: SleepDetailView()) {
                metricTile(icon: "moon.fill", label: String(localized: "Sleep"), value: currentSleep ?? "--", unit: "", color: PulseTheme.sleepAccent, trend: currentSleep != nil ? .good : .ok, animated: false)
            }
            .buttonStyle(.plain)

            // 步数
            NavigationLink(destination: StepsDetailView()) {
                metricTile(icon: "figure.run", label: String(localized: "Steps"), value: currentSteps > 0 ? formatSteps(currentSteps) : "--", unit: "", color: PulseTheme.accentTeal, trend: currentSteps >= 8000 ? .good : (currentSteps >= 5000 ? .ok : .poor), animated: true)
            }
            .buttonStyle(.plain)

            // 卡路里
            NavigationLink(destination: CaloriesDetailView()) {
                metricTile(icon: "flame.fill", label: String(localized: "Calories"), value: currentCalories > 0 ? "\(Int(currentCalories))" : "--", unit: currentCalories > 0 ? "kcal" : "", color: PulseTheme.activityCoral, trend: currentCalories >= 300 ? .good : .ok, animated: false)
            }
            .buttonStyle(.plain)

            // 血氧
            NavigationLink(destination: BloodOxygenDetailView()) {
                metricTile(icon: "lungs.fill", label: String(localized: "Blood Oxygen"), value: currentBloodOxygen != nil ? "\(Int(currentBloodOxygen!))%" : "--", unit: "", color: PulseTheme.statusGood, trend: (currentBloodOxygen ?? 0) >= 96 ? .good : ((currentBloodOxygen ?? 0) >= 93 ? .ok : .poor), animated: false)
            }
            .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            // Eyebrow label
            Text(label)
                .pulseEyebrow()

            // Metric value + unit
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(PulseTheme.metricMFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if !unit.isEmpty {
                    Text(unit)
                        .font(PulseTheme.unitFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            .opacity(value == "--" ? 0.4 : 1.0)

            // Status dot
            HStack(spacing: 4) {
                Circle()
                    .fill(trend.color)
                    .frame(width: 6, height: 6)
                Image(systemName: trend.arrow)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(trend.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseTheme.spacingM)
        .background(PulseTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.border, lineWidth: PulseTheme.hairline)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(unit.isEmpty ? value : "\(value) \(unit)")
        .accessibilityAddTraits(.isButton)
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
                Text(String(localized: "Training Advice"))
                    .pulseEyebrow()

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
                VStack(spacing: 8) {
                    Text(String(localized: "STRAIN"))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(PulseTheme.textTertiary)
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.border, lineWidth: 5)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0, to: CGFloat(strain) / 100)
                            .stroke(strainColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        Text("\(strain)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
                    Text(strainLevel.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(strainColor)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(PulseTheme.border)
                    .frame(width: 0.5, height: 80)

                // Recovery
                VStack(spacing: 8) {
                    Text(String(localized: "RECOVERY"))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(PulseTheme.textTertiary)
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.border, lineWidth: 5)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0, to: CGFloat(recovery) / 100)
                            .stroke(recoveryColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        Text("\(recovery)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
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
        .padding(PulseTheme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.highlight)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "Strain %d, Recovery %d"), strain, recovery))
    }

    // MARK: - Health Age 卡片

    // MARK: - Health Age Compact (single row)

    private func healthAgeCardCompact(result: HealthAgeService.HealthAgeResult) -> some View {
        let diff = result.difference
        let isYounger = diff < -0.5
        let accentColor = isYounger ? PulseTheme.accentTeal : PulseTheme.activityCoral
        let ageInt = Int(result.healthAge.rounded())
        let diffInt = Int(abs(diff).rounded())

        return HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle().fill(accentColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: "figure.run.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Health Age"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
                Text(String(format: String(localized: "%d yrs"), ageInt))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
            }

            Spacer()

            // Delta badge
            if abs(diff) > 0.5 {
                HStack(spacing: 4) {
                    Image(systemName: isYounger ? "arrow.down" : "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(format: String(localized: "%d yr %@"), diffInt, isYounger ? String(localized: "younger") : String(localized: "older")))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(accentColor.opacity(0.12)))
            }
        }
        .padding(.horizontal, PulseTheme.spacingM)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.highlight)
                .overlay(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .stroke(PulseTheme.highlight, lineWidth: 0.5))
        )
        .accessibilityLabel(String(format: String(localized: "Health Age %d years"), ageInt))
    }

    private func healthAgeCard(result: HealthAgeService.HealthAgeResult) -> some View {
        let diff = result.difference
        let isYounger = diff < -0.5
        let accentColor = isYounger ? PulseTheme.accentTeal : PulseTheme.activityCoral
        let ageInt = Int(result.healthAge.rounded())
        let diffInt = Int(abs(diff).rounded())

        return Button {
            withAnimation(.easeOut(duration: 0.3)) { healthAgeExpanded.toggle() }
        } label: {
            VStack(spacing: 0) {
                // Main row
                HStack(alignment: .center, spacing: 0) {
                    // Left: big age number
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(ageInt)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(String(localized: "Health Age"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }

                    Spacer()

                    // Right: delta + actual age
                    VStack(alignment: .trailing, spacing: 6) {
                        if abs(diff) > 0.5 {
                            HStack(spacing: 5) {
                                Image(systemName: isYounger ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                    .font(.system(size: 13))
                                Text(String(format: "%d yr %@", diffInt,
                                            isYounger ? String(localized: "younger") : String(localized: "older")))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(accentColor.opacity(0.12)))
                        }

                        Text(String(format: String(localized: "Actual: %d · %d day data"), result.chronologicalAge, result.daysOfData))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }

                    Image(systemName: healthAgeExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PulseTheme.textQuaternary)
                        .padding(.leading, 8)
                }
                .padding(PulseTheme.spacingM)

                // Expanded detail
                if healthAgeExpanded {
                    Divider().background(PulseTheme.highlight)
                    VStack(spacing: PulseTheme.spacingS) {
                        ForEach(result.metrics, id: \.metric) { metric in
                            healthAgeMetricRow(metric)
                        }
                    }
                    .padding(PulseTheme.spacingM)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.highlight)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                            .stroke(PulseTheme.highlight, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "Health Age %d"), ageInt))
    }

    private func healthAgeMetricRow(_ metric: HealthAgeService.MetricScore) -> some View {
        let isGood = metric.ageImpact < -0.1
        let isBad = metric.ageImpact > 0.1
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
            Text("\(workout.durationMinutes) min")
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
        default: return String(localized: "\(days)d ago")
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
                    Text(String(localized: "Set Gym Location"))
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)

                    Text(String(localized: "Auto-remind when arriving"))
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

    private var heroLoadingPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(PulseTheme.accent)
                .scaleEffect(1.3)
            Text(String(localized: "Analysing your data…"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PulseTheme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
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
                Analytics.trackScoreViewed()
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
            logger.error("Dashboard load error: \(error)")
        }

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

// MARK: - Apple-style Activity Ring

struct ActivityRingView: View {
    let progress: CGFloat   // 0.0 – 1.0
    let color: Color
    let size: CGFloat

    @State private var animated: CGFloat = 0

    private let lineWidth: CGFloat = 6
    private let shadowBlur: CGFloat = 6

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Progress ring — clockwise from 12 o'clock
            Circle()
                .trim(from: 0, to: min(animated, 1.0))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0.7), color]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: shadowBlur)

            // Cap dot at progress end
            if animated > 0.02 {
                let angle = (animated * 360 - 90) * .pi / 180
                let r = size / 2
                Circle()
                    .fill(color)
                    .frame(width: lineWidth, height: lineWidth)
                    .shadow(color: color.opacity(0.6), radius: 3)
                    .offset(x: r * cos(angle), y: r * sin(angle))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0).delay(0.2)) {
                animated = progress
            }
        }
        .onChange(of: progress) { _, newVal in
            withAnimation(.easeOut(duration: 0.3)) {
                animated = newVal
            }
        }
    }
}
