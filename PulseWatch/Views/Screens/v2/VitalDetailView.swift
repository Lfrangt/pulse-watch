import SwiftUI
import SwiftData
import os
#if canImport(UIKit)
import UIKit
#endif

// S02 · Vital Detail (parameterised)
//
// Replaces HRV / HeartRate / RestingHR / BloodOxygen / Sleep / Steps / Stress
// / Calories / HealthAge / Activity detail views. One view, one VitalMetric
// enum, one set of DS primitives.

enum VitalMetric: Hashable {
    case hrv
    case heartRate
    case restingHR
    case bloodOxygen
    case sleep
    case steps
    case stress
    case calories
    case healthAge
    case activity

    var label: String {
        switch self {
        case .hrv:         return "HRV"
        case .heartRate:   return String(localized: "Heart Rate")
        case .restingHR:   return String(localized: "Resting HR")
        case .bloodOxygen: return "SpO₂"
        case .sleep:       return String(localized: "Sleep")
        case .steps:       return String(localized: "Steps")
        case .stress:      return String(localized: "Stress")
        case .calories:    return String(localized: "Calories")
        case .healthAge:   return String(localized: "Health Age")
        case .activity:    return String(localized: "Activity")
        }
    }

    var unit: String? {
        switch self {
        case .hrv:         return "ms"
        case .heartRate:   return "bpm"
        case .restingHR:   return "bpm"
        case .bloodOxygen: return "%"
        case .sleep:       return "h"
        case .steps:       return nil
        case .stress:      return nil
        case .calories:    return "kcal"
        case .healthAge:   return "y"
        case .activity:    return nil
        }
    }

    var polarity: Polarity {
        switch self {
        case .hrv, .sleep, .activity, .steps: return .higherIsBetter
        case .heartRate, .restingHR, .stress, .healthAge: return .lowerIsBetter
        case .bloodOxygen, .calories: return .contextual
        }
    }

    var explainer: String {
        switch self {
        case .hrv:
            return String(localized: "HRV (heart-rate variability) reflects how recovered your nervous system is. Higher = more parasympathetic capacity = ready to train. It moves with sleep, stress, alcohol, and overload.")
        case .heartRate:
            return String(localized: "Live heart rate from your watch. Use it during workouts to gauge intensity, not as a daily readiness signal.")
        case .restingHR:
            return String(localized: "Resting heart rate measured during sleep. A rise of 5+ bpm above your baseline often signals illness, dehydration, or overtraining.")
        case .bloodOxygen:
            return String(localized: "Blood oxygen saturation. Healthy resting range is 95–100%. Sustained < 92% deserves a check-in.")
        case .sleep:
            return String(localized: "Total sleep time and stage breakdown. Deep sleep restores the body, REM consolidates the brain. Both follow ~90-minute cycles.")
        case .steps:
            return String(localized: "Cumulative step count for today. A daily floor of 6–8k correlates with cardiovascular health; 10k is a popular but arbitrary target.")
        case .stress:
            return String(localized: "Stress score derived from HRV and resting HR trends. 0 = chill, 100 = sustained sympathetic load. Track patterns, not single readings.")
        case .calories:
            return String(localized: "Active energy burned today, excluding resting metabolism. Higher with cardio, lower on rest days. Don't chase it.")
        case .healthAge:
            return String(localized: "Estimated biological age based on resting HR, HRV, and sleep regularity vs. population norms. Tap for the metric breakdown.")
        case .activity:
            return String(localized: "Composite of steps, exercise minutes, and active calories. Apple's three-ring system rolls up here.")
        }
    }
}

struct VitalDetailView: View {

