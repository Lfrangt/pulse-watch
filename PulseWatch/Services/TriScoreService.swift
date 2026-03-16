import Foundation
import SwiftData
import os

/// 三大核心评分 — 对标 Oura 的 Sleep / Activity / Readiness
/// 综合 Health Score = Sleep×35% + Activity×30% + Readiness×35%
final class TriScoreService {

    static let shared = TriScoreService()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "TriScore")

    // MARK: - 结果模型

    struct TriScore {
        let sleep: ScoreDetail
        let activity: ScoreDetail
        let readiness: ScoreDetail

        /// 综合评分
        var overallScore: Int {
            let raw = Double(sleep.score) * 0.35 + Double(activity.score) * 0.30 + Double(readiness.score) * 0.35
            return max(0, min(100, Int(raw.rounded())))
        }
    }

    struct ScoreDetail {
        let score: Int              // 0-100
        let factors: [Factor]       // 各因素得分
        let advice: String          // 一句话建议

        struct Factor {
            let name: String
            let value: String       // 显示值
            let contribution: Int   // -20 到 +20 的贡献
            let weight: String      // "40%" 等权重描述
        }
    }

    // MARK: - 计算

    func compute(modelContext: ModelContext) -> TriScore? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        // 获取近7天数据作为基线
        let weekAgo = cal.date(byAdding: .day, value: -7, to: today)!
        let summaries: [DailySummary]
        let todayWorkouts: [WorkoutHistoryEntry]

        do {
            summaries = try modelContext.fetch(FetchDescriptor<DailySummary>(
                predicate: #Predicate<DailySummary> { $0.date >= weekAgo },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ))
            todayWorkouts = try modelContext.fetch(FetchDescriptor<WorkoutHistoryEntry>(
                predicate: #Predicate<WorkoutHistoryEntry> { $0.startDate >= yesterday },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            ))
        } catch {
            logger.error("数据查询失败: \(error.localizedDescription)")
            return nil
        }

        guard !summaries.isEmpty else { return nil }

        let todaySummary = summaries.first { cal.isDate($0.date, inSameDayAs: today) }
            ?? summaries.first { cal.isDate($0.date, inSameDayAs: yesterday) }
        guard let current = todaySummary else { return nil }

        // 基线均值
        let baselineHRV = avg(summaries.compactMap(\.averageHRV))
        let baselineRHR = avg(summaries.compactMap(\.restingHeartRate))

        let sleep = computeSleep(current: current)
        let activity = computeActivity(current: current, workouts: todayWorkouts)
        let readiness = computeReadiness(current: current, baselineHRV: baselineHRV, baselineRHR: baselineRHR, sleepScore: sleep.score)

        return TriScore(sleep: sleep, activity: activity, readiness: readiness)
    }

    // MARK: - Sleep Score (0-100)
    // 权重: 时长 40% + 深睡比例 30% + 静息心率 30%

    private func computeSleep(current: DailySummary) -> ScoreDetail {
        var total: Double = 0
        var factors: [ScoreDetail.Factor] = []

        // 1. 时长 (40%)
        let sleepMin = current.sleepDurationMinutes ?? 0
        let hours = Double(sleepMin) / 60.0
        let durationScore: Double
        switch sleepMin {
        case 450...:        durationScore = 40  // 7.5h+
        case 420..<450:     durationScore = 36  // 7h
        case 390..<420:     durationScore = 30  // 6.5h
        case 360..<390:     durationScore = 22  // 6h
        case 300..<360:     durationScore = 12  // 5h
        default:            durationScore = 4
        }
        total += durationScore
        factors.append(.init(
            name: String(localized: "Sleep Duration"),
            value: String(format: "%.1fh", hours),
            contribution: Int(durationScore - 20),
            weight: "40%"
        ))

        // 2. 深睡比例 (30%)
        let deepMin = current.deepSleepMinutes ?? 0
        let deepRatio = sleepMin > 0 ? Double(deepMin) / Double(sleepMin) : 0
        let deepScore: Double
        switch deepRatio {
        case 0.20...:  deepScore = 30
        case 0.15...:  deepScore = 24
        case 0.10...:  deepScore = 16
        default:       deepScore = 6
        }
        total += deepScore
        factors.append(.init(
            name: String(localized: "Deep Sleep"),
            value: "\(deepMin)m",
            contribution: Int(deepScore - 15),
            weight: "30%"
        ))

        // 3. 静息心率 (30%)
        let rhr = current.restingHeartRate
        let rhrScore: Double
        if let rhr {
            switch rhr {
            case ..<55:     rhrScore = 30
            case 55..<60:   rhrScore = 26
            case 60..<65:   rhrScore = 20
            case 65..<70:   rhrScore = 14
            default:        rhrScore = 6
            }
        } else {
            rhrScore = 15  // 无数据给中间值
        }
        total += rhrScore
        factors.append(.init(
            name: String(localized: "Resting Heart Rate"),
            value: rhr.map { String(format: "%.0f bpm", $0) } ?? "—",
            contribution: Int(rhrScore - 15),
            weight: "30%"
        ))

        let score = max(0, min(100, Int(total)))
        let advice: String
        switch score {
        case 80...: advice = String(localized: "Excellent sleep — well rested")
        case 60...: advice = String(localized: "Decent sleep — room to improve")
        case 40...: advice = String(localized: "Sleep could be better — try earlier bedtime")
        default:    advice = String(localized: "Poor sleep — prioritize rest tonight")
        }

        return ScoreDetail(score: score, factors: factors, advice: advice)
    }

    // MARK: - Activity Score (0-100)
    // 步数完成率 + 活跃分钟 + 训练记录 (+20)

    private func computeActivity(current: DailySummary, workouts: [WorkoutHistoryEntry]) -> ScoreDetail {
        var total: Double = 0
        var factors: [ScoreDetail.Factor] = []

        // 1. 步数 (40%)
        let steps = current.totalSteps ?? 0
        let stepRate = min(1.0, Double(steps) / 10000.0)
        let stepScore = stepRate * 40
        total += stepScore
        factors.append(.init(
            name: String(localized: "Daily Steps"),
            value: steps >= 1000 ? String(format: "%.1fk", Double(steps)/1000) : "\(steps)",
            contribution: Int(stepScore - 20),
            weight: "40%"
        ))

        // 2. 活跃卡路里 → 估算活跃分钟 (40%)
        let activeCal = current.activeCalories ?? 0
        let activeMin = activeCal / 5.0  // 粗算
        let activeRate = min(1.0, activeMin / 30.0)  // 30 min/day 目标
        let activeScore = activeRate * 40
        total += activeScore
        factors.append(.init(
            name: String(localized: "Active Minutes"),
            value: String(format: "%.0f min", activeMin),
            contribution: Int(activeScore - 20),
            weight: "40%"
        ))

        // 3. 训练记录 bonus (最多 +20)
        let hasWorkout = !workouts.isEmpty
        let workoutBonus: Double = hasWorkout ? 20 : 0
        total += workoutBonus
        factors.append(.init(
            name: String(localized: "Workout Completed"),
            value: hasWorkout ? "✅" : "—",
            contribution: Int(workoutBonus),
            weight: "+20"
        ))

        let score = max(0, min(100, Int(total)))
        let advice: String
        switch score {
        case 80...: advice = String(localized: "Great activity day — you crushed it")
        case 60...: advice = String(localized: "Good movement — try adding a walk")
        case 40...: advice = String(localized: "Below target — get moving!")
        default:    advice = String(localized: "Very low activity — any movement helps")
        }

        return ScoreDetail(score: score, factors: factors, advice: advice)
    }

    // MARK: - Readiness Score (0-100)
    // HRV vs 基线 + RHR vs 基线 + Sleep Score 加权

    private func computeReadiness(current: DailySummary, baselineHRV: Double?, baselineRHR: Double?, sleepScore: Int) -> ScoreDetail {
        var total: Double = 0
        var factors: [ScoreDetail.Factor] = []

        // 1. HRV vs 基线 (35%)
        let hrv = current.averageHRV
        let hrvScore: Double
        if let hrv, let baseline = baselineHRV, baseline > 0 {
            let ratio = hrv / baseline
            switch ratio {
            case 1.1...:   hrvScore = 35   // 高于基线 10%+
            case 0.95...:  hrvScore = 28   // 基线附近
            case 0.85...:  hrvScore = 18   // 低于基线 5-15%
            default:       hrvScore = 8    // 明显低于基线
            }
        } else {
            hrvScore = 17  // 无数据中间值
        }
        total += hrvScore
        let hrvDisplay = hrv.map { String(format: "%.0f ms", $0) } ?? "—"
        let baselineDisplay = baselineHRV.map { String(format: "(avg %.0f)", $0) } ?? ""
        factors.append(.init(
            name: "HRV",
            value: "\(hrvDisplay) \(baselineDisplay)",
            contribution: Int(hrvScore - 17),
            weight: "35%"
        ))

        // 2. RHR vs 基线 (30%)
        let rhr = current.restingHeartRate
        let rhrScore: Double
        if let rhr, let baseline = baselineRHR, baseline > 0 {
            let diff = rhr - baseline
            switch diff {
            case ..<(-3):  rhrScore = 30   // 低于基线 3+ bpm (好)
            case (-3)...2: rhrScore = 24   // 基线附近
            case 2...5:    rhrScore = 14   // 高于基线 (差)
            default:       rhrScore = 6    // 明显偏高
            }
        } else {
            rhrScore = 15
        }
        total += rhrScore
        let rhrDisplay = rhr.map { String(format: "%.0f bpm", $0) } ?? "—"
        factors.append(.init(
            name: String(localized: "Resting HR vs Baseline"),
            value: rhrDisplay,
            contribution: Int(rhrScore - 15),
            weight: "30%"
        ))

        // 3. Sleep Score 加权 (35%)
        let sleepContrib = Double(sleepScore) / 100.0 * 35.0
        total += sleepContrib
        factors.append(.init(
            name: String(localized: "Sleep Quality"),
            value: "\(sleepScore)/100",
            contribution: Int(sleepContrib - 17),
            weight: "35%"
        ))

        let score = max(0, min(100, Int(total)))
        let advice: String
        switch score {
        case 80...: advice = String(localized: "Fully recovered — ready for anything")
        case 60...: advice = String(localized: "Moderately recovered — train smart")
        case 40...: advice = String(localized: "Still recovering — go easy today")
        default:    advice = String(localized: "Low readiness — rest is recommended")
        }

        return ScoreDetail(score: score, factors: factors, advice: advice)
    }

    // MARK: - Demo

    static let demoTriScore = TriScore(
        sleep: ScoreDetail(score: 82, factors: [
            .init(name: "Sleep Duration", value: "7.5h", contribution: 16, weight: "40%"),
            .init(name: "Deep Sleep", value: "108m", contribution: 15, weight: "30%"),
            .init(name: "Resting Heart Rate", value: "58 bpm", contribution: 11, weight: "30%"),
        ], advice: "Excellent sleep — well rested"),
        activity: ScoreDetail(score: 68, factors: [
            .init(name: "Daily Steps", value: "8.4k", contribution: 14, weight: "40%"),
            .init(name: "Active Minutes", value: "35 min", contribution: 13, weight: "40%"),
            .init(name: "Workout Completed", value: "✅", contribution: 20, weight: "+20"),
        ], advice: "Good movement — try adding a walk"),
        readiness: ScoreDetail(score: 75, factors: [
            .init(name: "HRV", value: "48 ms (avg 45)", contribution: 11, weight: "35%"),
            .init(name: "Resting HR vs Baseline", value: "58 bpm", contribution: 9, weight: "30%"),
            .init(name: "Sleep Quality", value: "82/100", contribution: 12, weight: "35%"),
        ], advice: "Moderately recovered — train smart")
    )

    // MARK: - Helpers

    private func avg(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
