import Foundation
import SwiftData
import os

/// AI 分析引擎 — 基于规则 + 统计的本地健康分析
/// 不依赖外部 API，所有计算在设备上完成
@Observable
final class HealthAnalyzer {

    static let shared = HealthAnalyzer()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "HealthAnalyzer")

    private init() {}

    // MARK: - 主入口：生成健康洞察

    /// 从 HealthDataService 读取数据，生成结构化洞察
    @MainActor
    func generateInsight() -> HealthInsight {
        let dataService = HealthDataService.shared
        let today = dataService.fetchTodaySummary()
        let week = dataService.fetchWeekTrend(days: 7)
        let month = dataService.fetchWeekTrend(days: 30)
        let vitals = dataService.getLatestVitals()

        // 睡眠评分
        let sleepScore = calculateSleepScore(
            durationMinutes: today?.sleepDurationMinutes ?? 0,
            deepMinutes: today?.deepSleepMinutes ?? 0,
            remMinutes: today?.remSleepMinutes ?? 0,
            recentSummaries: week
        )

        // 恢复评分（综合 HRV 趋势 + 静息心率变化 + 睡眠质量）
        let recoveryScore = calculateRecoveryScore(
            currentHRV: vitals.hrv,
            currentRHR: vitals.restingHeartRate,
            sleepScore: sleepScore,
            recentSummaries: week
        )

        // 训练建议
        let trainingAdvice = determineTrainingAdvice(recoveryScore: recoveryScore)

        // 趋势分析
        let trends = analyzeTrends(week: week, month: month)

        // 异常检测（基于个人基线标准差）
        let anomalies = detectAnomalies(current: today, vitals: vitals, history: week)

        // 自然语言洞察
        let insights = generateNaturalLanguageInsights(
            recoveryScore: recoveryScore,
            sleepScore: sleepScore,
            trainingAdvice: trainingAdvice,
            trends: trends,
            anomalies: anomalies,
            vitals: vitals
        )

        return HealthInsight(
            recoveryScore: recoveryScore,
            sleepScore: sleepScore,
            trainingAdvice: trainingAdvice,
            trends: trends,
            insights: insights,
            anomalies: anomalies,
            generatedAt: .now
        )
    }

    // MARK: - 恢复评分算法 (0-100)

    /// 综合 HRV 趋势、静息心率变化、睡眠质量计算恢复评分
    private func calculateRecoveryScore(
        currentHRV: Double?,
        currentRHR: Double?,
        sleepScore: Int,
        recentSummaries: [DailySummary]
    ) -> Int {
        var score: Double = 0
        var weights: Double = 0

        // === HRV 趋势分量 (权重 40%) ===
        if let hrv = currentHRV {
            let hrvValues = recentSummaries.compactMap(\.averageHRV)
            let hrvComponent: Double

            if hrvValues.count >= 3 {
                let baseline = hrvValues.reduce(0, +) / Double(hrvValues.count)
                let stdDev = standardDeviation(hrvValues)
                let zScore = stdDev > 0 ? (hrv - baseline) / stdDev : 0

                // z-score 映射到 0-100
                // z = +2 → 100, z = 0 → 65, z = -2 → 20
                hrvComponent = clamp(65 + zScore * 17.5, min: 0, max: 100)
            } else {
                // 无历史数据，用绝对值估算
                hrvComponent = absoluteHRVScore(hrv)
            }

            score += hrvComponent * 0.4
            weights += 0.4
        }

        // === 静息心率变化分量 (权重 30%) ===
        if let rhr = currentRHR {
            let rhrValues = recentSummaries.compactMap(\.restingHeartRate)
            let rhrComponent: Double

            if rhrValues.count >= 3 {
                let baseline = rhrValues.reduce(0, +) / Double(rhrValues.count)
                let stdDev = standardDeviation(rhrValues)
                let zScore = stdDev > 0 ? (baseline - rhr) / stdDev : 0  // 注意：RHR 越低越好，所以反转

                rhrComponent = clamp(65 + zScore * 17.5, min: 0, max: 100)
            } else {
                rhrComponent = absoluteRHRScore(rhr)
            }

            score += rhrComponent * 0.3
            weights += 0.3
        }

        // === 睡眠质量分量 (权重 30%) ===
        score += Double(sleepScore) * 0.3
        weights += 0.3

        // 归一化
        let finalScore = weights > 0 ? score / weights : 50
        return clamp(Int(finalScore.rounded()), min: 0, max: 100)
    }

    // MARK: - 睡眠评分算法 (0-100)

    /// 综合时长 + 规律性 + 深睡比例估算
    private func calculateSleepScore(
        durationMinutes: Int,
        deepMinutes: Int,
        remMinutes: Int,
        recentSummaries: [DailySummary]
    ) -> Int {
        guard durationMinutes > 0 else { return 0 }

        // === 时长评分 (0-40) ===
        // 最佳区间 7-9 小时
        let durationScore: Double
        let hours = Double(durationMinutes) / 60.0
        switch hours {
        case 7.0...9.0:
            durationScore = 40  // 黄金区间满分
        case 6.5..<7.0:
            durationScore = 35
        case 9.0..<10.0:
            durationScore = 35  // 过长也轻微扣分
        case 6.0..<6.5:
            durationScore = 28
        case 5.0..<6.0:
            durationScore = 18
        case 10.0...:
            durationScore = 25  // 过长
        default:
            durationScore = max(5, hours / 5.0 * 10)
        }

        // === 深睡比例评分 (0-30) ===
        let deepRatio = durationMinutes > 0 ? Double(deepMinutes) / Double(durationMinutes) : 0
        let deepScore: Double
        switch deepRatio {
        case 0.20...:
            deepScore = 30      // 20%+ 深睡
        case 0.15..<0.20:
            deepScore = 25
        case 0.10..<0.15:
            deepScore = 18
        case 0.05..<0.10:
            deepScore = 10
        default:
            deepScore = 5
        }

        // === REM 比例评分 (0-15) ===
        let remRatio = durationMinutes > 0 ? Double(remMinutes) / Double(durationMinutes) : 0
        let remScore: Double
        switch remRatio {
        case 0.20...:
            remScore = 15
        case 0.15..<0.20:
            remScore = 12
        case 0.10..<0.15:
            remScore = 8
        default:
            remScore = 4
        }

        // === 规律性评分 (0-15) ===
        let regularityScore: Double
        let recentDurations = recentSummaries.compactMap(\.sleepDurationMinutes).filter { $0 > 0 }
        if recentDurations.count >= 3 {
            let stdDev = standardDeviation(recentDurations.map(Double.init))
            // 标准差越小越规律。stdDev < 30min → 满分，> 90min → 最低
            if stdDev < 30 {
                regularityScore = 15
            } else if stdDev < 45 {
                regularityScore = 12
            } else if stdDev < 60 {
                regularityScore = 8
            } else if stdDev < 90 {
                regularityScore = 5
            } else {
                regularityScore = 2
            }
        } else {
            regularityScore = 8  // 数据不足给中等分
        }

        return clamp(Int((durationScore + deepScore + remScore + regularityScore).rounded()), min: 0, max: 100)
    }

    // MARK: - 训练建议

    /// 根据恢复评分决定训练强度建议
    private func determineTrainingAdvice(recoveryScore: Int) -> TrainingAdvice {
        switch recoveryScore {
        case 80...:
            return .intense
        case 60..<80:
            return .moderate
        case 40..<60:
            return .light
        default:
            return .rest
        }
    }

    // MARK: - 趋势分析

    /// 7天 / 30天滑动平均，检测上升/下降/平稳趋势
    private func analyzeTrends(week: [DailySummary], month: [DailySummary]) -> TrendAnalysis {
        return TrendAnalysis(
            hrvTrend: calculateMetricTrend(
                weekValues: week.compactMap(\.averageHRV),
                monthValues: month.compactMap(\.averageHRV)
            ),
            rhrTrend: calculateMetricTrend(
                weekValues: week.compactMap(\.restingHeartRate),
                monthValues: month.compactMap(\.restingHeartRate),
                inverted: true  // RHR 下降是好趋势
            ),
            sleepTrend: calculateMetricTrend(
                weekValues: week.compactMap(\.sleepDurationMinutes).map(Double.init),
                monthValues: month.compactMap(\.sleepDurationMinutes).map(Double.init)
            ),
            scoreTrend: calculateMetricTrend(
                weekValues: week.compactMap(\.dailyScore).map(Double.init),
                monthValues: month.compactMap(\.dailyScore).map(Double.init)
            ),
            weekAvgScore: week.compactMap(\.dailyScore).isEmpty ? nil :
                Int(week.compactMap(\.dailyScore).map(Double.init).reduce(0, +) /
                    Double(week.compactMap(\.dailyScore).count)),
            monthAvgScore: month.compactMap(\.dailyScore).isEmpty ? nil :
                Int(month.compactMap(\.dailyScore).map(Double.init).reduce(0, +) /
                    Double(month.compactMap(\.dailyScore).count))
        )
    }

    /// 单项指标趋势计算
    private func calculateMetricTrend(
        weekValues: [Double],
        monthValues: [Double],
        inverted: Bool = false
    ) -> Trend {
        // 至少需要 3 天数据才判断趋势
        guard weekValues.count >= 3 else { return .insufficient }

        // 用简单线性回归斜率判断趋势
        let slope = linearRegressionSlope(weekValues)
        let mean = weekValues.reduce(0, +) / Double(weekValues.count)

        // 归一化斜率（相对于均值的百分比变化/天）
        guard mean != 0 else { return .stable }
        let normalizedSlope = slope / mean

        // 阈值：每天变化超过 2% 才算趋势
        let threshold = 0.02
        let effectiveSlope = inverted ? -normalizedSlope : normalizedSlope

        if effectiveSlope > threshold {
            return .improving
        } else if effectiveSlope < -threshold {
            return .declining
        } else {
            return .stable
        }
    }

    // MARK: - 异常检测（基于个人基线标准差）

    /// 基于个人基线的标准差方法检测异常（不是固定阈值）
    private func detectAnomalies(
        current: DailySummary?,
        vitals: LatestVitals,
        history: [DailySummary]
    ) -> [Anomaly] {
        var anomalies: [Anomaly] = []

        // 至少需要 5 天历史数据才建立基线
        guard history.count >= 5 else { return anomalies }

        // === HRV 异常检测 ===
        if let currentHRV = vitals.hrv {
            let hrvHistory = history.compactMap(\.averageHRV)
            if hrvHistory.count >= 5 {
                let mean = hrvHistory.reduce(0, +) / Double(hrvHistory.count)
                let sd = standardDeviation(hrvHistory)

                if sd > 0 {
                    let zScore = (currentHRV - mean) / sd

                    if zScore < -2.0 {
                        anomalies.append(Anomaly(
                            metric: .hrv,
                            severity: .high,
                            message: "HRV 显著偏低",
                            detail: "当前 \(Int(currentHRV))ms，低于个人基线 \(Int(mean))ms 超过 2 个标准差",
                            currentValue: currentHRV,
                            baselineValue: mean,
                            zScore: zScore
                        ))
                    } else if zScore < -1.5 {
                        anomalies.append(Anomaly(
                            metric: .hrv,
                            severity: .medium,
                            message: "HRV 偏低",
                            detail: "当前 \(Int(currentHRV))ms，低于个人均值 \(Int(mean))ms",
                            currentValue: currentHRV,
                            baselineValue: mean,
                            zScore: zScore
                        ))
                    }
                }
            }
        }

        // === 静息心率异常检测 ===
        if let currentRHR = vitals.restingHeartRate {
            let rhrHistory = history.compactMap(\.restingHeartRate)
            if rhrHistory.count >= 5 {
                let mean = rhrHistory.reduce(0, +) / Double(rhrHistory.count)
                let sd = standardDeviation(rhrHistory)

                if sd > 0 {
                    let zScore = (currentRHR - mean) / sd

                    if zScore > 2.0 {
                        anomalies.append(Anomaly(
                            metric: .restingHeartRate,
                            severity: .high,
                            message: "静息心率显著偏高",
                            detail: "当前 \(Int(currentRHR))bpm，高于个人基线 \(Int(mean))bpm 超过 2 个标准差",
                            currentValue: currentRHR,
                            baselineValue: mean,
                            zScore: zScore
                        ))
                    } else if zScore > 1.5 {
                        anomalies.append(Anomaly(
                            metric: .restingHeartRate,
                            severity: .medium,
                            message: "静息心率偏高",
                            detail: "当前 \(Int(currentRHR))bpm，高于个人均值 \(Int(mean))bpm",
                            currentValue: currentRHR,
                            baselineValue: mean,
                            zScore: zScore
                        ))
                    }
                }
            }
        }

        // === 睡眠异常检测 ===
        if let sleepMinutes = current?.sleepDurationMinutes, sleepMinutes > 0 {
            let sleepHistory = history.compactMap(\.sleepDurationMinutes).filter { $0 > 0 }.map(Double.init)
            if sleepHistory.count >= 5 {
                let mean = sleepHistory.reduce(0, +) / Double(sleepHistory.count)
                let sd = standardDeviation(sleepHistory)

                if sd > 0 {
                    let zScore = (Double(sleepMinutes) - mean) / sd

                    if zScore < -2.0 {
                        let hoursNow = sleepMinutes / 60
                        let minsNow = sleepMinutes % 60
                        let hoursAvg = Int(mean) / 60
                        let minsAvg = Int(mean) % 60

                        anomalies.append(Anomaly(
                            metric: .sleep,
                            severity: .high,
                            message: "睡眠严重不足",
                            detail: "昨晚 \(hoursNow)h\(minsNow)m，远低于你的平均 \(hoursAvg)h\(minsAvg)m",
                            currentValue: Double(sleepMinutes),
                            baselineValue: mean,
                            zScore: zScore
                        ))
                    }
                }
            }
        }

        // === 连续差睡眠检测 ===
        let recentSleep = history.suffix(3).compactMap(\.sleepDurationMinutes)
        if recentSleep.count == 3 && recentSleep.allSatisfy({ $0 > 0 && $0 < 360 }) {
            anomalies.append(Anomaly(
                metric: .sleep,
                severity: .high,
                message: "连续 3 晚睡眠不足",
                detail: "连续 3 晚不足 6 小时，累积睡眠债会影响恢复和表现",
                currentValue: Double(recentSleep.last ?? 0),
                baselineValue: 420,  // 7 小时参考值
                zScore: -3.0
            ))
        }

        return anomalies
    }

    // MARK: - 自然语言洞察生成

    private func generateNaturalLanguageInsights(
        recoveryScore: Int,
        sleepScore: Int,
        trainingAdvice: TrainingAdvice,
        trends: TrendAnalysis,
        anomalies: [Anomaly],
        vitals: LatestVitals
    ) -> [String] {
        var insights: [String] = []

        // 恢复状态总结
        switch recoveryScore {
        case 85...:
            insights.append("身体恢复非常好，今天是挑战自我的好时机")
        case 70..<85:
            insights.append("恢复状态良好，可以正常安排训练")
        case 50..<70:
            insights.append("恢复中等，建议适度训练，注意倾听身体")
        case 30..<50:
            insights.append("身体仍在恢复，建议轻松活动如散步或瑜伽")
        default:
            insights.append("身体需要充分休息，今天建议完全休息")
        }

        // 睡眠洞察
        if sleepScore > 0 {
            if sleepScore >= 80 {
                insights.append("昨晚睡眠质量很好，为今天打下了好基础")
            } else if sleepScore < 40 {
                insights.append("睡眠质量较差，今天可能精力不足，注意补觉")
            }
        }

        // 趋势洞察
        if trends.hrvTrend == .improving {
            insights.append("HRV 近期呈上升趋势，身体适应能力在增强")
        } else if trends.hrvTrend == .declining {
            insights.append("HRV 近期有下降趋势，注意控制训练量和压力")
        }

        if trends.rhrTrend == .declining {
            insights.append("静息心率近期偏高，可能是疲劳或压力信号")
        }

        // 异常洞察
        for anomaly in anomalies.prefix(2) {
            if anomaly.severity == .high {
                insights.append(anomaly.message + "：" + anomaly.detail)
            }
        }

        return insights
    }

    // MARK: - 统计工具

    /// 标准差
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }

    /// 简单线性回归斜率
    private func linearRegressionSlope(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n > 1 else { return 0 }

        let xs = (0..<values.count).map(Double.init)
        let xMean = xs.reduce(0, +) / n
        let yMean = values.reduce(0, +) / n

        var numerator: Double = 0
        var denominator: Double = 0

        for i in 0..<values.count {
            let xDiff = xs[i] - xMean
            let yDiff = values[i] - yMean
            numerator += xDiff * yDiff
            denominator += xDiff * xDiff
        }

        return denominator != 0 ? numerator / denominator : 0
    }

    /// HRV 绝对值评分（无历史数据时使用）
    private func absoluteHRVScore(_ hrv: Double) -> Double {
        switch hrv {
        case 80...: return 90
        case 65..<80: return 78
        case 50..<65: return 65
        case 35..<50: return 50
        case 20..<35: return 35
        default: return 20
        }
    }

    /// RHR 绝对值评分（无历史数据时使用）
    private func absoluteRHRScore(_ rhr: Double) -> Double {
        switch rhr {
        case ..<50: return 90
        case 50..<55: return 82
        case 55..<60: return 72
        case 60..<65: return 62
        case 65..<70: return 50
        case 70..<80: return 38
        default: return 25
        }
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }

    private func clamp(_ value: Int, min: Int, max: Int) -> Int {
        Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - 数据模型

/// 健康分析结果
struct HealthInsight {
    /// 恢复评分 (0-100)
    let recoveryScore: Int
    /// 睡眠评分 (0-100)
    let sleepScore: Int
    /// 训练建议
    let trainingAdvice: TrainingAdvice
    /// 趋势分析
    let trends: TrendAnalysis
    /// 自然语言洞察列表
    let insights: [String]
    /// 检测到的异常
    let anomalies: [Anomaly]
    /// 生成时间
    let generatedAt: Date

    /// 综合每日评分
    var dailyScore: Int {
        // 恢复 60% + 睡眠 40%
        let score = Double(recoveryScore) * 0.6 + Double(sleepScore) * 0.4
        return max(0, min(100, Int(score.rounded())))
    }
}

/// 训练建议等级
enum TrainingAdvice: String, Codable {
    case intense    // 高强度
    case moderate   // 中等
    case light      // 轻松恢复
    case rest       // 休息

    var label: String {
        switch self {
        case .intense:  return "高强度训练"
        case .moderate: return "中等强度"
        case .light:    return "轻松恢复"
        case .rest:     return "完全休息"
        }
    }

    var icon: String {
        switch self {
        case .intense:  return "flame.fill"
        case .moderate: return "figure.run"
        case .light:    return "figure.walk"
        case .rest:     return "bed.double.fill"
        }
    }
}

/// 趋势方向
enum Trend: String {
    case improving   // 上升
    case stable      // 平稳
    case declining   // 下降
    case insufficient // 数据不足

    var label: String {
        switch self {
        case .improving:    return "上升趋势"
        case .stable:       return "保持平稳"
        case .declining:    return "下降趋势"
        case .insufficient: return "数据不足"
        }
    }

    var icon: String {
        switch self {
        case .improving:    return "arrow.up.right"
        case .stable:       return "arrow.right"
        case .declining:    return "arrow.down.right"
        case .insufficient: return "questionmark"
        }
    }
}

/// 趋势分析结果
struct TrendAnalysis {
    let hrvTrend: Trend
    let rhrTrend: Trend
    let sleepTrend: Trend
    let scoreTrend: Trend
    let weekAvgScore: Int?
    let monthAvgScore: Int?
}

/// 检测到的异常
struct Anomaly: Identifiable {
    let id = UUID()
    let metric: AnomalyMetric
    let severity: AnomalySeverityLevel
    let message: String
    let detail: String
    let currentValue: Double
    let baselineValue: Double
    let zScore: Double
}

/// 异常指标类型
enum AnomalyMetric: String {
    case hrv = "HRV"
    case restingHeartRate = "静息心率"
    case sleep = "睡眠"
    case bloodOxygen = "血氧"
}

/// 异常严重等级
enum AnomalySeverityLevel: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: AnomalySeverityLevel, rhs: AnomalySeverityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