    let metric: VitalMetric

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "VitalDetailView")

    private let healthManager = HealthKitManager.shared

    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var rangeDays: Int = 30
    @State private var healthAgeResult: HealthAgeService.HealthAgeResult?

    private var isChinese: Bool {
        locale.language.languageCode?.identifier == "zh"
    }

    var body: some View {
        ZStack {
            DS.Color.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.group) {
                    if metric == .sleep {
                        sleepHero
                    } else {
                        standardHero
                    }

                    rangeTabsCard

                    historyChartCard

                    if metric != .healthAge && metric != .sleep {
                        contextNormCard
                    }

                    if metric == .healthAge, let r = healthAgeResult {
                        healthAgeBreakdownCard(r)
                    }

                    explainerCard

                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.edge)
                .padding(.top, DS.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(metric.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                MonoLabel(text: metric.label, size: .m)
            }
        }
        .task { await loadData() }
    }

    // MARK: - Hero (standard)

    private var standardHero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            MonoLabel(text: metric.label, size: .m)
            HStack(alignment: .firstTextBaseline) {
                BigNum(
                    value: heroValueText,
                    unit: heroUnit,
                    size: .display3,
                    color: heroValueColor
                )
                Spacer()
                if let baseline = baselineDelta {
                    VStack(alignment: .trailing, spacing: 2) {
                        MonoLabel(text: baseline.label, size: .s, tone: baseline.tone)
                        MonoLabel(text: String(localized: "vs \(rangeDays)d baseline"), size: .s, tone: .dim)
                    }
                }
            }
            if let sub = heroSubLabel {
                MonoLabel(text: sub, size: .s, tone: .dim)
            }
        }
    }

    // MARK: - Hero (sleep — replaces with SleepBand + duration)

    private var sleepHero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            MonoLabel(text: String(localized: "Last Night"), size: .m)
            HStack(alignment: .firstTextBaseline) {
                BigNum(
                    value: sleepHeroValue,
                    unit: "h",
                    size: .display3
                )
                Spacer()
                MonoLabel(text: sleepStageBreakdownLabel, size: .s, tone: .dim)
            }
            Card(sunk: true) {
                SleepBand(stages: sleepStages)
            }
        }
    }

    // MARK: - Range tabs (P9 spec: 7/30/90/6m/1y)

    private var rangeTabsCard: some View {
        HStack(spacing: 0) {
            rangeTab(7,   label: "7D")
            rangeTab(30,  label: "30D")
            rangeTab(90,  label: "90D")
            rangeTab(180, label: "6M")
            rangeTab(365, label: "1Y")
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

    private func rangeTab(_ days: Int, label: String) -> some View {
        let active = rangeDays == days
        return Button {
            rangeDays = days
        } label: {
            Text(label)
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

    // MARK: - History chart

    private var historyChartCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                HStack {
                    MonoLabel(text: chartHeaderLabel, size: .s, tone: .dim)
                    Spacer()
                }
                ScoreChart(data: chartData)
            }
        }
    }

    private var chartHeaderLabel: String {
        guard !chartData.isEmpty else { return String(localized: "Awaiting Data") }
        let values = chartData.map { Double($0.value) }
        let mean = values.reduce(0, +) / Double(values.count)
        return String(format: String(localized: "Avg %.0f"), mean)
    }

    private var chartData: [(day: Date, value: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard let lo = cal.date(byAdding: .day, value: -(rangeDays - 1), to: today) else { return [] }
        let inRange = allSummaries.filter { $0.date >= lo && $0.date <= today }
        return inRange.compactMap { s in
            guard let v = sampleValue(s) else { return nil }
            return (day: s.date, value: Int(v.rounded()))
        }
    }

    private func sampleValue(_ s: DailySummary) -> Double? {
        switch metric {
        case .hrv:         return s.averageHRV
        case .heartRate:   return s.averageHeartRate
        case .restingHR:   return s.restingHeartRate
        case .bloodOxygen: return s.averageBloodOxygen
        case .sleep:       return s.sleepDurationMinutes.map { Double($0) / 60.0 }
        case .steps:       return s.totalSteps.map(Double.init)
        case .stress:      return s.stressScore.map(Double.init)
        case .calories:    return s.activeCalories
        case .healthAge:   return nil
        case .activity:    return s.totalSteps.map(Double.init)
        }
    }

    // MARK: - Context norm card

    @ViewBuilder
    private var contextNormCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                MonoLabel(text: String(localized: "Context"), size: .s, tone: .dim)
                if let txt = contextText {
                    Text(txt)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    MonoLabel(text: String(localized: "Awaiting Data"), size: .m, tone: .dim)
                }
            }
        }
    }

    private var contextText: String? {
        let userRange = userRangeText()
        let popRange = populationRangeText()
        if userRange == nil && popRange == nil { return nil }
        var parts: [String] = []
        if let u = userRange { parts.append(u) }
        if let p = popRange { parts.append(p) }
        return parts.joined(separator: " · ")
    }

    private func userRangeText() -> String? {
        let values = chartData.map(\.value)
        guard let lo = values.min(), let hi = values.max(), lo != hi else { return nil }
        let unit = metric.unit ?? ""
        let unitSpace = unit.isEmpty ? "" : " \(unit)"
        return String(format: String(localized: "Your range: %d–%d%@"), lo, hi, unitSpace)
    }

    private func populationRangeText() -> String? {
        switch metric {
        case .hrv:
            return String(localized: "Population p50–p90: 30–80 ms")
        case .heartRate:
            return String(localized: "Population resting band: 60–100 bpm")
        case .restingHR:
            return String(localized: "Population p50–p90: 55–75 bpm")
        case .bloodOxygen:
            return String(localized: "Healthy resting: 95–100%")
        case .sleep:
            return String(localized: "Adult target: 7–9 h")
        case .steps:
            return String(localized: "Activity floor: 6,000–8,000 steps")
        case .stress:
            return nil
        case .calories:
            return nil
        case .healthAge, .activity:
            return nil
        }
    }

    // MARK: - Health Age breakdown

    @ViewBuilder
    private func healthAgeBreakdownCard(_ result: HealthAgeService.HealthAgeResult) -> some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                MonoLabel(text: String(localized: "Metric Breakdown"), size: .s, tone: .dim)
                ForEach(Array(result.metrics.enumerated()), id: \.offset) { idx, m in
                    if idx > 0 {
                        Rectangle().fill(DS.Color.lineSoft).frame(height: DS.Stroke.hairline)
                    }
                    healthAgeMetricRow(m)
                }
            }
        }
    }

    private func healthAgeMetricRow(_ m: HealthAgeService.MetricScore) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metricLabel(m.metric))
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.ink)
                if !m.advice.isEmpty {
                    Text(m.advice)
                        .font(DS.Typography.bodyS)
                        .foregroundStyle(DS.Color.inkMid)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            MonoLabel(
                text: String(format: "%+.1fy", m.ageImpact),
                size: .s,
                tone: m.ageImpact < 0 ? .good : (m.ageImpact > 0 ? .warn : .dim)
            )
        }
        .padding(.vertical, DS.Spacing.s)
    }

    private func metricLabel(_ m: HealthAgeService.MetricScore.Metric) -> String {
        switch m {
        case .restingHR: return String(localized: "Resting HR")
        case .hrv:       return "HRV"
        case .sleep:     return String(localized: "Sleep")
        }
    }

    // MARK: - Explainer

    private var explainerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                MonoLabel(text: String(localized: "What This Means"), size: .s, tone: .dim)
                Text(metric.explainer)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Hero value computation

    private var heroValueText: String {
        switch metric {
        case .hrv:         return healthManager.latestHRV.map { String(Int($0)) } ?? "—"
        case .heartRate:   return healthManager.latestHeartRate.map { String(Int($0)) } ?? "—"
        case .restingHR:   return healthManager.latestRestingHR.map { String(Int($0)) } ?? "—"
        case .bloodOxygen:
            guard let v = healthManager.latestBloodOxygen else { return "—" }
            return String(format: "%.0f", v * 100)
        case .sleep:
            let m = healthManager.lastNightSleepMinutes
            return m > 0 ? String(format: "%.1f", Double(m) / 60.0) : "—"
        case .steps:
            let s = healthManager.todaySteps
            if s == 0 { return "—" }
            if s >= 1000 { return String(format: "%.1fk", Double(s) / 1000.0) }
            return "\(s)"
        case .stress:
            let s = healthManager.calculateStressScore()
            return "\(s)"
        case .calories:
            let c = healthManager.todayActiveCalories
            return c > 0 ? String(format: "%.0f", c) : "—"
        case .healthAge:
            return healthAgeResult.map { "\(Int($0.healthAge.rounded()))" } ?? "—"
        case .activity:
            let s = healthManager.todaySteps
            return s == 0 ? "—" : "\(s)"
        }
    }

    private var heroUnit: String? {
        switch metric {
        case .steps where heroValueText.hasSuffix("k"): return nil
        case .steps:    return nil
        case .stress:   return nil
        case .activity: return nil
        default:        return metric.unit
        }
    }

    private var heroValueColor: Color {
        switch metric {
        case .bloodOxygen:
            guard let v = healthManager.latestBloodOxygen else { return DS.Color.inkDim }
            if v < 0.92 { return DS.Color.bad }
            if v < 0.95 { return DS.Color.warn }
            return DS.Color.ink
        default: return DS.Color.ink
        }
    }

    private var heroSubLabel: String? {
        switch metric {
        case .stress:
            let s = healthManager.calculateStressScore()
            return StressLevel.from(score: s).label
        default: return nil
        }
    }

    private var baselineDelta: (label: String, tone: MonoTone)? {
        guard let baseline = computeBaseline(),
              let current = currentMetricValue() else { return nil }
        let diff = current - baseline
        let unit = metric.unit ?? ""
        let unitSpace = unit.isEmpty ? "" : " \(unit)"
        let signed = diff >= 0 ? String(format: "+%.0f%@", diff, unitSpace)
                               : String(format: "%.0f%@", diff, unitSpace)
        let tone: MonoTone
        switch (diff > 0, metric.polarity) {
        case (true, .higherIsBetter):  tone = .good
        case (false, .higherIsBetter): tone = diff < 0 ? .warn : .dim
        case (true, .lowerIsBetter):   tone = .warn
        case (false, .lowerIsBetter):  tone = diff < 0 ? .good : .dim
        case (_, .contextual):         tone = .dim
        }
        return (signed, tone)
    }

    private func currentMetricValue() -> Double? {
        switch metric {
        case .hrv:         return healthManager.latestHRV
        case .heartRate:   return healthManager.latestHeartRate
        case .restingHR:   return healthManager.latestRestingHR
        case .bloodOxygen: return healthManager.latestBloodOxygen.map { $0 * 100 }
        case .sleep:       return Double(healthManager.lastNightSleepMinutes) / 60.0
        case .steps:       return Double(healthManager.todaySteps)
        case .stress:      return Double(healthManager.calculateStressScore())
        case .calories:    return healthManager.todayActiveCalories
        case .healthAge:   return healthAgeResult?.healthAge
        case .activity:    return Double(healthManager.todaySteps)
        }
    }

    private func computeBaseline() -> Double? {
        let values = chartData.map { Double($0.value) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Sleep specifics

    private var sleepHeroValue: String {
        let m = healthManager.lastNightSleepMinutes
        return m > 0 ? String(format: "%.1f", Double(m) / 60.0) : "—"
    }

    private var sleepStageBreakdownLabel: String {
        let deep = healthManager.lastNightDeepSleepMinutes
        let rem = healthManager.lastNightREMSleepMinutes
        return String(format: String(localized: "Deep %dm · REM %dm"), deep, rem)
    }

    private var sleepStages: [SleepStage] {
        let total = healthManager.lastNightSleepMinutes
        let deep = healthManager.lastNightDeepSleepMinutes
        let rem = healthManager.lastNightREMSleepMinutes
        let core = max(0, total - deep - rem)
        guard total > 0 else { return [] }
        return [
            SleepStage(stage: .core, mins: core),
            SleepStage(stage: .rem, mins: rem),
            SleepStage(stage: .deep, mins: deep)
        ]
    }

    // MARK: - Data load

    private func loadData() async {
        do {
            try await healthManager.requestAuthorization()
            await healthManager.refreshAll()
        } catch {
            logger.error("VitalDetailView load error: \(error)")
        }
        if metric == .healthAge {
            healthAgeResult = HealthAgeService.shared.compute(modelContext: modelContext)
        }
    }
}

#Preview {
    NavigationStack {
        VitalDetailView(metric: .hrv)
    }
}
