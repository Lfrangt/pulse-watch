import Foundation
import SwiftData
import os

/// Health Age — Biological age estimation using the Klemera-Doubal Method (KDM)
///
/// Algorithm based on peer-reviewed research:
///
/// [1] Klemera P, Doubal S. "A new approach to the concept and computation
///     of biological age." Mech Ageing Dev, 2006;127(3):240-248.
///     → KDM framework: multi-biomarker regression against chronological age
///
/// [2] Zhang D et al. "Resting heart rate and all-cause and cardiovascular
///     mortality in the general population." J Epidemiol Community Health,
///     2016;70(5):499-505.  (Meta-analysis, 46 studies, N > 1.2M)
///     → RHR population norm: intercept ≈ 64 bpm, slope ≈ +0.16 bpm/year, SD ≈ 10.5
///
/// [3] Shaffer F, Ginsberg JP. "An Overview of Heart Rate Variability Metrics
///     and Norms." Front Public Health, 2017;5:258.
///     + Altini M, Plews D. (2021) — Apple Watch short-window SDNN norms:
///     → SDNN norm (short-window): intercept ≈ 62 ms, slope ≈ −0.55 ms/year, SD ≈ 17
///
/// [4] Saint-Maurice PF et al. "Association of Daily Step Count and Step
///     Intensity With Mortality Among US Adults." JAMA, 2020;323(12):1151-1160.
///     + Tudor-Locke C et al. Int J Behav Nutr Phys Act, 2011;8:79.
///     → Steps norm: intercept ≈ 10500, slope ≈ −80 steps/year, SD ≈ 3000
///
/// [5] Cappuccio FP et al. "Sleep duration and all-cause mortality:
///     a systematic review and meta-analysis." Sleep, 2010;33(5):585-592.
///     → U-shaped mortality: <6h HR=1.12, >9h HR=1.30; optimal 7–8h
///
/// [6] WHO 2020 Physical Activity Guidelines.
///     → 150 min/week moderate intensity (≈21 min/day) threshold
///
final class HealthAgeService {

