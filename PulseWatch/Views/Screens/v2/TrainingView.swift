import SwiftUI
import SwiftData
import HealthKit
import os

/// Tab: Workout — Clinical v2 layout matching Workout.jsx
/// Header (eyebrow + 32pt title)
/// → Week summary card (3-up + 7-day strip)
/// → Last session card (HR zones bar)
/// → History card (hairline-separated rows)
/// → "MORE FROM PULSE" divider
/// → Strength + AI/OpenClaw sections
struct TrainingView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "TrainingView")

    @State private var workouts: [HKWorkout] = []
    @State private var heartRateZones: [UUID: [HeartRateZone]] = [:]
    @State private var lastSessionZoneMinutes: [Int] = []
    @State private var isLoading = true
    @State private var weekStats: WeekWorkoutStats?
    @State private var showAddStrength = false
    @State private var weekDayActivity: [Bool] = Array(repeating: false, count: 7)

    @Query(sort: \StrengthRecord.date, order: .reverse) private var strengthRecords: [StrengthRecord]
    @Query(sort: \WorkoutHistoryEntry.startDate, order: .reverse) private var allHistoryEntries: [WorkoutHistoryEntry]
    @AppStorage("pulse.user.weightKg") private var bodyweight: Double = 0

    /// 最近 7 天的 OpenClaw AI 训练记录
    private var recentAIWorkouts: [WorkoutHistoryEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return allHistoryEntries.filter { $0.sourceName == "OpenClaw" && $0.startDate >= cutoff }
    }

    private let store = HKHealthStore()

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Clinical header (eyebrow + 32pt title + History action)
                    clinicalHeader
                        .padding(.horizontal, DS.Spacing.l)
                        .padding(.top, DS.Spacing.m)
                        .padding(.bottom, DS.Spacing.s)

                    // ── JSX-aligned cards
                    VStack(spacing: 12) {
                        weekSummaryCard
                            .staggered(index: 0)

                        if let workout = workouts.first {
                            lastSessionCard(workout)
                                .staggered(index: 1)
                        } else if isLoading {
                            loadingPlaceholder
                                .staggered(index: 1)
                        }

                        historyCard
                            .staggered(index: 2)
                    }
                    .padding(.horizontal, DS.Spacing.m)

                    // ── "MORE FROM PULSE" divider
                    moreFromPulseDivider
                        .padding(.horizontal, DS.Spacing.m)
                        .padding(.top, DS.Spacing.m)
                        .padding(.bottom, DS.Spacing.m)

                    // ── Pulse-only extras
                    VStack(spacing: DS.Spacing.m) {
                        strengthSection
                            .staggered(index: 3)

                        if !recentAIWorkouts.isEmpty {
                            aiWorkoutsSection
                                .staggered(index: 4)
                        }

                        if workouts.isEmpty && !isLoading {
                            emptyState
                                .staggered(index: 5)
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, DS.Spacing.m)
                }
            }
            .background(DS.Color.bg)
            .navigationBarHidden(true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await loadWorkouts()
            }
            .refreshable {
                await loadWorkouts()
            }
            .sheet(isPresented: $showAddStrength) {
                AddStrengthRecordView()
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Clinical header (mirrors Workout.jsx header)

    private var clinicalHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerEyebrowText)
                    .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
                Text(String(localized: "Workout"))
                    .font(DS.Typography.title1.weight(.bold))
                    .foregroundStyle(DS.Color.ink)
                    .tracking(-0.5)
            }
            Spacer()
            NavigationLink {
                WorkoutHistoryListView()
                    .preferredColorScheme(.dark)
            } label: {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Color.inkMid)
                    .padding(DS.Spacing.s)
                    .accessibilityLabel(String(localized: "History"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerEyebrowText: String {
        let count = weekStats?.totalCount ?? 0
        if count > 0 {
            return String(format: String(localized: "This week · %d sessions"), count)
        }
        return String(localized: "Last 7 days")
    }

    // MARK: - "MORE FROM PULSE" divider (matches HistoryView pattern)

    private var moreFromPulseDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(DS.Color.lineSoft)
                .frame(height: DS.Stroke.hairline)
                .frame(maxWidth: .infinity)
            Text(String(localized: "More from Pulse"))
                .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
            Rectangle()
                .fill(DS.Color.lineSoft)
                .frame(height: DS.Stroke.hairline)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Week summary card

    private var weekSummaryCard: some View {
        VStack(spacing: 0) {
            // Top row: eyebrow + week range mono
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "This Week"))
                    .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
                Spacer()
                Text(weekRangeText)
                    .font(DS.Typography.mono)
                    .foregroundStyle(DS.Color.inkDim)
            }

            // 3-up metric grid
            HStack(spacing: 12) {
                summaryMetric(
                    primary: "\(weekStats?.totalCount ?? 0)",
                    primarySuffix: " /\(weeklySessionGoal)",
                    label: String(localized: "Sessions")
                )
                summaryMetric(
                    primary: durationPrimary,
                    primarySuffix: durationSuffix,
                    label: String(localized: "Total time")
                )
                summaryMetric(
                    primary: kcalPrimary,
                    primarySuffix: "",
                    label: String(localized: "kcal")
                )
            }
            .padding(.top, DS.Spacing.card)

            // Week dot matrix — M T W T F S S
            weekDayStrip
                .padding(.top, DS.Spacing.l)
        }
        .dsCard(padding: DS.Spacing.l)
    }

    private func summaryMetric(primary: String, primarySuffix: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(primary)
                    .font(DS.Typography.title1.weight(.semibold).monospacedDigit())
                    .foregroundStyle(DS.Color.ink)
                if !primarySuffix.isEmpty {
                    Text(primarySuffix)
                        .font(DS.Typography.bodyS.monospacedDigit())
                        .foregroundStyle(DS.Color.inkDim)
                }
            }
            Text(label)
                .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekDayStrip: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let trained = weekDayActivity.indices.contains(i) ? weekDayActivity[i] : false
                VStack(spacing: 6) {
                    Text(weekdayLabel(i))
                        .font(DS.Typography.mono.weight(.semibold))
                        .foregroundStyle(DS.Color.inkDim)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(trained ? DS.Color.ink : Color.clear)
                        .frame(width: DS.Spacing.xl - DS.Spacing.xs, height: DS.Spacing.xl - DS.Spacing.xs)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(trained ? Color.clear : DS.Color.line, lineWidth: DS.Stroke.hairline)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayLabel(_ index: Int) -> String {
        // index 0 = Monday
        ["M", "T", "W", "T", "F", "S", "S"][index]
    }

    private var weekRangeText: String {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysSinceMonday, to: cal.startOfDay(for: now)),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else {
            return ""
        }
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "MMM d"
        return "\(f.string(from: monday)) – \(f.string(from: sunday))"
    }

    private var weeklySessionGoal: Int {
        // Default goal: 6 sessions/week. Could be wired to HealthGoal later.
        6
    }

    private var durationPrimary: String {
        guard let mins = weekStats?.totalMinutes, mins > 0 else { return "—" }
        if mins >= 60 {
            return "\(mins / 60)h"
        }
        return "\(mins)m"
    }

    private var durationSuffix: String {
        guard let mins = weekStats?.totalMinutes, mins >= 60 else { return "" }
        let rem = mins % 60
        return rem > 0 ? " \(String(format: "%02d", rem))m" : ""
    }

    private var kcalPrimary: String {
        guard let cal = weekStats?.totalCalories, cal > 0 else { return "—" }
        let int = Int(cal)
        if int >= 1000 {
            // 1,238 style
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = ","
            return f.string(from: NSNumber(value: int)) ?? "\(int)"
        }
        return "\(int)"
    }

    // MARK: - Last session card

    private func lastSessionCard(_ workout: HKWorkout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Last Session"))
                        .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
                    Text(workoutName(workout))
                        .font(DS.Typography.bodyL.weight(.semibold))
                        .foregroundStyle(DS.Color.ink)
                        .padding(.top, DS.Spacing.xs)
                    Text(lastSessionMetaText(workout))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.inkDim)
                        .padding(.top, DS.Spacing.m)
                }
                Spacer()
                Text(String(localized: "Logged"))
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Color.inkMid)
                    .padding(.horizontal, DS.Spacing.s)
                    .padding(.vertical, DS.Spacing.xs)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
                    )
            }

            // HR zones bar
            heartRateZonesView
                .padding(.top, DS.Spacing.m)
        }
        .dsCard(padding: DS.Spacing.l)
    }

    private var heartRateZonesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Heart Rate Zones"))
                .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)

            // Stacked horizontal bar
            zoneBar
                .padding(.top, DS.Spacing.m)

            // Z1 2m  Z2 6m  Z3 26m...
            zoneLegend
                .padding(.top, DS.Spacing.xs)
        }
    }

    private var zoneBar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if zoneTotalMinutes > 0 {
                    ForEach(0..<5, id: \.self) { i in
                        let mins = lastSessionZoneMinutes.indices.contains(i) ? lastSessionZoneMinutes[i] : 0
                        let frac = Double(mins) / Double(zoneTotalMinutes)
                        Rectangle()
                            .fill(zoneColor(forIndex: i, mins: mins))
                            .frame(width: max(0, geo.size.width * frac))
                    }
                } else {
                    // Empty / skeleton bar
                    Rectangle().fill(DS.Color.lineSoft)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(height: 8)
    }

    private var zoneTotalMinutes: Int {
        lastSessionZoneMinutes.reduce(0, +)
    }

    private func zoneColor(forIndex idx: Int, mins: Int) -> Color {
        if mins == 0 { return DS.Color.lineSoft }
        // Highlight the dominant zone with textPrimary; others are tonal greys.
        let maxIdx = lastSessionZoneMinutes.firstIndex(of: lastSessionZoneMinutes.max() ?? 0) ?? -1
        if idx == maxIdx {
            return DS.Color.ink
        }
        // Secondary tones
        switch idx {
        case 0: return DS.Color.inkDim
        case 1: return DS.Color.inkDim
        case 3: return DS.Color.inkMid
        case 4: return DS.Color.inkDim
        default: return DS.Color.inkDim
        }
    }

    private var zoneLegend: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                let mins = lastSessionZoneMinutes.indices.contains(i) ? lastSessionZoneMinutes[i] : 0
                let isDominant = mins > 0 && mins == lastSessionZoneMinutes.max()
                HStack(spacing: 3) {
                    Text("Z\(i + 1)")
                        .font(DS.Typography.mono)
                    Text(mins > 0 ? "\(mins)m" : "—")
                        .font(DS.Typography.mono)
                }
                .foregroundStyle(isDominant ? DS.Color.ink : DS.Color.inkDim)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func lastSessionMetaText(_ workout: HKWorkout) -> String {
        let weekday = workout.startDate.formatted(.dateTime.weekday(.abbreviated))
        let time = timeString(workout.startDate)
        let dur = formatDurationVerbose(Int(workout.duration / 60))
        var parts: [String] = ["\(weekday) \(time)", dur]
        if let cal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()), cal > 0 {
            parts.append("\(Int(cal)) kcal")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - History card

    private var historyCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "History"))
                    .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
                Spacer()
                NavigationLink {
                    WorkoutHistoryListView()
                        .preferredColorScheme(.dark)
                } label: {
                    Text(String(localized: "See all"))
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Color.accent)
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.card)
            .padding(.bottom, DS.Spacing.s)

            if isLoading && workouts.isEmpty {
                ProgressView()
                    .tint(DS.Color.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.l)
            } else if workouts.isEmpty {
                Text(String(localized: "No workouts in the last 30 days"))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.l)
            } else {
                ForEach(Array(workouts.prefix(6).enumerated()), id: \.element.uuid) { idx, workout in
                    historyRow(workout, isFirst: idx == 0)
                }
            }
        }
        .background(DS.Color.bgElev)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
        )
    }

    private func historyRow(_ workout: HKWorkout, isFirst: Bool) -> some View {
        HStack(spacing: 12) {
            // Day label column (3-letter weekday + day number)
            VStack(spacing: 2) {
                Text(workout.startDate.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(DS.Typography.mono.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(DS.Color.inkDim)
                Text("\(Calendar.current.component(.day, from: workout.startDate))")
                    .font(DS.Typography.bodyS.weight(.medium).monospacedDigit())
                    .foregroundStyle(DS.Color.ink)
            }
            .frame(width: 44)

            // Title + meta
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutName(workout))
                    .font(DS.Typography.bodyS.weight(.medium))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)
                Text(historyMetaText(workout))
                    .font(DS.Typography.caption.monospacedDigit())
                    .foregroundStyle(DS.Color.inkDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Zone chip
            Text(estimatedZone(workout))
                .font(DS.Typography.mono)
                .foregroundStyle(DS.Color.inkDim)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.card)
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle()
                    .fill(DS.Color.lineSoft)
                    .frame(height: DS.Stroke.hairline)
            }
        }
    }

    private func historyMetaText(_ workout: HKWorkout) -> String {
        let mins = Int(workout.duration / 60)
        var s = "\(mins)m"
        if let cal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()), cal > 0 {
            s += " · \(Int(cal)) kcal"
        }
        return s
    }

    /// Rough estimate of dominant HR zone based on average heart rate / max HR ratio.
    /// JSX shows static "Z3"/"Z4"; without per-row HR samples we approximate via avgHR.
    private func estimatedZone(_ workout: HKWorkout) -> String {
        // Try to use cached zones if available
        if let zones = heartRateZones[workout.uuid],
           let dominant = zones.max(by: { $0.percentage < $1.percentage }) {
            return zoneShortLabel(dominant.name)
        }
        return "—"
    }

    private func zoneShortLabel(_ name: String) -> String {
        // Map zone names to Z1-Z5
        switch name {
        case String(localized: "Warm-up"): return "Z1"
        case String(localized: "Fat Burn"): return "Z2"
        case String(localized: "Cardio"): return "Z3"
        case String(localized: "Anaerobic"): return "Z4"
        case String(localized: "Peak"): return "Z5"
        default: return "—"
        }
    }

    // MARK: - Strength section (Pulse-only, behind divider)

    private var strengthAssessment: StrengthService.StrengthAssessment? {
        StrengthService.shared.assess(records: strengthRecords, bodyweightKg: bodyweight)
    }

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.s) {
                Text(String(localized: "Strength"))
                    .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
                Spacer()
                if let a = strengthAssessment, a.totalScore > 0 {
                    Text("\(a.totalScore)")
                        .font(DS.Typography.bodyS.weight(.semibold).monospacedDigit())
                        .foregroundStyle(DS.Color.ink)
                        .padding(.horizontal, DS.Spacing.s)
                        .padding(.vertical, DS.Spacing.m)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                                .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
                        )
                }
                Button {
                    showAddStrength = true
                } label: {
                    Image(systemName: "plus")
                        .font(DS.Typography.bodyS.weight(.medium))
                        .foregroundStyle(DS.Color.accent)
                        .frame(width: DS.Spacing.xl - DS.Spacing.xs, height: DS.Spacing.xl - DS.Spacing.xs)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                                .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
                        )
                }
                .buttonStyle(.plain)
            }

            // 3-up best lifts
            if let a = strengthAssessment, !a.lifts.isEmpty {
                HStack(spacing: 0) {
                    ForEach(a.lifts, id: \.liftType) { lift in
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", lift.best1RM))
                                .font(DS.Typography.title2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(DS.Color.ink)
                            Text(lift.liftType.label)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Color.inkMid)
                            Text(lift.level.label)
                                .font(DS.Typography.mono.weight(.medium))
                                .foregroundStyle(DS.Color.inkDim)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else if bodyweight <= 0 {
                Text(String(localized: "Set body weight in Settings → Profile"))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)
            } else if strengthRecords.isEmpty {
                Text(String(localized: "No lifts recorded yet — tap + to add"))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)
            }

            // Recent records (compact)
            if !strengthRecords.isEmpty {
                Rectangle()
                    .fill(DS.Color.lineSoft)
                    .frame(height: DS.Stroke.hairline)

                VStack(spacing: 8) {
                    ForEach(strengthRecords.prefix(3)) { record in
                        let type = StrengthService.LiftType(rawValue: record.liftType) ?? .squat
                        HStack(spacing: DS.Spacing.s) {
                            Text(type.label)
                                .font(DS.Typography.caption.weight(.medium))
                                .foregroundStyle(DS.Color.ink)
                                .frame(width: 70, alignment: .leading)
                            Text(String(format: "%.0f kg × %d × %d", record.weightKg, record.sets, record.reps))
                                .font(DS.Typography.monoL)
                                .foregroundStyle(DS.Color.inkMid)
                            Spacer()
                            Text(record.date, format: .dateTime.month(.abbreviated).day())
                                .font(DS.Typography.mono)
                                .foregroundStyle(DS.Color.inkDim)
                            if record.isPersonalRecord {
                                Text("PR")
                                    .font(DS.Typography.monoS.weight(.bold))
                                    .foregroundStyle(DS.Color.warn)
                                    .padding(.horizontal, DS.Spacing.xs)
                                    .padding(.vertical, DS.Spacing.m)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .stroke(DS.Color.warn.opacity(0.5), lineWidth: DS.Stroke.hairline)
                                    )
                            }
                        }
                    }
                }

                NavigationLink {
                    StrengthView()
                        .preferredColorScheme(.dark)
                } label: {
                    HStack {
                        Text(String(localized: "View Full Strength Details"))
                            .font(DS.Typography.caption.weight(.medium))
                            .foregroundStyle(DS.Color.accent)
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.mono.weight(.semibold))
                            .foregroundStyle(DS.Color.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, DS.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .dsCard(padding: DS.Spacing.l)
    }

    // MARK: - AI workouts (Pulse-only)

    private var aiWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.accent)
                Text(String(localized: "OpenClaw AI Records"))
                    .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
            }

            VStack(spacing: 0) {
                ForEach(Array(recentAIWorkouts.enumerated()), id: \.offset) { idx, entry in
                    aiWorkoutRow(entry, isFirst: idx == 0)
                }
            }
            .background(DS.Color.bgElev)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
            )
        }
    }

    private func aiWorkoutRow(_ entry: WorkoutHistoryEntry, isFirst: Bool) -> some View {
        let title = !(entry.notes ?? "").isEmpty ? entry.notes! : entry.activityName
        return NavigationLink(destination: WorkoutHistoryDetailView(entry: entry)) {
            HStack(spacing: 12) {
                Image(systemName: entry.activityIcon)
                    .font(DS.Typography.bodyS.weight(.medium))
                    .foregroundStyle(DS.Color.inkMid)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(DS.Typography.bodyS.weight(.medium))
                            .foregroundStyle(DS.Color.ink)
                            .lineLimit(1)
                        Text("AI")
                            .font(DS.Typography.monoS.weight(.bold))
                            .foregroundStyle(DS.Color.accent)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.m)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(DS.Color.accent.opacity(0.5), lineWidth: DS.Stroke.hairline)
                            )
                    }
                    Text(timeString(entry.startDate))
                        .font(DS.Typography.mono)
                        .foregroundStyle(DS.Color.inkDim)
                }
                Spacer()
                Text("\(entry.durationMinutes)m")
                    .font(DS.Typography.monoL)
                    .foregroundStyle(DS.Color.inkMid)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.inkDim)
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.card)
            .overlay(alignment: .top) {
                if !isFirst {
                    Rectangle()
                        .fill(DS.Color.lineSoft)
                        .frame(height: DS.Stroke.hairline)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state / loading

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: "figure.run")
                .font(DS.Typography.title1.weight(.light))
                .foregroundStyle(DS.Color.inkDim)
            Text(String(localized: "No workout records yet"))
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(DS.Color.ink)
            Text(String(localized: "Your workout records will appear here.\nSupports running, cycling, swimming, strength training, and more."))
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.inkMid)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.vertical, DS.Spacing.xl)
        .frame(maxWidth: .infinity)
        .dsCard(padding: DS.Spacing.l)
    }

    private var loadingPlaceholder: some View {
        VStack {
            ProgressView()
                .tint(DS.Color.accent)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .dsCard(padding: DS.Spacing.l)
    }

    // MARK: - Data loading

    private func loadWorkouts() async {
        isLoading = true

        guard HKHealthStore.isHealthDataAvailable() else {
            isLoading = false
            return
        }

        let workoutType = HKWorkoutType.workoutType()
        let readTypes: Set<HKObjectType> = [workoutType, HKQuantityType(.heartRate)]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            isLoading = false
            return
        }

        let calendar = Calendar.current
        let now = Date()
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else {
            isLoading = false
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 50
        )

        do {
            let results = try await descriptor.result(for: store)
            workouts = results

            // Week stats
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let weekWorkouts = results.filter { $0.startDate >= startOfWeek }

            let totalMinutes = weekWorkouts.reduce(0) { $0 + Int($1.duration / 60) }
            let totalCalories = weekWorkouts.reduce(0.0) {
                $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
            }
            let activeDays = Set(weekWorkouts.map { calendar.startOfDay(for: $0.startDate) }).count

            weekStats = WeekWorkoutStats(
                totalCount: weekWorkouts.count,
                totalMinutes: totalMinutes,
                totalCalories: totalCalories,
                activeDays: activeDays
            )

            // 7-day strip — Monday-first
            var strip = Array(repeating: false, count: 7)
            // Compute Monday of the current ISO week
            let weekday = calendar.component(.weekday, from: now)  // 1=Sun..7=Sat
            let daysSinceMonday = (weekday + 5) % 7
            if let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: now)) {
                for w in weekWorkouts {
                    let day = calendar.startOfDay(for: w.startDate)
                    let diff = calendar.dateComponents([.day], from: monday, to: day).day ?? 0
                    if (0..<7).contains(diff) {
                        strip[diff] = true
                    }
                }
            }
            weekDayActivity = strip

            // Eagerly load HR zones for last session and (best-effort) for history rows
            if let last = results.first {
                await loadHeartRateZones(for: last, isLastSession: true)
            }
            for w in results.prefix(6).dropFirst() {
                await loadHeartRateZones(for: w, isLastSession: false)
            }
        } catch {
            logger.error("Workout fetch error: \(error)")
        }

        isLoading = false
    }

    private func loadHeartRateZones(for workout: HKWorkout, isLastSession: Bool) async {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        do {
            let samples = try await descriptor.result(for: store)
            let bpmValues = samples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }

            guard !bpmValues.isEmpty else { return }

            let maxHR: Double = 190
            var zoneCounts = [0, 0, 0, 0, 0]
            let total = Double(bpmValues.count)

            for bpm in bpmValues {
                let pct = bpm / maxHR
                switch pct {
                case ..<0.6:    zoneCounts[0] += 1
                case 0.6..<0.7: zoneCounts[1] += 1
                case 0.7..<0.8: zoneCounts[2] += 1
                case 0.8..<0.9: zoneCounts[3] += 1
                default:        zoneCounts[4] += 1
                }
            }

            let zones: [HeartRateZone] = [
                HeartRateZone(name: String(localized: "Warm-up"), percentage: Double(zoneCounts[0]) / total, color: PulseTheme.zoneRest),
                HeartRateZone(name: String(localized: "Fat Burn"), percentage: Double(zoneCounts[1]) / total, color: PulseTheme.zoneFatBurn),
                HeartRateZone(name: String(localized: "Cardio"), percentage: Double(zoneCounts[2]) / total, color: PulseTheme.zoneCardio),
                HeartRateZone(name: String(localized: "Anaerobic"), percentage: Double(zoneCounts[3]) / total, color: PulseTheme.zonePeak),
                HeartRateZone(name: String(localized: "Peak"), percentage: Double(zoneCounts[4]) / total, color: PulseTheme.zoneMax),
            ]

            heartRateZones[workout.uuid] = zones

            if isLastSession {
                let totalMins = max(1, Int(workout.duration / 60))
                lastSessionZoneMinutes = zoneCounts.map { Int(round(Double($0) / total * Double(totalMins))) }
            }
        } catch {
            logger.error("HR zone fetch error: \(error)")
        }
    }

    // MARK: - Helpers

    private func workoutName(_ workout: HKWorkout) -> String {
        switch workout.workoutActivityType {
        case .running:              return String(localized: "Running")
        case .cycling:              return String(localized: "Cycling")
        case .swimming:             return String(localized: "Swimming")
        case .walking:              return String(localized: "Walking")
        case .hiking:               return String(localized: "Hiking")
        case .yoga:                 return String(localized: "Yoga")
        case .functionalStrengthTraining: return String(localized: "Functional Strength")
        case .traditionalStrengthTraining: return String(localized: "Strength Training")
        case .highIntensityIntervalTraining: return String(localized: "HIIT")
        case .dance:                return String(localized: "Dance")
        case .elliptical:           return String(localized: "Elliptical")
        case .rowing:               return String(localized: "Rowing")
        case .stairClimbing:        return String(localized: "Stair Climbing")
        case .basketball:           return String(localized: "Basketball")
        case .soccer:               return String(localized: "Soccer")
        case .tennis:               return String(localized: "Tennis")
        case .tableTennis:          return String(localized: "Table Tennis")
        case .badminton:            return String(localized: "Badminton")
        case .cooldown:             return String(localized: "Cooldown")
        default:                    return String(localized: "Exercise")
        }
    }

    private func formatDurationVerbose(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes) min"
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Data models

private struct WeekWorkoutStats {
    let totalCount: Int
    let totalMinutes: Int
    let totalCalories: Double
    let activeDays: Int
}

private struct HeartRateZone: Identifiable {
    let id = UUID()
    let name: String
    let percentage: Double
    let color: Color
}

#Preview {
    TrainingView()
        .preferredColorScheme(.dark)
}
