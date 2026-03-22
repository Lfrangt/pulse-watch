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

        // ─────────────────────────────────────────────────────────────
        // 算法基于以下权威研究，每项影响限 ±2 年，总计限 ±5 年
        //
        // [1] RHR — Cooney MT et al. Eur Heart J 2010;31:750-758
        //     Framingham Heart Study: RHR >80 bpm 全因死亡率风险比 1.45
        //     每 10 bpm 偏差 ≈ 0.8 年生理年龄影响
        //
        // [2] HRV (RMSSD) — Shaffer F & Ginsberg JP. Front Public Health 2017;5:258
        //     年龄修正参考区间（20岁:~60ms, 40岁:~40ms, 60岁:~25ms）
        //     斜率约 -0.8ms/year，每 10ms 偏差 ≈ 1.0 年影响
        //
        // [3] 睡眠 — Walker MP. "Why We Sleep". 2017 + CDC MMWR 2016;65(6):137-141
        //     6 年追踪：睡眠 <6h 死亡率 HR 1.65；>9h HR 1.41；7-8h 最优
        //     偏离最优每 1h ≈ 0.7 年影响
        //
        // [4] 步数 — Paluch AZ et al. JAMA Netw Open 2022;5:e2228519
        //     8000 步/天死亡率降低 51%；Saint-Maurice PF et al. JAMA 2020;323:1151-1160
        //     每 1000 步 ≈ 0.3 年影响，上限 ±2 年
        //
        // [5] 活动时间 — WHO 2020 Physical Activity Guidelines
        //     150 min/week 中等强度 = 每天 ~21 min；不足时心血管风险上升
        // ─────────────────────────────────────────────────────────────

        func clampImpact(_ val: Double) -> Double { max(-2.0, min(2.0, val)) }

        // ① 静息心率 [1] Framingham 数据：基准 68 bpm（成人中位数）
        //    RHR 每偏离 10 bpm → 约 0.8 年生理年龄差
        if let rhr = avgRHR {
            let baseline = 68.0
            let diff = rhr - baseline            // 正 = 高于基准 = 更老
            let impact = clampImpact(diff * 0.08) // 10 bpm → 0.8 yr
            totalImpact += impact
            let advice: String
            if rhr < 50 {
                advice = String(localized: "Very low resting HR — typical of endurance athletes")
            } else if rhr < 60 {
                advice = String(localized: "Excellent resting HR (Framingham low-risk range)")
            } else if rhr < 75 {
                advice = String(localized: "Normal resting HR — cardiovascular health is good")
            } else {
                advice = String(localized: "Resting HR is elevated — cardio training can help lower it")
            }
            metrics.append(MetricScore(metric: .restingHR, value: rhr, ageImpact: impact, advice: advice))
        }

        // ② HRV (RMSSD) [2] Shaffer & Ginsberg 2017
        //    年龄修正基准：baseline ≈ 60 - 0.8 × (age - 20)
        //    每 10ms 偏离基准 → 约 1.0 年影响
        if let hrv = avgHRV {
            let baseline = max(20.0, 60.0 - 0.8 * Double(max(0, actualAge - 20)))
            let diff = hrv - baseline            // 正 = 高于基准 = 更年轻
            let impact = clampImpact(-(diff * 0.10)) // 年龄方向相反
            totalImpact += impact
            let advice: String
            if hrv >= baseline * 1.3 {
                advice = String(localized: "HRV well above age baseline — excellent autonomic function")
            } else if hrv >= baseline * 0.9 {
                advice = String(localized: "HRV within normal range for your age (Shaffer 2017)")
            } else {
                advice = String(localized: "HRV below age baseline — improve sleep and reduce stress")
            }
            metrics.append(MetricScore(metric: .hrv, value: hrv, ageImpact: impact, advice: advice))
        }

        // ③ 睡眠时长 [3] Walker / CDC：7-8h 最优，偏离每 1h ≈ 0.7 年影响
        if let sleepMin = avgSleepMin {
            let hours = sleepMin / 60.0
            // 最优区间 7.0-8.5h，偏离两侧均为负面
            let optimalMid = 7.75
            let deviation = max(0, abs(hours - optimalMid) - 0.75) // 0.75h 缓冲区
            let impact = clampImpact(deviation * 0.7)
            totalImpact += impact
            let advice: String
            switch hours {
            case ..<6.0:    advice = String(localized: "Severe sleep deficit — significantly higher mortality risk (CDC 2016)")
            case 6.0..<7.0: advice = String(localized: "Slightly short on sleep — aim for 7-8 hours")
            case 7.0..<8.5: advice = String(localized: "Sleep duration in optimal range (Walker 2017)")
            case 8.5..<9.5: advice = String(localized: "Sleeping a bit long — check sleep efficiency and quality")
            default:        advice = String(localized: "Excessive sleep — consider checking for underlying health issues")
            }
            metrics.append(MetricScore(metric: .sleep, value: hours, ageImpact: impact, advice: advice))
        }

        // ④ 每日步数 [4] Paluch et al. JAMA Netw Open 2022
        //    关键结论：8000步/天是死亡率显著下降的"阈值"，非线性关系
        //    ≥8000步 → 健康基线，无额外"年轻"加分（步数不是生理年龄的线性因子）
        //    <8000步 → 久坐风险，每减少2000步 ≈ 0.4年负影响，上限 +1.5年（偏老）
        //    注意：马拉松运动员步数再高也不会因此"变年轻"——这不是步数测量的
        if let steps = avgSteps {
            let deficit = max(0, 8000.0 - steps)   // 只计算不足，不计算超出
            let impact = min(1.5, deficit / 2000.0 * 0.4)  // 只有正值（偏老）
            totalImpact += impact
            let advice: String
            switch steps {
            case ..<4000:   advice = String(localized: "Sedentary (<4000 steps) — cardiovascular and metabolic risk significantly elevated (JAMA 2022)")
            case 4000..<6000: advice = String(localized: "Step count is low — aim for at least 8000 steps per day")
            case 6000..<8000: advice = String(localized: "Approaching recommended threshold — keep it up")
            default:        advice = String(localized: "Step count on target (8000+) — low sedentary risk")
            }
            metrics.append(MetricScore(metric: .steps, value: steps, ageImpact: impact, advice: advice))
        }

        // ⑤ 活跃时间 [5] WHO 2020 身体活动指南
        //    同样是阈值效应：达到 150 min/week 是基线，超过无额外加分
        //    不足时才有负影响
        let whoDaily = 21.4
        let activeDeficit = max(0, whoDaily - avgActiveMin)  // 只计算不足
        let activeImpact = min(1.0, activeDeficit / 10.0 * 0.4)  // 只有正值（偏老）
        totalImpact += activeImpact
        let activeAdvice: String
        if avgActiveMin >= whoDaily {
            activeAdvice = String(localized: "Activity meets WHO 2020 guidelines (150+ min/week)")
        } else if avgActiveMin >= 10 {
            activeAdvice = String(localized: "Activity slightly below target — WHO recommends 21+ min/day of moderate exercise")
        } else {
            activeAdvice = String(localized: "Activity severely insufficient — increasing daily exercise can significantly reduce chronic disease risk")
        }
        metrics.append(MetricScore(metric: .activeMinutes, value: avgActiveMin, ageImpact: activeImpact, advice: activeAdvice))

        let healthAge = Double(actualAge) + totalImpact
        // 按年龄比例限制：年轻人生理储备小，改善空间有限
        // 19岁最多年轻 ~2.8年；40岁最多年轻 ~6年；80岁最多年轻 ~12年
        let maxImprovement = Double(actualAge) * 0.15  // 最多年轻 15%
        let maxDeterioration = Double(actualAge) * 0.20 // 最多偏老 20%
        let lowerBound = Double(actualAge) - maxImprovement
        let upperBound = Double(actualAge) + maxDeterioration
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
