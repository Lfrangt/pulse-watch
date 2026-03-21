import Foundation
import SwiftData

/// 指标相关性分析服务 — 计算健康指标间 Pearson 相关系数
/// 揭示如 "睡眠充足时 HRV 更高" 等数据驱动洞察
@Observable
@MainActor
final class CorrelationService {

    static let shared = CorrelationService()
    private init() {}

    // MARK: - 公开接口

    /// 从 DailySummary 数据计算指标间相关性
    func computeCorrelations(summaries: [DailySummary]) -> [CorrelationResult] {
        guard summaries.count >= 14 else { return [] }

        let sorted = summaries.sorted { $0.date < $1.date }
        var results: [CorrelationResult] = []

        // 睡眠时长 vs HRV
        let sleepHours = sorted.map { Double($0.sleepDurationMinutes ?? 0) / 60.0 }
        let hrvValues = sorted.map { $0.averageHRV ?? 0 }
        if let r = pearson(sleepHours, hrvValues, minNonZero: 14) {
            results.append(CorrelationResult(
                metricA: .sleepDuration, metricB: .hrv,
                coefficient: r, sampleSize: sorted.count,
                insight: sleepHRVInsight(summaries: sorted, r: r)
            ))
        }

        // 睡眠时长 vs 每日评分
        let scores = sorted.map { Double($0.dailyScore ?? 0) }
        if let r = pearson(sleepHours, scores, minNonZero: 14) {
            results.append(CorrelationResult(
                metricA: .sleepDuration, metricB: .dailyScore,
                coefficient: r, sampleSize: sorted.count,
                insight: sleepScoreInsight(summaries: sorted, r: r)
            ))
        }

        // 深睡比例 vs 每日评分
        let deepRatios = sorted.map { s -> Double in
            guard let total = s.sleepDurationMinutes, total > 0,
                  let deep = s.deepSleepMinutes else { return 0 }
            return Double(deep) / Double(total)
        }
        if let r = pearson(deepRatios, scores, minNonZero: 14) {
            results.append(CorrelationResult(
                metricA: .deepSleepRatio, metricB: .dailyScore,
                coefficient: r, sampleSize: sorted.count,
                insight: deepSleepScoreInsight(r: r)
            ))
        }

        // 静息心率 vs HRV（通常负相关）
        let rhrValues = sorted.map { $0.restingHeartRate ?? 0 }
        if let r = pearson(rhrValues, hrvValues, minNonZero: 14) {
            results.append(CorrelationResult(
                metricA: .restingHR, metricB: .hrv,
                coefficient: r, sampleSize: sorted.count,
                insight: rhrHRVInsight(r: r)
            ))
        }

        // 步数 vs 睡眠质量（当天步数 vs 当晚睡眠）
        let steps = sorted.map { Double($0.totalSteps ?? 0) }
        if let r = pearson(steps, sleepHours, minNonZero: 14) {
            results.append(CorrelationResult(
                metricA: .steps, metricB: .sleepDuration,
                coefficient: r, sampleSize: sorted.count,
                insight: stepsSleepInsight(r: r)
            ))
        }

        // 运动分钟 vs 每日评分
        let exerciseMins = sorted.map { $0.exerciseMinutes ?? 0 }
        if let r = pearson(exerciseMins, scores, minNonZero: 14) {
            results.append(CorrelationResult(
                metricA: .exerciseMinutes, metricB: .dailyScore,
                coefficient: r, sampleSize: sorted.count,
                insight: exerciseScoreInsight(r: r)
            ))
        }

        // 按相关系数绝对值排序，最显著的在前
        return results
            .filter { abs($0.coefficient) > 0.2 }
            .sorted { abs($0.coefficient) > abs($1.coefficient) }
    }

    // MARK: - Pearson 相关系数

    /// 计算两个数组的 Pearson 相关系数
    /// minNonZero: 非零配对数据的最小数量
    private func pearson(_ x: [Double], _ y: [Double], minNonZero: Int) -> Double? {
        guard x.count == y.count else { return nil }

        // 过滤掉两端都为 0 的配对
        let pairs = zip(x, y).filter { $0.0 != 0 && $0.1 != 0 }
        guard pairs.count >= minNonZero else { return nil }

        let xVals = pairs.map(\.0)
        let yVals = pairs.map(\.1)
        let n = Double(xVals.count)

        let xMean = xVals.reduce(0, +) / n
        let yMean = yVals.reduce(0, +) / n

        var numerator: Double = 0
        var xDenominator: Double = 0
        var yDenominator: Double = 0

        for i in 0..<xVals.count {
            let xDiff = xVals[i] - xMean
            let yDiff = yVals[i] - yMean
            numerator += xDiff * yDiff
            xDenominator += xDiff * xDiff
            yDenominator += yDiff * yDiff
        }

        let denominator = sqrt(xDenominator * yDenominator)
        guard denominator > 0 else { return nil }

        let r = numerator / denominator
        // 数值范围保护
        return max(-1, min(1, r))
    }

    // MARK: - 自然语言洞察生成