    static let shared = HealthAgeService()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "HealthAge")

    static let minDays = 7

    /// User birth year
    var birthYear: Int {
        get { UserDefaults.standard.integer(forKey: "pulse.user.birthYear") }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.user.birthYear") }
    }

    var hasBirthYear: Bool { birthYear > 1900 && birthYear <= Calendar.current.component(.year, from: .now) }

    /// Birth month (1-12) for precise age
    var birthMonth: Int {
        get { UserDefaults.standard.integer(forKey: "pulse.user.birthMonth") }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.user.birthMonth") }
    }

    var chronologicalAge: Int? {
        guard hasBirthYear else { return nil }
        let cal = Calendar.current
        let now = Date()
        let currentYear = cal.component(.year, from: now)
        let currentMonth = cal.component(.month, from: now)
        var age = currentYear - birthYear
        let bMonth = birthMonth > 0 ? birthMonth : 1
        if currentMonth < bMonth {
            age -= 1
        }
        return max(0, age)
    }

    // MARK: - Result Types

    struct HealthAgeResult {
        let healthAge: Double
        let chronologicalAge: Int
        let difference: Double       // negative = younger (good)
        let metrics: [MetricScore]
        let daysOfData: Int

        var isYounger: Bool { difference < -0.5 }
        var isOlder: Bool { difference > 0.5 }
    }

    struct MetricScore {
        let metric: Metric
        let value: Double
        let ageImpact: Double        // negative = makes you younger
        let advice: String

        enum Metric: String, CaseIterable {
            case restingHR = "restingHR"
            case hrv = "hrv"
            case sleep = "sleep"

            var label: String {
                switch self {
                case .restingHR:      return String(localized: "Resting Heart Rate")
                case .hrv:            return String(localized: "Heart Rate Variability")
                case .sleep:          return String(localized: "Sleep Duration")
                }
            }

            var icon: String {
                switch self {
                case .restingHR:      return "heart.fill"
                case .hrv:            return "waveform.path.ecg"
                case .sleep:          return "moon.fill"
                }
            }
        }
    }

    // MARK: - KDM Regression Parameters (from literature)
    //
    // Each biomarker has a linear regression against chronological age:
    //   expected(age) = intercept + slope × age
    //
    // KDM biological age minimises the weighted distance between observed
    // biomarker values and their age-expected values.

    private struct KDMBiomarker {
        let intercept: Double  // q — value at age 0 (extrapolated)
        let slope: Double      // k — change per year
        let residualSE: Double // s — population scatter around the regression line
    }

    // [2] RHR: +0.16 bpm/year, SD ≈ 10.5 bpm
    private static let rhrParam = KDMBiomarker(intercept: 64.0, slope: 0.16, residualSE: 10.5)

    // [3] Short-window SDNN: −0.55 ms/year, SD ≈ 17 ms
    private static let sdnnParam = KDMBiomarker(intercept: 62.0, slope: -0.55, residualSE: 17.0)

    // Prior uncertainty on biological age (years).
    // Controls how strongly the estimate anchors to chronological age.
    // Age-adaptive: young users anchor more strongly because wearable metrics
    // explain less biological age variance before age ~30 (Ahadi 2020).
    // 19yo → 3.4, 30yo → 4.5, 40yo → 5.5, 60yo → 7.5
    private static func adaptiveSBA(for age: Double) -> Double {
        max(3.0, min(8.0, 1.5 + age * 0.1))
    }

    // MARK: - Computation

    func compute(modelContext: ModelContext) -> HealthAgeResult? {
        guard let actualAge = chronologicalAge, actualAge > 0 else { return nil }

        let summaries = fetchRecentSummaries(days: 30, modelContext: modelContext)
        let validDays = summaries.filter { s in
            s.restingHeartRate != nil || s.averageHRV != nil
        }.count

        guard validDays > 0 else { return nil }

        // 7–30 day rolling averages for stability
        let avgRHR = avg(summaries.compactMap(\.restingHeartRate))
        let avgHRV = avg(summaries.compactMap(\.averageHRV))
        let avgSleepMin = avg(summaries.compactMap(\.sleepDurationMinutes).map(Double.init))

        let ca = Double(actualAge)

        // ── KDM Biological Age [1] ──────────────────────────────────
        //
        // BioAge = [ Σ_j (m_j − q_j) · k_j / s_j²  +  CA / s_BA² ]
        //          ÷ [ Σ_j k_j² / s_j²  +  1 / s_BA² ]

        let sBA = Self.adaptiveSBA(for: ca)
        var numerator = ca / (sBA * sBA)
        var denominator = 1.0 / (sBA * sBA)

        struct BiomarkerInput {
            let param: KDMBiomarker
            let observed: Double
        }

        var inputs: [(metric: MetricScore.Metric, biomarker: BiomarkerInput)] = []

        if let rhr = avgRHR {
            inputs.append((.restingHR, BiomarkerInput(param: Self.rhrParam, observed: rhr)))
        }
        if let hrv = avgHRV {
            inputs.append((.hrv, BiomarkerInput(param: Self.sdnnParam, observed: hrv)))
        }

        for input in inputs {
            let p = input.biomarker.param
            let m = input.biomarker.observed
            let s2 = p.residualSE * p.residualSE
            numerator += (m - p.intercept) * p.slope / s2
            denominator += (p.slope * p.slope) / s2
        }

        let kdmAge = numerator / denominator

        // ── Per-Metric Impact for Display ───────────────────────────
        // Each KDM biomarker's contribution = w_j × (impliedAge_j − CA)
        // where w_j = (k_j²/s_j²) / denominator, impliedAge_j = (m_j − q_j) / k_j

        var metrics: [MetricScore] = []

        for input in inputs {
            let p = input.biomarker.param
            let m = input.biomarker.observed
            let s2 = p.residualSE * p.residualSE
            let weight = (p.slope * p.slope / s2) / denominator
            let impliedAge = (m - p.intercept) / p.slope
            let ageImpact = weight * (impliedAge - ca)

            let advice: String
            switch input.metric {
            case .restingHR:
                let expected = p.intercept + p.slope * ca
                if m < 50 {
                    advice = String(localized: "Very low RHR — typical of endurance athletes")
                } else if m < expected - 5 {
                    advice = String(localized: "RHR well below age norm — strong cardiovascular health")
                } else if m < expected + 5 {
                    advice = String(localized: "RHR in normal range for your age (Zhang 2016 norms)")
                } else {
                    advice = String(localized: "RHR above age norm — aerobic training can help lower it")
                }
            case .hrv:
                let expected = p.intercept + p.slope * ca
                if m > expected * 1.3 {
                    advice = String(localized: "HRV well above age norm — excellent autonomic function")
                } else if m > expected * 0.85 {
                    advice = String(localized: "HRV in normal range for your age (Shaffer 2017 norms)")
                } else {
                    advice = String(localized: "HRV below age norm — improving sleep and reducing stress can help")
                }
            default:
                advice = ""
            }

            metrics.append(MetricScore(
                metric: input.metric,
                value: m,
                ageImpact: ageImpact,
                advice: advice
            ))
        }

        // ── Sleep Penalty [5] ───────────────────────────────────────
        // U-shaped mortality: optimal 7–8h.
        // Gompertz doubling time ≈ 8 years → HR 1.12 ≈ +1.1 year per hour short,
        // HR 1.30 ≈ +2.4 year per hour long. Simplified to ≈ 1.5 yr/h short, 2.0 yr/h long.
        var sleepPenalty: Double = 0
        if let sleepMin = avgSleepMin {
            let hours = sleepMin / 60.0
            if hours < 7.0 {
                sleepPenalty = min(3.0, (7.0 - hours) * 1.5)
            } else if hours > 8.0 {
                sleepPenalty = min(3.0, (hours - 8.0) * 2.0)
            }
            let sleepAdvice: String
            switch hours {
            case ..<6.0:
                sleepAdvice = String(localized: "Severe sleep deficit — significantly elevated mortality risk (Cappuccio 2010)")
            case 6.0..<7.0:
                sleepAdvice = String(localized: "Slightly short on sleep — aim for 7–8 hours")
            case 7.0..<8.0:
                sleepAdvice = String(localized: "Sleep in the optimal range (Cappuccio 2010 meta-analysis)")
            case 8.0..<9.0:
                sleepAdvice = String(localized: "Sleep is adequate — monitor sleep quality")
            default:
                sleepAdvice = String(localized: "Oversleeping — consider evaluating underlying causes")
            }
            metrics.append(MetricScore(
                metric: .sleep,
                value: hours,
                ageImpact: sleepPenalty,
                advice: sleepAdvice
            ))
        }

        // ── Final Biological Age ────────────────────────────────────
        let rawBioAge = kdmAge + sleepPenalty

        // Clamp: wearable-only estimates have ±5–8 year confidence interval.
        // Age-adaptive cap — young users have less physiological aging to reverse,
        // so the offset should be tighter. Scales from ±1.5yr at 19 to ±5yr at 50+.
        // Formula: (chronologicalAge − 16) × 0.3, floored at 1.5, capped at 5.
        let maxOffset = min(5.0, max(1.5, (ca - 16.0) * 0.3))
        let clampedAge = max(ca - maxOffset, min(ca + maxOffset, rawBioAge))

        return HealthAgeResult(
            healthAge: clampedAge,
            chronologicalAge: actualAge,
            difference: clampedAge - ca,
            metrics: metrics,
            daysOfData: validDays
        )
    }

    /// Days of data still needed before computation is available
    func daysUntilReady(modelContext: ModelContext) -> Int? {
        guard hasBirthYear else { return nil }
        let summaries = fetchRecentSummaries(days: 30, modelContext: modelContext)
        let valid = summaries.filter { $0.restingHeartRate != nil || $0.averageHRV != nil }.count
        guard valid < Self.minDays else { return nil }
        return Self.minDays - valid
    }

    // Demo
    static let demoResult = HealthAgeResult(
        healthAge: 25.0,
        chronologicalAge: 28,
        difference: -3.0,
        metrics: [
            MetricScore(metric: .restingHR, value: 58, ageImpact: -1.0, advice: "Resting HR is in a healthy range"),
            MetricScore(metric: .hrv, value: 52, ageImpact: -1.5, advice: "HRV indicates good autonomic health"),
            MetricScore(metric: .sleep, value: 7.5, ageImpact: 0, advice: "Sleep duration is in the optimal range"),
        ],
        daysOfData: 14
    )

    // MARK: - Helpers

    private func fetchRecentSummaries(days: Int, modelContext: ModelContext) -> [DailySummary] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate<DailySummary> { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func avg(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
