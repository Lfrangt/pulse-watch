import Foundation
import SwiftData
import os

/// Health Age — 基于 5 项指标估算生理年龄
/// 指标：静息心率 / HRV / 睡眠时长 / 日均步数 / 活跃分钟数
/// 需要 ≥7 天有效数据
final class HealthAgeService {

    static let shared = HealthAgeService()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "HealthAge")

    static let minDays = 7

    /// 用户出生年份
    var birthYear: Int {
        get { UserDefaults.standard.integer(forKey: "pulse.user.birthYear") }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.user.birthYear") }
    }

    var hasBirthYear: Bool { birthYear > 1900 && birthYear <= Calendar.current.component(.year, from: .now) }

    var chronologicalAge: Int? {
        guard hasBirthYear else { return nil }
        return Calendar.current.component(.year, from: .now) - birthYear
    }

    // MARK: - 结果

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
            case steps = "steps"
            case activeMinutes = "activeMinutes"

            var label: String {
                switch self {
                case .restingHR:      return String(localized: "Resting Heart Rate")
                case .hrv:            return String(localized: "Heart Rate Variability")
                case .sleep:          return String(localized: "Sleep Duration")
                case .steps:          return String(localized: "Daily Steps")
                case .activeMinutes:  return String(localized: "Active Minutes")
                }
            }

            var icon: String {
                switch self {
                case .restingHR:      return "heart.fill"
                case .hrv:            return "waveform.path.ecg"
                case .sleep:          return "moon.fill"
                case .steps:          return "figure.walk"
                case .activeMinutes:  return "flame.fill"
                }
            }
        }
    }

    // MARK: - 计算

    func compute(modelContext: ModelContext) -> HealthAgeResult? {
        guard let actualAge = chronologicalAge, actualAge > 0 else { return nil }

        let summaries = fetchRecentSummaries(days: 30, modelContext: modelContext)
        let validDays = summaries.filter { s in
            s.restingHeartRate != nil || s.averageHRV != nil
        }.count

        guard validDays >= Self.minDays else { return nil }

        // 计算各指标 7-30 天均值
        let avgRHR = avg(summaries.compactMap(\.restingHeartRate))
        let avgHRV = avg(summaries.compactMap(\.averageHRV))
        let avgSleepMin = avg(summaries.compactMap(\.sleepDurationMinutes).map(Double.init))
        let avgSteps = avg(summaries.compactMap(\.totalSteps).map(Double.init))
        let avgActiveCal = avg(summaries.compactMap(\.activeCalories))

        // 估算每日活跃分钟数（活跃卡路里 / 5 ≈ 活跃分钟，粗略估算）
        let avgActiveMin = avgActiveCal.map { $0 / 5.0 } ?? 0

        var totalImpact: Double = 0
        var metrics: [MetricScore] = []

        // 1. 静息心率: 基准 ~60+年龄/3, 低更好
        if let rhr = avgRHR {
            let baseline = 60.0 + Double(actualAge) / 3.0
            let diff = rhr - baseline
            let impact = diff * 0.4  // 每 bpm 偏差 ≈ 0.4 岁
            totalImpact += impact
            let advice = rhr > 70
                ? String(localized: "Resting HR is elevated — more aerobic exercise can help")
                : String(localized: "Resting HR is in a healthy range")
            metrics.append(MetricScore(metric: .restingHR, value: rhr, ageImpact: impact, advice: advice))
        }

        // 2. HRV: 基准 ~45-年龄/3, 高更好
        if let hrv = avgHRV {
            let baseline = 45.0 - Double(actualAge) / 3.0
            let diff = baseline - hrv  // 低于基准 = 更老
            let impact = diff * 0.35
            totalImpact += impact
            let advice = hrv < 30
                ? String(localized: "HRV is below average — prioritize sleep and stress management")
                : String(localized: "HRV indicates good autonomic health")
            metrics.append(MetricScore(metric: .hrv, value: hrv, ageImpact: impact, advice: advice))
        }

        // 3. 睡眠: 7-9h 最优，偏离越多越差
        if let sleepMin = avgSleepMin {
            let hours = sleepMin / 60.0
            let optimalCenter = 8.0
            let diff = abs(hours - optimalCenter)
            let impact = diff * 1.2  // 每小时偏差 ≈ 1.2 岁
            totalImpact += impact
            let advice: String
            if hours < 6.5 {
                advice = String(localized: "Sleep is too short — aim for 7-9 hours")
            } else if hours > 9.5 {
                advice = String(localized: "Oversleeping may indicate underlying issues")
            } else {
                advice = String(localized: "Sleep duration is in the optimal range")
            }
            metrics.append(MetricScore(metric: .sleep, value: hours, ageImpact: impact, advice: advice))
        }

        // 4. 步数: 10000 为基准
        if let steps = avgSteps {
            let diff = (10000 - steps) / 2000  // 每 2000 步偏差 ≈ 1 岁
            let impact = max(-3, min(3, diff))
            totalImpact += impact
            let advice = steps < 6000
                ? String(localized: "Steps are below average — try walking 30 min daily")
                : String(localized: "Step count is solid — keep it up")
            metrics.append(MetricScore(metric: .steps, value: steps, ageImpact: impact, advice: advice))
        }

        // 5. 活跃分钟: WHO 建议每周 150 min = 每天 ~21 min
        let dailyActiveTarget = 21.0
        let activeDiff = (dailyActiveTarget - avgActiveMin) / 7.0  // 每 7 min 偏差 ≈ 1 岁
        let activeImpact = max(-2, min(2, activeDiff))
        totalImpact += activeImpact
        let activeAdvice = avgActiveMin < 15
            ? String(localized: "Low activity — WHO recommends 150 min/week of moderate exercise")
            : String(localized: "Activity level meets WHO guidelines")
        metrics.append(MetricScore(metric: .activeMinutes, value: avgActiveMin, ageImpact: activeImpact, advice: activeAdvice))

        let healthAge = Double(actualAge) + totalImpact
        let clampedAge = max(max(Double(actualAge) - 10, 18), min(Double(actualAge) + 15, healthAge))

        return HealthAgeResult(
            healthAge: clampedAge,
            chronologicalAge: actualAge,
            difference: clampedAge - Double(actualAge),
            metrics: metrics,
            daysOfData: validDays
        )
    }

    /// 数据不足时返回还差几天
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
            MetricScore(metric: .sleep, value: 7.5, ageImpact: 0.4, advice: "Sleep duration is in the optimal range"),
            MetricScore(metric: .steps, value: 9200, ageImpact: 0.4, advice: "Step count is solid — keep it up"),
            MetricScore(metric: .activeMinutes, value: 35, ageImpact: -1.3, advice: "Activity level meets WHO guidelines"),
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
