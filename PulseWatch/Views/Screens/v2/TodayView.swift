import SwiftUI
import SwiftData
import os
#if canImport(UIKit)
import UIKit
#endif

// S01 · Today
//
// Replaces DashboardView.swift + HomeView.swift.
// All functional behavior preserved (R11). UI strictly DS tokens + Phase 2 primitives.

struct TodayView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "TodayView")

    @AppStorage("pulse.demo.enabled") private var demoMode = false

    private let healthManager = HealthKitManager.shared
    private let connectivityManager = WatchConnectivityManager.shared

    // MARK: - State

    @State private var isLoading = true
    @State private var brief: ScoreEngine.DailyBrief?
    @State private var insight: HealthInsight?
    @State private var todayStrain: Int = 0
    @State private var triScore: TriScoreService.TriScore?
    @State private var healthAgeResult: HealthAgeService.HealthAgeResult?
    @State private var demoTimelineEvents: [TimelineEvent] = []

    @State private var showLocationSetup = false
    @State private var showGymPrompt = false
    @State private var showShareSnapshot = false

    @Query(sort: \WorkoutRecord.date, order: .reverse) private var recentWorkouts: [WorkoutRecord]
    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @Query private var savedLocations: [SavedLocation]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DS.Color.bg.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.group) {
                        if demoMode {
                            demoBanner
                        }

                        navHeader

                        heroBlock

                        vitalsBlock

                        sleepBlock

                        trainBlock

                        scoreChartBlock

                        timelineBlock

                        healthAgeBlock

                        recentWorkoutsBlock

                        goalBlock

                        energyBlock

                        gymSetupBlock

                        Spacer(minLength: DS.Spacing.xl)
                    }
                    .padding(.horizontal, DS.Spacing.edge)
                    .padding(.top, DS.Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLocationSetup) {
                LocationSetupView()
            }
            .sheet(isPresented: $showShareSnapshot) {
                HealthSnapshotShareScreen()
            }
            .fullScreenCover(isPresented: $showGymPrompt) {
                GymArrivalFlowView(
                    readinessScore: insight?.recoveryScore ?? brief?.score ?? 50,
                    strainScore: todayStrain
                )
            }
            .task { await loadData() }
            .refreshable { await loadData() }
            .onReceive(NotificationCenter.default.publisher(for: .didEnterSavedRegion)) { note in
                handleGeofenceEntry(note)
            }
        }
    }

    // MARK: - Demo banner

    private var demoBanner: some View {
        HStack {
            Chip(text: "Demo Data", style: .neutral)
            Spacer()
        }
    }

    // MARK: - NAV header

    private var navHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            MonoLabel(text: navDateLabel, size: .m)
            Spacer()
            Menu {
                Button {
                    showShareSnapshot = true
                } label: {
                    Label(String(localized: "Share Snapshot"), systemImage: "square.and.arrow.up")
                }
                Button {
                    showLocationSetup = true
                } label: {
                    Label(String(localized: "Set Gym Location"), systemImage: "mappin.and.ellipse")
                }
            } label: {
                MonoLabel(text: "More", size: .m, tone: .accent)
            }
        }
        .padding(.bottom, DS.Spacing.s)
    }

    private var navDateLabel: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = isChinese ? "M月d日 EEEE" : "EEE · MMM d"
        return String(localized: "Today") + " · " + f.string(from: .now)
    }

    // MARK: - Hero block

    @ViewBuilder
    private var heroBlock: some View {
        if let brief {
            HeroScore(
                score: brief.score,
                status: statusLabel(for: brief.score),
                insightText: coachAction(for: brief.score),
                insightLabel: String(localized: "Today's coach"),
                trendData: trendDataForHero(),
                trendLabel: String(localized: "30d Trend"),
                dateLabel: String(localized: "Readiness")
            )
            confidenceFooter
        } else if isLoading {
            loadingHero
        } else if !healthManager.hasHealthData && !demoMode {
            healthKitPermissionCard
        } else {
            emptyHero
        }
    }

    private func trendDataForHero() -> [Double] {
        sevenDayAllScores().compactMap { $0.map(Double.init) }
    }

    private var loadingHero: some View {
        Card {
            VStack(spacing: DS.Spacing.m) {
                MonoLabel(text: "Loading…", size: .m, tone: .dim)
                    .padding(.vertical, DS.Spacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var emptyHero: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                MonoLabel(text: "Awaiting Data · 0/4 vitals", size: .m, tone: .dim)
                Text(String(localized: "Wear your Apple Watch and Pulse will start showing today's readiness."))
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.inkMid)
            }
        }
    }

    private var healthKitPermissionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                MonoLabel(text: "Health Access Required", size: .m)
                Text(String(localized: "Pulse Watch reads HRV, sleep, and resting heart rate to compute your daily readiness score. Data stays on this device."))
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.inkMid)
                Button {
                    openAppSettings()
                } label: {
                    HStack {
                        Spacer()
                        Text(String(localized: "Open Settings"))
                            .font(DS.Typography.bodyL)
                            .foregroundStyle(DS.Color.accentInk)
                        Spacer()
                    }
                    .padding(.vertical, DS.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                            .fill(DS.Color.accent)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var confidenceFooter: some View {
        let chipsCount = currentDataChips().count
        let label: String
        switch chipsCount {
        case 3...:  label = String(localized: "Apple Watch · data complete")
        case 1...2: label = String(localized: "Apple Watch · partial")
        default:    label = String(localized: "Apple Watch · awaiting data")
        }
        return HStack {
            MonoLabel(text: label, size: .s, tone: .dim)
            Spacer()
        }
    }

    // MARK: - Vitals block

    @ViewBuilder
    private var vitalsBlock: some View {
        if hasAnyMetric {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                SectionHead(num: "01", title: String(localized: "Vitals"), sub: String(localized: "6 metrics"))
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: DS.Spacing.s),
                    GridItem(.flexible(), spacing: DS.Spacing.s)
                ], spacing: DS.Spacing.s) {
                    NavigationLink { HRVDetailView() } label: { hrvVitalChip }
                        .buttonStyle(.plain)
                    NavigationLink { HeartRateDetailView() } label: { rhrVitalChip }
                        .buttonStyle(.plain)
                    NavigationLink { SleepDetailView() } label: { sleepVitalChip }
                        .buttonStyle(.plain)
                    NavigationLink { BloodOxygenDetailView() } label: { spo2VitalChip }
                        .buttonStyle(.plain)
                    NavigationLink { StressDetailView() } label: { stressVitalChip }
                        .buttonStyle(.plain)
                    if let result = healthAgeResult {
                        NavigationLink { HealthAgeDetailView(result: result) } label: { healthAgeVitalChip(result: result) }
                            .buttonStyle(.plain)
                    } else {
                        healthAgeVitalChipEmpty
                    }
                }
            }
        }
    }

    private var hrvVitalChip: some View {
        let v = healthManager.latestHRV
        return VitalChip(
            label: "HRV",
            value: v.map { String(Int($0)) } ?? "—",
            unit: v != nil ? "ms" : nil,
            trend: hrvTrend,
            polarity: .higherIsBetter,
            sub: hrvSub
        )
    }

    private var rhrVitalChip: some View {
        let v = healthManager.latestRestingHR
        return VitalChip(
            label: "RHR",
            value: v.map { String(Int($0)) } ?? "—",
            unit: v != nil ? "bpm" : nil,
            trend: rhrTrend,
            polarity: .lowerIsBetter,
            sub: rhrSub
        )
    }

    private var sleepVitalChip: some View {
        let mins = healthManager.lastNightSleepMinutes
        let hours = Double(mins) / 60.0
        return VitalChip(
            label: String(localized: "Sleep"),
            value: mins > 0 ? String(format: "%.1f", hours) : "—",
            unit: mins > 0 ? "h" : nil,
            trend: .flat,
            polarity: .higherIsBetter,
            sub: mins > 0 ? sleepStageSub() : nil
        )
    }

    private var spo2VitalChip: some View {
        let v = healthManager.latestBloodOxygen
        return VitalChip(
            label: "SpO₂",
            value: v.map { String(format: "%.0f", $0 * 100) } ?? "—",
            unit: v != nil ? "%" : nil,
            trend: .flat,
            polarity: .contextual,
            trendColor: spo2Color(v),
            sub: nil
        )
    }

    private var stressVitalChip: some View {
        let s = currentStressScore
        let mode = StressLevel.from(score: s)
        return VitalChip(
            label: String(localized: "Stress"),
            value: "\(s)",
            unit: nil,
            trend: stressTrend(score: s),
            polarity: .lowerIsBetter,
            sub: mode.label
        )
    }

    private func healthAgeVitalChip(result: HealthAgeService.HealthAgeResult) -> some View {
        let delta = Int(result.difference.rounded())
        let deltaText: String
        if delta == 0 {
            deltaText = String(localized: "= actual")
        } else if delta < 0 {
            deltaText = "\(delta) " + String(localized: "vs actual")
        } else {
            deltaText = "+\(delta) " + String(localized: "vs actual")
        }
        return VitalChip(
            label: String(localized: "Health Age"),
            value: "\(Int(result.healthAge.rounded()))",
            unit: "y",
            trend: result.difference < 0 ? .down : (result.difference > 0 ? .up : .flat),
            polarity: .lowerIsBetter,
            sub: deltaText
        )
    }

    private var healthAgeVitalChipEmpty: some View {
        VitalChip(
            label: String(localized: "Health Age"),
            value: "—",
            trend: .flat,
            polarity: .lowerIsBetter,
            sub: String(localized: "computing…")
        )
    }

    // MARK: - Sleep block

    @ViewBuilder
    private var sleepBlock: some View {
        if healthManager.lastNightSleepMinutes > 0 {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                SectionHead(
                    num: "02",
                    title: String(localized: "Sleep"),
                    sub: sleepDurationLabel
                )
                NavigationLink { SleepDetailView() } label: {
                    Card {
                        SleepBand(stages: sleepStages)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sleepStages: [SleepStage] {
        let total = healthManager.lastNightSleepMinutes
        let deep = healthManager.lastNightDeepSleepMinutes
        let rem = healthManager.lastNightREMSleepMinutes
        let core = max(0, total - deep - rem)
        return [
            SleepStage(stage: .core, mins: core),
            SleepStage(stage: .rem, mins: rem),
            SleepStage(stage: .deep, mins: deep)
        ]
    }

    private var sleepDurationLabel: String {
        let m = healthManager.lastNightSleepMinutes
        let h = m / 60
        let r = m % 60
        if isChinese {
            return "\(h)小时\(r)分"
        }
        return "\(h)H \(r)M"
    }

    private func sleepStageSub() -> String {
        let deep = healthManager.lastNightDeepSleepMinutes
        let rem = healthManager.lastNightREMSleepMinutes
        return String(format: String(localized: "Deep %dm · REM %dm"), deep, rem)
    }

    // MARK: - Train block

    @ViewBuilder
    private var trainBlock: some View {
        if let plan = brief?.trainingPlan, plan.targetMuscleGroup != "rest" {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                SectionHead(
                    num: "03",
                    title: String(localized: "Train"),
                    sub: String(localized: "Suggested"),
                    action: String(localized: "Start")
                )
                Card {
                    VStack(alignment: .leading, spacing: DS.Spacing.m) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(workoutTitle(for: plan))
                                .font(DS.Typography.title2)
                                .foregroundStyle(DS.Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: DS.Spacing.s)
                            Chip(
                                text: plan.intensity.rawValue,
                                style: chipStyle(for: plan.intensity)
                            )
                        }
                        if !plan.reason.isEmpty {
                            Text(plan.reason)
                                .font(DS.Typography.bodyS)
                                .foregroundStyle(DS.Color.inkMid)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(plan.suggestedExercises.enumerated()), id: \.offset) { index, ex in
                            if index > 0 {
                                Rectangle()
                                    .fill(DS.Color.lineSoft)
                                    .frame(height: DS.Stroke.hairline)
                            }
                            exerciseRow(ex)
                        }
                    }
                }
            }
        }
    }

    private func exerciseRow(_ ex: SuggestedExercise) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(ex.name)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.ink)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                MonoLabel(text: "\(ex.sets) × \(ex.reps)", size: .s)
                if let w = ex.suggestedWeight {
                    MonoLabel(text: String(format: "%.0f kg", w), size: .s, tone: .dim)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func chipStyle(for intensity: TrainingPlan.Intensity) -> ChipStyle {
        switch intensity {
        case .light:    return .good
        case .moderate: return .accent
        case .heavy:    return .warn
        }
    }

    // MARK: - Score chart block

    private var scoreChartBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHead(
                num: "04",
                title: String(localized: "Score"),
                sub: String(localized: "30 days")
            )
            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    HStack {
                        MonoLabel(text: scoreChartHeader, size: .s, tone: .dim)
                        Spacer()
                    }
                    ScoreChart(data: scoreChartData)
                }
            }
        }
    }

    private var scoreChartData: [(day: Date, value: Int)] {
        let sorted = allSummaries.sorted(by: { $0.date < $1.date })
        let last30 = Array(sorted.suffix(30))
        var entries: [(day: Date, value: Int)] = last30.compactMap { s in
            guard let v = s.dailyScore else { return nil }
            return (day: s.date, value: v)
        }
        if let todayScore = brief?.score {
            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            if let lastEntry = entries.last,
               !cal.isDate(lastEntry.day, inSameDayAs: today) {
                entries.append((day: today, value: todayScore))
            }
        }
        return entries
    }

    private var scoreChartHeader: String {
        let values = scoreChartData.map { Double($0.value) }
        guard !values.isEmpty else { return String(localized: "Awaiting Data") }
        let mean = values.reduce(0, +) / Double(values.count)
        let varSum = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        let std = sqrt(varSum / Double(values.count))
        return String(format: String(localized: "Avg %.0f · σ %.1f"), mean, std)
    }

    // MARK: - Timeline block

    private var timelineBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHead(
                num: "05",
                title: String(localized: "Today"),
                sub: String(localized: "Timeline")
            )
            Card {
                EventTimeline(events: timelineEvents)
            }
        }
    }

    private var timelineEvents: [EventEntry] {
        if demoMode {
            return demoTimelineEvents.map { e in
                EventEntry(
                    time: timeStr(e.time),
                    title: e.title,
                    detail: e.detail,
                    impact: timelineImpact(e.impact),
                    isCurrent: e.isCurrent
                )
            }
        }
        return realTimelineEvents()
    }

    private func realTimelineEvents() -> [EventEntry] {
        var out: [EventEntry] = []
        if let wake = healthManager.lastNightSleepEnd {
            let rhr = healthManager.latestRestingHR.map { Int($0) }
            let detail = rhr.map { String(format: String(localized: "RHR %d — well rested."), $0) }
                ?? String(localized: "Sleep complete.")
            out.append(EventEntry(
                time: timeStr(wake),
                title: String(localized: "Wake"),
                detail: detail,
                impact: .positive
            ))
        }
        if let hrv = healthManager.latestHRV, hrv > 0 {
            out.append(EventEntry(
                time: timeStr(.now),
                title: String(localized: "Current HRV"),
                detail: String(format: String(localized: "%d ms — within your normal range."), Int(hrv)),
                impact: .neutral,
                isCurrent: true
            ))
        }
        if let i = insight {
            out.append(EventEntry(
                time: timeStr(.now),
                title: String(localized: "Insight"),
                detail: i.insights.first ?? "—",
                impact: timelineImpact(from: i)
            ))
        }
        return out
    }

    private func timelineImpact(_ s: String) -> TimelineImpact {
        switch s.lowercased() {
        case "positive", "good": return .positive
        case "negative", "bad":  return .negative
        default:                 return .neutral
        }
    }

    private func timelineImpact(from insight: HealthInsight) -> TimelineImpact {
        if insight.recoveryScore >= 70 { return .positive }
        if insight.recoveryScore < 40 { return .negative }
        return .neutral
    }

    private func timeStr(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    // MARK: - Health Age block

    @ViewBuilder
    private var healthAgeBlock: some View {
        if let result = healthAgeResult {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                SectionHead(
                    num: "06",
                    title: String(localized: "Health Age"),
                    sub: result.difference < 0 ? String(localized: "Younger") : (result.difference > 0 ? String(localized: "Older") : String(localized: "On par"))
                )
                NavigationLink { HealthAgeDetailView(result: result) } label: {
                    Card {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.m) {
                            BigNum(value: "\(Int(result.healthAge.rounded()))", unit: "y", size: .display3)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                MonoLabel(
                                    text: deltaLabel(result.difference),
                                    size: .s,
                                    tone: result.difference < 0 ? .good : (result.difference > 0 ? .warn : .dim)
                                )
                                MonoLabel(text: String(format: String(localized: "Actual age %d"), result.chronologicalAge), size: .s, tone: .dim)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func deltaLabel(_ delta: Double) -> String {
        let i = Int(delta.rounded())
        if i == 0 { return String(localized: "= actual") }
        return i < 0 ? "\(i)y vs actual" : "+\(i)y vs actual"
    }

    // MARK: - Recent workouts block

    @ViewBuilder
    private var recentWorkoutsBlock: some View {
        if !recentWorkouts.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                SectionHead(
                    num: "07",
                    title: String(localized: "Recent"),
                    sub: String(localized: "Workouts")
                )
                Card {
                    VStack(spacing: 0) {
                        let top3 = Array(recentWorkouts.prefix(3))
                        ForEach(Array(top3.enumerated()), id: \.element.id) { idx, w in
                            if idx > 0 {
                                Rectangle()
                                    .fill(DS.Color.lineSoft)
                                    .frame(height: DS.Stroke.hairline)
                            }
                            workoutRow(w)
                        }
                    }
                }
            }
        }
    }

    private func workoutRow(_ w: WorkoutRecord) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutCategoryName(w.category))
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.ink)
                MonoLabel(text: relativeDate(w.date), size: .s, tone: .dim)
            }
            Spacer()
            MonoLabel(text: workoutDuration(w), size: .s)
        }
        .padding(.vertical, DS.Spacing.s)
    }

    private func workoutDuration(_ w: WorkoutRecord) -> String {
        return "\(w.durationMinutes)M"
    }

    // MARK: - Goal block

    private var goalBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHead(
                num: "08",
                title: String(localized: "Goals"),
                sub: String(localized: "Today")
            )
            GoalProgressCard()
        }
    }

    // MARK: - Energy block

    private var energyBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHead(
                num: "09",
                title: String(localized: "Energy"),
                sub: String(localized: "Capacity")
            )
            Card {
                VStack(alignment: .leading, spacing: DS.Spacing.m) {
                    HStack(alignment: .firstTextBaseline) {
                        BigNum(value: "\(energyLevel)", unit: "%", size: .display3)
                        Spacer()
                        Chip(text: energyLevelLabel, style: energyChipStyle)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DS.Color.lineSoft)
                                .frame(height: 4)
                            Capsule()
                                .fill(DS.Color.accent)
                                .frame(width: geo.size.width * CGFloat(energyLevel) / 100, height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text(energyRecommendation)
                        .font(DS.Typography.bodyS)
                        .foregroundStyle(DS.Color.inkMid)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var energyLevel: Int {
        let recovery = Double(brief?.score ?? 0) / 100.0 * 0.4
        let hrvRaw = healthManager.latestHRV ?? 0
        let hrvScore = max(0.0, min(1.0, (hrvRaw - 15) / (80 - 15))) * 0.35
        let steps = healthManager.todaySteps
        let stepScore: Double
        if steps < 3000 { stepScore = Double(steps) / 3000 * 0.5 }
        else if steps < 10000 { stepScore = 0.5 + Double(steps - 3000) / 7000 * 0.5 }
        else { stepScore = max(0.6, 1.0 - Double(steps - 10000) / 20000) }
        let activity = stepScore * 0.25
        let composite = recovery + hrvScore + activity
        let pct = Int(composite * 100)
        if pct == 0 { return brief?.score ?? 50 }
        return min(100, max(0, pct))
    }

    private var energyLevelLabel: String {
        let l = energyLevel
        if l > 70 { return String(localized: "High") }
        if l > 40 { return String(localized: "Moderate") }
        return String(localized: "Low")
    }

    private var energyChipStyle: ChipStyle {
        let l = energyLevel
        if l > 70 { return .good }
        if l > 40 { return .accent }
        return .warn
    }

    private var energyRecommendation: String {
        let l = energyLevel
        if l > 70 { return String(localized: "High energy — great day for intensity.") }
        if l > 40 { return String(localized: "Moderate energy — steady effort recommended.") }
        return String(localized: "Low energy — focus on recovery today.")
    }

    // MARK: - Gym setup block

    @ViewBuilder
    private var gymSetupBlock: some View {
        if !hasGymLocation {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                SectionHead(
                    num: "10",
                    title: String(localized: "Setup"),
                    sub: String(localized: "Gym Location")
                )
                Button {
                    showLocationSetup = true
                } label: {
                    Card {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Set Gym Location"))
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Color.ink)
                                Text(String(localized: "Auto-remind on arrival"))
                                    .font(DS.Typography.bodyS)
                                    .foregroundStyle(DS.Color.inkMid)
                            }
                            Spacer()
                            MonoLabel(text: "→", size: .m, tone: .accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Status / labels

    private func statusLabel(for score: Int) -> String {
        switch score {
        case 0..<30:  return String(localized: "Rest")
        case 30..<50: return String(localized: "Average")
        case 50..<70: return String(localized: "Fair")
        case 70..<85: return String(localized: "Good")
        default:      return String(localized: "Peak")
        }
    }

    private func coachAction(for score: Int) -> String {
        switch score {
        case 85...100: return String(localized: "Train hard. HIIT or heavy lift today.")
        case 70..<85:  return String(localized: "Train steady. Moderate intensity, no max effort.")
        case 50..<70:  return String(localized: "Cruise. Zone 2 cardio 30 min.")
        case 30..<50:  return String(localized: "Move light. Walk or stretch only.")
        default:       return String(localized: "Recover. Sleep + hydrate.")
        }
    }

    // MARK: - Trends

    private var hrvTrend: TrendDirection {
        guard let baseline = sevenDayBaselineHRV(),
              let latest = healthManager.latestHRV else { return .flat }
        if latest > baseline + 3 { return .up }
        if latest < baseline - 3 { return .down }
        return .flat
    }

    private var hrvSub: String? {
        guard let baseline = sevenDayBaselineHRV(),
              let latest = healthManager.latestHRV else { return nil }
        let diff = Int((latest - baseline).rounded())
        return diff == 0 ? nil : (diff > 0 ? "+\(diff) vs 7d" : "\(diff) vs 7d")
    }

    private var rhrTrend: TrendDirection {
        guard let latest = healthManager.latestRestingHR else { return .flat }
        if latest > 70 { return .up }
        if latest < 55 { return .down }
        return .flat
    }

    private var rhrSub: String? {
        guard let latest = healthManager.latestRestingHR else { return nil }
        if latest >= 70 { return String(localized: "elevated") }
        if latest <= 55 { return String(localized: "low resting") }
        return String(localized: "normal")
    }

    private func sevenDayBaselineHRV() -> Double? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let prior = (1...6).compactMap { offset -> Double? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return allSummaries.first { cal.isDate($0.date, inSameDayAs: d) }?.averageHRV
        }
        guard !prior.isEmpty else { return nil }
        return prior.reduce(0, +) / Double(prior.count)
    }

    private func spo2Color(_ v: Double?) -> Color {
        guard let v else { return DS.Color.inkDim }
        if v < 0.92 { return DS.Color.bad }
        if v < 0.95 { return DS.Color.warn }
        return DS.Color.good
    }

    private var currentStressScore: Int {
        healthManager.calculateStressScore()
    }

    private func stressTrend(score: Int) -> TrendDirection {
        if score >= 70 { return .up }
        if score <= 30 { return .down }
        return .flat
    }

    private var hasAnyMetric: Bool {
        healthManager.latestHeartRate != nil ||
        healthManager.latestHRV != nil ||
        healthManager.latestRestingHR != nil ||
        healthManager.latestBloodOxygen != nil ||
        healthManager.lastNightSleepMinutes > 0 ||
        healthManager.todaySteps > 0
    }

    private var hasGymLocation: Bool {
        savedLocations.contains { $0.locationType == "gym" && $0.isActive }
    }

    private var isChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }

    private func currentDataChips() -> [String] {
        var chips: [String] = []
        let m = healthManager.lastNightSleepMinutes
        if m > 0 { chips.append(String(format: "Sleep %.1fh", Double(m) / 60.0)) }
        if let r = healthManager.latestRestingHR, r > 0 { chips.append("RHR \(Int(r))") }
        if let h = healthManager.latestHRV, h > 0 { chips.append("HRV \(Int(h))ms") }
        return chips
    }

    private func sevenDayPriorScores() -> [Int?] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (1...6).reversed().map { offset -> Int? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return allSummaries.first { cal.isDate($0.date, inSameDayAs: d) }?.dailyScore ?? nil
        }
    }

    private func sevenDayAllScores() -> [Int?] {
        sevenDayPriorScores() + [brief?.score]
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

    private func workoutCategoryName(_ category: String) -> String {
        switch category.lowercased() {
        case "chest":     return String(localized: "Chest")
        case "back":      return String(localized: "Back")
        case "legs":      return String(localized: "Legs")
        case "shoulders": return String(localized: "Shoulders")
        case "arms":      return String(localized: "Arms")
        case "cardio":    return String(localized: "Cardio")
        default:          return category.capitalized
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        let now = Date.now
        let startToday = cal.startOfDay(for: now)
        let startDate = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startDate, to: startToday).day ?? 0
        switch days {
        case 0:  return String(localized: "Today")
        case 1:  return String(localized: "Yesterday")
        default: return String(localized: "\(days)d ago")
        }
    }

    // MARK: - Data load

    private func loadData() async {
        isLoading = true

        #if DEBUG
        if demoMode {
            brief = DemoDataProvider.makeBrief()
            insight = DemoDataProvider.makeInsight()
            demoTimelineEvents = DemoDataProvider.makeTimelineEvents()
            todayStrain = StrainScoreService.demoStrain
            healthAgeResult = HealthAgeService.demoResult
            triScore = TriScoreService.demoTriScore
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

            if brief != nil { Analytics.trackScoreViewed() }
            ReviewRequestManager.shared.syncWorkoutCount(recentWorkouts.count)

            insight = await MainActor.run {
                HealthAnalyzer.shared.generateInsight()
            }

            if let brief {
                connectivityManager.sendHealthSummary(
                    score: brief.score,
                    headline: brief.headline,
                    insight: brief.insight,
                    heartRate: Int(healthManager.latestHeartRate ?? 0),
                    steps: healthManager.todaySteps
                )
            }
        } catch {
            logger.error("TodayView load error: \(error)")
        }

        todayStrain = StrainScoreService.shared.todayStrain(modelContext: modelContext)
        healthAgeResult = HealthAgeService.shared.compute(modelContext: modelContext)
        triScore = TriScoreService.shared.compute(modelContext: modelContext)

        isLoading = false
    }

    // MARK: - Geofence

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

    // MARK: - Helpers

    private func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

#Preview {
    TodayView()
}
