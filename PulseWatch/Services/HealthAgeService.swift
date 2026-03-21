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

    /// 出生月份（1-12），用于精确年龄计算
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
        // 今年生日还没到，减一岁
        let bMonth = birthMonth > 0 ? birthMonth : 1
        if currentMonth < bMonth {
            age -= 1
        }
        return max(0, age)
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

        guard validDays > 0 else { return nil }

        // 计算各指标 7-30 天均值
        let avgRHR = avg(summaries.compactMap(\.restingHeartRate))
        let avgHRV = avg(summaries.compactMap(\.averageHRV))
        let avgSleepMin = avg(summaries.compactMap(\.sleepDurationMinutes).map(Double.init))
        let avgSteps = avg(summaries.compactMap(\.totalSteps).map(Double.init))
        let avgActiveCal = avg(summaries.compactMap(\.activeCalories))

        // 优先使用真实 appleExerciseTime，无数据时降级到 cal/5 估算
        let avgExerciseMin = avg(summaries.compactMap(\.exerciseMinutes))
        let avgActiveMin: Double
        if let real = avgExerciseMin, real > 0 {
            avgActiveMin = real
        } else {
            avgActiveMin = avgActiveCal.map { $0 / 5.0 } ?? 0
        }

        var totalImpact: Double = 0
        var metrics: [MetricScore] = []

        // 单项影响上限 ±3 年，防止单指标异常值主导结果
        func clamp(_ val: Double, limit: Double = 3.0) -> Double {
            max(-limit, min(limit, val))
        }

        // 1. 静息心率: 基准 60 bpm，偏高老化，偏低年轻
        if let rhr = avgRHR {
            let diff = rhr - 60.0
            let impact = clamp(diff * 0.15)
            totalImpact += impact
            let advice = rhr > 75
                ? String(localized: "静息心率偏高，增加有氧运动有帮助")
                : String(localized: "静息心率在健康范围内")
            metrics.append(MetricScore(metric: .restingHR, value: rhr, ageImpact: impact, advice: advice))
        }

        // 2. HRV: 基准依年龄，范围 25-75ms 合理，超出按比例计算，限 ±3 年
        if let hrv = avgHRV {
            let baseline = max(25.0, 55.0 - Double(actualAge) * 0.5)
            let diff = baseline - hrv  // 低于基准 = 更老
            let impact = clamp(diff * 0.06)
            totalImpact += impact
            let advice = hrv < 25
                ? String(localized: "HRV偏低，注意睡眠和压力管理")
                : hrv > 80
                    ? String(localized: "HRV优秀，自主神经功能良好")
                    : String(localized: "HRV显示自主神经功能良好")
            metrics.append(MetricScore(metric: .hrv, value: hrv, ageImpact: impact, advice: advice))
        }

        // 3. 睡眠: 7-9h 最优，偏离每小时 0.8 岁，限 ±2 年
        if let sleepMin = avgSleepMin {
            let hours = sleepMin / 60.0
            let diff = abs(hours - 8.0)
            let impact = clamp(diff * 0.8, limit: 2.0)
            totalImpact += impact
            let advice: String
            if hours < 6.5 {
                advice = String(localized: "睡眠不足，建议保证 7-9 小时")
            } else if hours > 9.5 {
                advice = String(localized: "睡眠偏多，可能需要关注睡眠质量")
            } else {
                advice = String(localized: "睡眠时长在最佳范围内")
            }
            metrics.append(MetricScore(metric: .sleep, value: hours, ageImpact: impact, advice: advice))
        }

        // 4. 步数: 8000 为基准，每 2000 步 0.8 岁，限 ±2 年
        if let steps = avgSteps {
            let diff = (8000.0 - steps) / 2000.0
            let impact = clamp(diff * 0.8, limit: 2.0)
            totalImpact += impact
            let advice = steps < 5000
                ? String(localized: "步数较低，尝试每天步行 30 分钟")
                : String(localized: "步数达标，继续保持")
            metrics.append(MetricScore(metric: .steps, value: steps, ageImpact: impact, advice: advice))
        }

        // 5. 活跃分钟: WHO 建议每天 ~21 min，限 ±1.5 年
        let dailyActiveTarget = 21.0
        let activeDiff = (dailyActiveTarget - avgActiveMin) / 10.0
        let activeImpact = clamp(activeDiff, limit: 1.5)
        totalImpact += activeImpact
        let activeAdvice = avgActiveMin < 15
            ? String(localized: "活动量较低，WHO 建议每周 150 分钟中等强度运动")
            : String(localized: "活动量达到 WHO 建议标准")
        metrics.append(MetricScore(metric: .activeMinutes, value: avgActiveMin, ageImpact: activeImpact, advice: activeAdvice))

        let healthAge = Double(actualAge) + totalImpact
        // 整体结果限制在 ±5 年内，且不低于 16 岁（避免荒谬结果）
        let lowerBound = max(16.0, Double(actualAge) - 5)
        let upperBound = Double(actualAge) + 5
        let clampedAge = max(lowerBound, min(upperBound, healthAge))

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
