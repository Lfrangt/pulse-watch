import SwiftUI
import SwiftData
import os
#if canImport(UIKit)
import UIKit
#endif

// S05 · Trends (formerly "History")
//
// Replaces HistoryView (2141 lines) with DS primitives. Functional surface
// preserved per R11: range filter (7D/30D/90D/1Y) → period summary → 5 trend
// cards (readiness/HRV/RHR/sleep/stress) → weekly comparison vs prior week
// → shortcut row to TrainingCalendar / Weekly Report sheet / Workout Log
// → MuscleInsightsCard → analytics shortcuts (Insights / Anomalies / Challenges
// / Monthly Report sheet).

struct TrendsView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "TrendsView")

    enum Range: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30
        case quarter = 90
        case year = 365

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .week:    return "7D"
            case .month:   return "30D"
            case .quarter: return "90D"
            case .year:    return "1Y"
            }
        }
        var days: Int { rawValue }
    }

    @State private var range: Range = .week
    @State private var showWeeklyReport = false
    @State private var showMonthlyReport = false

    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @Query(sort: \WorkoutHistoryEntry.startDate, order: .reverse) private var allWorkouts: [WorkoutHistoryEntry]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.bg.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.group) {
                        navHeader
                        rangeTabs
                        summaryBlock
                        if dataInsufficient { insufficientHint }
                        trendsBlock
                        weeklyComparisonBlock
                        shortcutsBlock
                        muscleInsightsBlock
                        proAnalyticsBlock
                        Spacer(minLength: DS.Spacing.xl)
                    }
                    .padding(.horizontal, DS.Spacing.edge)
                    .padding(.top, DS.Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showWeeklyReport) {
                WeeklyReportView()
                    .onAppear { Analytics.trackWeeklyReportViewed() }
            }
            .sheet(isPresented: $showMonthlyReport) {
                MonthlyReportView()
            }
            .onAppear {
                let cal = Calendar.current
                guard let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: .now) else { return }
                let recent = allSummaries.filter { $0.date >= sevenDaysAgo && $0.dailyScore != nil }
                ReviewRequestManager.shared.recordTrendsViewed(hasSevenDayData: recent.count >= 7)
            }
        }
    }

    // MARK: - NAV

    private var navHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            MonoLabel(text: String(localized: "Trends"), size: .l, tone: .emphasised)
            Spacer()
            MonoLabel(text: rangeLabel, size: .s, tone: .dim)
        }
        .padding(.bottom, DS.Spacing.s)
    }

    private var rangeLabel: String {
        switch range {
        case .week:    return String(localized: "7-day window")
        case .month:   return String(localized: "30-day window")
        case .quarter: return String(localized: "90-day window")
        case .year:    return String(localized: "1-year window")
        }
    }

    // MARK: - Range tabs

    private var rangeTabs: some View {
        HStack(spacing: 0) {
            ForEach(Range.allCases) { r in
                rangeTab(r)
            }
        }
        .padding(DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                .fill(DS.Color.bgElev)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
        )
    }

    private func rangeTab(_ r: Range) -> some View {
        let active = range == r
        return Button {
            range = r
        } label: {
            Text(r.label)
                .font(DS.Typography.mono)
                .tracking(DS.Tracking.mono)
                .foregroundStyle(active ? DS.Color.accentInk : DS.Color.inkMid)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                        .fill(active ? DS.Color.accent : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Period summary (3-up: Score / HRV / Sleep)

    private var summaryBlock: some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                summaryColumn(
                    label: String(localized: "Score"),
                    current: avgScore(filteredSummaries),
                    prev: avgScore(prevPeriodSummaries),
                    formatter: { "\(Int($0.rounded()))" },
                    polarity: .higherIsBetter
                )
                Divider().frame(width: DS.Stroke.hairline).background(DS.Color.lineSoft)
                summaryColumn(
                    label: "HRV",
                    current: avgHRV(filteredSummaries),
                    prev: avgHRV(prevPeriodSummaries),
                    formatter: { String(format: "%.0f", $0) + " ms" },
                    polarity: .higherIsBetter
                )
                Divider().frame(width: DS.Stroke.hairline).background(DS.Color.lineSoft)
                summaryColumn(
                    label: String(localized: "Sleep"),
                    current: avgSleepHours(filteredSummaries),
                    prev: avgSleepHours(prevPeriodSummaries),
                    formatter: { String(format: "%.1fh", $0) },
                    polarity: .higherIsBetter
                )
            }
        }
    }

    private func summaryColumn(
        label: String,
        current: Double?,
        prev: Double?,
        formatter: (Double) -> String,
        polarity: Polarity
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            MonoLabel(text: label, size: .s, tone: .dim)
            Text(current.map(formatter) ?? "—")
                .font(DS.Typography.title2)
                .foregroundStyle(DS.Color.ink)
                .monospacedDigit()
            if let c = current, let p = prev {
                let diff = c - p
                let tone: MonoTone = deltaTone(diff: diff, polarity: polarity)
                let sign = diff >= 0 ? "+" : ""
                MonoLabel(text: "\(sign)\(formatter(diff))", size: .s, tone: tone)
            } else {
                MonoLabel(text: "—", size: .s, tone: .dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deltaTone(diff: Double, polarity: Polarity) -> MonoTone {
        if abs(diff) < 0.5 { return .dim }
        switch polarity {
        case .higherIsBetter: return diff > 0 ? .good : .warn
        case .lowerIsBetter:  return diff < 0 ? .good : .warn
        case .contextual:     return .dim
        }
    }

    // MARK: - Insufficient data hint

    private var insufficientHint: some View {
        Card(sunk: true) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: "Limited Data", size: .s, tone: .warn)
                Spacer()
            }
            Text(String(localized: "Keep wearing your Watch — more days unlock better trends."))
                .font(DS.Typography.bodyS)
                .foregroundStyle(DS.Color.inkMid)
                .padding(.top, DS.Spacing.xs)
        }
    }

    private var dataInsufficient: Bool {
        filteredSummaries.count < range.days / 2
    }

    // MARK: - Trends block (5 trend cards)

    private var trendsBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHead(num: "01", title: String(localized: "Trends"), sub: String(localized: "5 metrics"))

            trendCard(
                label: String(localized: "Readiness"),
                samples: filteredSummaries.compactMap { s in
                    guard let v = s.dailyScore else { return nil }
                    return (s.date, Double(v))
                },
                prevSamples: prevPeriodSummaries.compactMap { s in
                    guard let v = s.dailyScore else { return nil }
                    return (s.date, Double(v))
                },
                formatter: { String(Int($0.rounded())) },
                unit: nil,
                polarity: .higherIsBetter
            )

            trendCard(
                label: "HRV",
                samples: filteredSummaries.compactMap { s in
                    guard let v = s.averageHRV else { return nil }
                    return (s.date, v)
                },
                prevSamples: prevPeriodSummaries.compactMap { s in
                    guard let v = s.averageHRV else { return nil }
                    return (s.date, v)
                },
                formatter: { String(format: "%.0f", $0) },
                unit: "ms",
                polarity: .higherIsBetter
            )

            trendCard(
                label: String(localized: "Resting HR"),
                samples: filteredSummaries.compactMap { s in
                    guard let v = s.restingHeartRate else { return nil }
                    return (s.date, v)
                },
                prevSamples: prevPeriodSummaries.compactMap { s in
                    guard let v = s.restingHeartRate else { return nil }
                    return (s.date, v)
                },
                formatter: { String(format: "%.0f", $0) },
                unit: "bpm",
                polarity: .lowerIsBetter
            )

            trendCard(
                label: String(localized: "Sleep"),
                samples: filteredSummaries.compactMap { s in
                    guard let v = s.sleepDurationMinutes else { return nil }
                    return (s.date, Double(v) / 60.0)
                },
                prevSamples: prevPeriodSummaries.compactMap { s in
                    guard let v = s.sleepDurationMinutes else { return nil }
                    return (s.date, Double(v) / 60.0)
                },
                formatter: { String(format: "%.1f", $0) },
                unit: "h",
                polarity: .higherIsBetter
            )

            trendCard(
                label: String(localized: "Stress"),
                samples: filteredSummaries.compactMap { s in
                    guard let v = s.stressScore else { return nil }
                    return (s.date, Double(v))
                },
                prevSamples: prevPeriodSummaries.compactMap { s in
                    guard let v = s.stressScore else { return nil }
                    return (s.date, Double(v))
                },
                formatter: { String(Int($0.rounded())) },
                unit: nil,
                polarity: .lowerIsBetter
            )
        }
    }

    private func trendCard(
        label: String,
        samples: [(Date, Double)],
        prevSamples: [(Date, Double)],
        formatter: @escaping (Double) -> String,
        unit: String?,
        polarity: Polarity
    ) -> some View {
        let current = samples.isEmpty ? nil : samples.map(\.1).reduce(0, +) / Double(samples.count)
        let prev = prevSamples.isEmpty ? nil : prevSamples.map(\.1).reduce(0, +) / Double(prevSamples.count)
        let diff: Double? = (current != nil && prev != nil) ? (current! - prev!) : nil
        let chartData: [(day: Date, value: Int)] = samples.map { (day: $0.0, value: Int($0.1.rounded())) }

        return Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                HStack(alignment: .firstTextBaseline) {
                    MonoLabel(text: label, size: .m)
                    Spacer()
                    if let c = current {
                        let unitText = unit.map { " \($0)" } ?? ""
                        Text(formatter(c) + unitText)
                            .font(DS.Typography.bodyL)
                            .foregroundStyle(DS.Color.ink)
                    } else {
                        MonoLabel(text: "—", size: .m, tone: .dim)
                    }
                }
                if let d = diff {
                    let sign = d >= 0 ? "+" : ""
                    let tone: MonoTone = deltaTone(diff: d, polarity: polarity)
                    let unitText = unit.map { " \($0)" } ?? ""
                    MonoLabel(text: "\(sign)\(formatter(d))\(unitText) " + String(localized: "vs prev period"), size: .s, tone: tone)
                }
                ScoreChart(data: chartData, height: 80)
            }
        }
    }

    // MARK: - Weekly comparison

    private var weeklyComparisonBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHead(num: "02", title: String(localized: "This Week"), sub: String(localized: "vs last week"))
            Card {
                VStack(spacing: 0) {
                    weekRow(
                        label: String(localized: "Score"),
                        current: avgScore(currentWeekSummaries),
                        prev: avgScore(lastWeekSummaries),
                        formatter: { "\(Int($0.rounded()))" },
                        polarity: .higherIsBetter
                    )
                    Rectangle().fill(DS.Color.lineSoft).frame(height: DS.Stroke.hairline)
                    weekRow(
                        label: String(localized: "Sleep"),
                        current: avgSleepHours(currentWeekSummaries),
                        prev: avgSleepHours(lastWeekSummaries),
                        formatter: { String(format: "%.1fh", $0) },
                        polarity: .higherIsBetter
                    )
                    Rectangle().fill(DS.Color.lineSoft).frame(height: DS.Stroke.hairline)
                    weekRow(
                        label: "HRV",
                        current: avgHRV(currentWeekSummaries),
                        prev: avgHRV(lastWeekSummaries),
                        formatter: { String(format: "%.0f ms", $0) },
                        polarity: .higherIsBetter
                    )
                    Rectangle().fill(DS.Color.lineSoft).frame(height: DS.Stroke.hairline)
                    weekRow(
                        label: String(localized: "Steps"),
                        current: avgSteps(currentWeekSummaries),
                        prev: avgSteps(lastWeekSummaries),
                        formatter: { steps in
                            steps >= 1000 ? String(format: "%.1fk", steps / 1000) : String(format: "%.0f", steps)
                        },
                        polarity: .higherIsBetter
                    )
                }
            }
            Button {
                showWeeklyReport = true
            } label: {
                HStack {
                    Spacer()
                    MonoLabel(text: String(localized: "View Full Report"), size: .m, tone: .accent)
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                        .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func weekRow(
        label: String,
        current: Double?,
        prev: Double?,
        formatter: @escaping (Double) -> String,
        polarity: Polarity
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            MonoLabel(text: label, size: .m)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(current.map(formatter) ?? "—")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.ink)
                    .monospacedDigit()
                if let c = current, let p = prev {
                    let diff = c - p
                    let tone: MonoTone = deltaTone(diff: diff, polarity: polarity)
                    let sign = diff >= 0 ? "+" : ""
                    MonoLabel(text: "\(sign)\(formatter(diff))", size: .s, tone: tone)
                }
            }
        }
        .padding(.vertical, DS.Spacing.s)
    }

    // MARK: - Shortcuts (preserve TrainingCalendar / WeeklyReport / WorkoutLog access)

    private var shortcutsBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHead(num: "03", title: String(localized: "Shortcuts"))
            HStack(spacing: DS.Spacing.s) {
                NavigationLink { TrainingCalendarView() } label: {
                    shortcutTile(label: String(localized: "Calendar"), sub: String(localized: "Plan"))
                }
                .buttonStyle(.plain)
                Button { showWeeklyReport = true } label: {
                    shortcutTile(label: String(localized: "Weekly"), sub: String(localized: "Report"))
                }
                .buttonStyle(.plain)
                NavigationLink { WorkoutHistoryListView() } label: {
                    shortcutTile(label: String(localized: "Workouts"), sub: String(localized: "Log"))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func shortcutTile(label: String, sub: String) -> some View {
        Card(padding: DS.Spacing.card) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                MonoLabel(text: label, size: .m, tone: .emphasised)
                MonoLabel(text: sub, size: .s, tone: .dim)
            }
        }
    }

    // MARK: - Muscle insights (existing component)

    private var muscleInsightsBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHead(num: "04", title: String(localized: "Muscle"), sub: String(localized: "Insights"))
            MuscleInsightsCard(workouts: allWorkouts, summaries: allSummaries)
        }
    }

    // MARK: - Pro analytics

    private var proAnalyticsBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            SectionHead(num: "05", title: String(localized: "Analytics"), sub: String(localized: "Pro"))
            HStack(spacing: DS.Spacing.s) {
                NavigationLink { CorrelationInsightsView() } label: {
                    shortcutTile(label: String(localized: "Insights"), sub: String(localized: "Correlations"))
                }
                .buttonStyle(.plain)
                NavigationLink { AnomalyTimelineView() } label: {
                    shortcutTile(label: String(localized: "Anomalies"), sub: String(localized: "Timeline"))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: DS.Spacing.s) {
                NavigationLink { ChallengeView() } label: {
                    shortcutTile(label: String(localized: "Challenges"), sub: String(localized: "Active"))
                }
                .buttonStyle(.plain)
                Button { showMonthlyReport = true } label: {
                    shortcutTile(label: String(localized: "Monthly"), sub: String(localized: "Report"))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Filters

    private var filteredSummaries: [DailySummary] {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -range.days, to: .now) else { return allSummaries }
        return allSummaries.filter { $0.date >= cutoff }
    }

    private var prevPeriodSummaries: [DailySummary] {
        let cal = Calendar.current
        guard let end = cal.date(byAdding: .day, value: -range.days, to: .now),
              let start = cal.date(byAdding: .day, value: -(range.days * 2), to: .now) else { return [] }
        return allSummaries.filter { $0.date >= start && $0.date < end }
    }

    private var currentWeekSummaries: [DailySummary] {
        let cal = Calendar.current
        guard let weekAgo = cal.date(byAdding: .day, value: -7, to: .now) else { return [] }
        return allSummaries.filter { $0.date >= weekAgo }
    }

    private var lastWeekSummaries: [DailySummary] {
        let cal = Calendar.current
        guard let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: .now),
              let weekAgo = cal.date(byAdding: .day, value: -7, to: .now) else { return [] }
        return allSummaries.filter { $0.date >= twoWeeksAgo && $0.date < weekAgo }
    }

    // MARK: - Aggregates

    private func avgScore(_ s: [DailySummary]) -> Double? {
        let v = s.compactMap(\.dailyScore).map(Double.init)
        guard !v.isEmpty else { return nil }
        return v.reduce(0, +) / Double(v.count)
    }

    private func avgHRV(_ s: [DailySummary]) -> Double? {
        let v = s.compactMap(\.averageHRV)
        guard !v.isEmpty else { return nil }
        return v.reduce(0, +) / Double(v.count)
    }

    private func avgSleepHours(_ s: [DailySummary]) -> Double? {
        let v = s.compactMap(\.sleepDurationMinutes).map { Double($0) / 60.0 }
        guard !v.isEmpty else { return nil }
        return v.reduce(0, +) / Double(v.count)
    }

    private func avgSteps(_ s: [DailySummary]) -> Double? {
        let v = s.compactMap(\.totalSteps).map(Double.init)
        guard !v.isEmpty else { return nil }
        return v.reduce(0, +) / Double(v.count)
    }
}

#Preview {
    TrendsView()
}