    private func sleepHRVInsight(summaries: [DailySummary], r: Double) -> String {
        // 分组对比：睡眠 >= 7h vs < 7h 的 HRV 均值
        let good = summaries.filter { ($0.sleepDurationMinutes ?? 0) >= 420 }
        let poor = summaries.filter { ($0.sleepDurationMinutes ?? 0) > 0 && ($0.sleepDurationMinutes ?? 0) < 420 }

        let goodHRV = good.compactMap(\.averageHRV)
        let poorHRV = poor.compactMap(\.averageHRV)

        if !goodHRV.isEmpty && !poorHRV.isEmpty {
            let goodAvg = goodHRV.reduce(0, +) / Double(goodHRV.count)
            let poorAvg = poorHRV.reduce(0, +) / Double(poorHRV.count)
            let pctDiff = abs(goodAvg - poorAvg) / poorAvg * 100

            if goodAvg > poorAvg && pctDiff > 5 {
                return String(localized: "睡眠 ≥ 7h 时，HRV 平均高 \(Int(pctDiff))%")
            }
        }

        if r > 0.3 {
            return String(localized: "睡得越久，HRV 越高 — 睡眠是恢复的基石")
        } else if r < -0.3 {
            return String(localized: "睡眠时长与 HRV 呈负相关 — 可能存在睡眠质量问题")
        }
        return String(localized: "睡眠时长与 HRV 有一定关联")
    }

    private func sleepScoreInsight(summaries: [DailySummary], r: Double) -> String {
        let good = summaries.filter { ($0.sleepDurationMinutes ?? 0) >= 420 }
        let poor = summaries.filter { ($0.sleepDurationMinutes ?? 0) > 0 && ($0.sleepDurationMinutes ?? 0) < 420 }

        let goodScores = good.compactMap(\.dailyScore)
        let poorScores = poor.compactMap(\.dailyScore)

        if !goodScores.isEmpty && !poorScores.isEmpty {
            let goodAvg = goodScores.reduce(0, +) / goodScores.count
            let poorAvg = poorScores.reduce(0, +) / poorScores.count
            let diff = goodAvg - poorAvg

            if diff > 3 {
                return String(localized: "睡够 7h 的日子，评分平均高 \(diff) 分")
            }
        }

        if r > 0.3 {
            return String(localized: "充足睡眠 = 更高评分 — 优先保证睡眠")
        }
        return String(localized: "睡眠时长对每日评分有一定影响")
    }

    private func deepSleepScoreInsight(r: Double) -> String {
        if r > 0.3 {
            return String(localized: "深睡占比越高，第二天状态越好")
        } else if r > 0.15 {
            return String(localized: "深睡比例与评分有轻微正相关")
        }
        return String(localized: "深睡比例对评分有一定影响")
    }

    private func rhrHRVInsight(r: Double) -> String {
        if r < -0.3 {
            return String(localized: "静息心率越低，HRV 越高 — 心肺能力的体现")
        }
        return String(localized: "静息心率与 HRV 存在关联")
    }

    private func stepsSleepInsight(r: Double) -> String {
        if r > 0.2 {
            return String(localized: "活动量大的日子，往往睡得更好")
        } else if r < -0.2 {
            return String(localized: "步数过高可能影响睡眠 — 注意恢复")
        }
        return String(localized: "日间活动量与睡眠有一定关联")
    }

    private func exerciseScoreInsight(r: Double) -> String {
        if r > 0.2 {
            return String(localized: "坚持运动的日子，整体状态更好")
        }
        return String(localized: "运动时长对整体评分有一定影响")
    }
}

// MARK: - 数据模型

struct CorrelationResult: Identifiable {
    let id = UUID()
    let metricA: CorrelationMetric
    let metricB: CorrelationMetric
    let coefficient: Double         // Pearson r, -1 ~ +1
    let sampleSize: Int
    let insight: String             // 自然语言解读

    /// 相关性强度描述
    var strengthLabel: String {
        switch abs(coefficient) {
        case 0.7...: return String(localized: "强相关")
        case 0.5..<0.7: return String(localized: "中等相关")
        case 0.3..<0.5: return String(localized: "弱相关")
        default: return String(localized: "微弱")
        }
    }

    /// 相关性方向
    var isPositive: Bool { coefficient > 0 }
}

enum CorrelationMetric: String {
    case sleepDuration = "sleep_duration"
    case deepSleepRatio = "deep_sleep_ratio"
    case hrv = "hrv"
    case restingHR = "resting_hr"
    case dailyScore = "daily_score"
    case steps = "steps"
    case exerciseMinutes = "exercise_minutes"

    var label: String {
        switch self {
        case .sleepDuration: return String(localized: "睡眠时长")
        case .deepSleepRatio: return String(localized: "深睡比例")
        case .hrv: return "HRV"
        case .restingHR: return String(localized: "静息心率")
        case .dailyScore: return String(localized: "每日评分")
        case .steps: return String(localized: "步数")
        case .exerciseMinutes: return String(localized: "运动时长")
        }
    }

    var icon: String {
        switch self {
        case .sleepDuration, .deepSleepRatio: return "moon.fill"
        case .hrv: return "waveform.path.ecg"
        case .restingHR: return "heart.fill"
        case .dailyScore: return "chart.line.uptrend.xyaxis"
        case .steps: return "figure.walk"
        case .exerciseMinutes: return "figure.run"
        }
    }
}
