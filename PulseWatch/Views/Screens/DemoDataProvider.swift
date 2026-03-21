import Foundation
import SwiftUI

/// 演示模式数据提供者 — 提供满数据的完美展示效果
enum DemoDataProvider {

    // MARK: - 评分与简报

    /// 演示模式的 DailyBrief
    static func makeBrief() -> ScoreEngine.DailyBrief {
        ScoreEngine.DailyBrief(
            score: 78,
            headline: PulseTheme.statusLabel(for: 78),
            insight: String(localized: "Good recovery — moderate intensity"),
            sleepSummary: "7h12m",
            recoveryNote: nil,
            trainingPlan: TrainingPlan(
                targetMuscleGroup: "chest",
                daysSinceLastTrained: 3,
                suggestedExercises: [
                    SuggestedExercise(name: String(localized: "Flat Bench Press"), sets: 4, reps: 8, suggestedWeight: 80),
                    SuggestedExercise(name: String(localized: "Incline Dumbbell Press"), sets: 3, reps: 10, suggestedWeight: 30),
                    SuggestedExercise(name: String(localized: "Cable Fly"), sets: 3, reps: 12, suggestedWeight: 15),
                ],
                intensity: .moderate,
                reason: String(localized: "Last chest day was 3 days ago")
            )
        )
    }

    /// 演示模式的 HealthInsight
    static func makeInsight() -> HealthInsight {
        HealthInsight(
            recoveryScore: 78,
            sleepScore: 82,
            trainingAdvice: .moderate,
            trends: TrendAnalysis(
                hrvTrend: .improving,
                rhrTrend: .stable,
                sleepTrend: .improving,
                scoreTrend: .improving,
                weekAvgScore: 75,
                monthAvgScore: 72
            ),
            insights: [
                String(localized: "HRV trending up 12%"),
                String(localized: "3+ consecutive nights over 7 hours"),
            ],
            anomalies: [],
            generatedAt: .now
        )
    }

    // MARK: - 指标数据

    static let heartRate: Double = 72
    static let hrv: Double = 48
    static let restingHR: Double = 58
    static let bloodOxygen: Double = 98
    static let steps: Int = 8430
    static let activeCalories: Double = 320
    static let sleepMinutes: Int = 432  // 7h12m

    // MARK: - 时间线事件

    static func makeTimelineEvents() -> [TimelineEvent] {
        let calendar = Calendar.current
        let now = Date()

        let bedtime = calendar.date(bySettingHour: 23, minute: 15, second: 0, of:
            calendar.date(byAdding: .day, value: -1, to: now)!
        )!

        let wakeTime = calendar.date(bySettingHour: 6, minute: 27, second: 0, of: now)!
        let activityTime = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: now)!

        return [
            TimelineEvent(
                time: bedtime,
                icon: "moon.fill",
                title: String(localized: "Asleep"),
                detail: String(localized: "Total 7h12m · Deep ~1.8h"),
                impact: String(localized: "Recovery +15"),
                impactPositive: true,
                color: PulseTheme.sleepAccent
            ),
            TimelineEvent(
                time: wakeTime,
                icon: "sunrise.fill",
                title: String(localized: "Awake"),
                detail: String(localized: "静息心率 58bpm"),
                impact: String(localized: "Good Recovery"),
                impactPositive: true,
                color: PulseTheme.statusGood
            ),
            TimelineEvent(
                time: activityTime,
                icon: "figure.walk",
                title: String(localized: "Daily Activity"),
                detail: String(localized: "8.4k steps · Active calories +320kcal"),
                impact: String(localized: "Active +"),
                impactPositive: true,
                color: PulseTheme.accent
            ),
            TimelineEvent(
                time: now,
                icon: "heart.text.clipboard",
                title: String(localized: "Current Status"),
                detail: String(localized: "HRV 48ms ↑ · Moderate"),
                impact: String(localized: "Ready to train"),
                impactPositive: true,
                color: PulseTheme.accent,
                isCurrent: true
            ),
        ]
    }

    // MARK: - 示例训练记录

    static func makeWorkoutRecords() -> [(category: String, date: Date, duration: Int)] {
        let cal = Calendar.current
        let now = Date()
        return [
            ("chest", cal.date(byAdding: .day, value: -3, to: now)!, 55),
            ("back", cal.date(byAdding: .day, value: -5, to: now)!, 50),
            ("legs", cal.date(byAdding: .day, value: -7, to: now)!, 60),
        ]
    }

    // MARK: - 相关性分析 Demo

    static func makeCorrelations() -> [CorrelationResult] {
        [
            CorrelationResult(
                metricA: .sleepDuration, metricB: .hrv,
                coefficient: 0.62, sampleSize: 28,
                insight: String(localized: "睡眠 ≥ 7h 时，HRV 平均高 18%")
            ),
            CorrelationResult(
                metricA: .sleepDuration, metricB: .dailyScore,
                coefficient: 0.55, sampleSize: 28,
                insight: String(localized: "睡够 7h 的日子，评分平均高 12 分")
            ),
            CorrelationResult(
                metricA: .restingHR, metricB: .hrv,
                coefficient: -0.48, sampleSize: 28,
                insight: String(localized: "静息心率越低，HRV 越高 — 心肺能力的体现")
            ),
            CorrelationResult(
                metricA: .exerciseMinutes, metricB: .dailyScore,
                coefficient: 0.35, sampleSize: 28,
                insight: String(localized: "坚持运动的日子，整体状态更好")
            ),
        ]
    }

    // MARK: - 异常时间线 Demo

    static func makeAnomalyDays() -> [(date: Date, anomalies: [Anomaly])] {
        let cal = Calendar.current
        let now = Date()
        return [
            (cal.date(byAdding: .day, value: -3, to: now)!, [
                Anomaly(metric: .hrv, severity: .medium,
                        message: String(localized: "HRV below baseline"),
                        detail: "Current 32ms, below avg 48ms",
                        currentValue: 32, baselineValue: 48, zScore: -1.6)
            ]),
            (cal.date(byAdding: .day, value: -8, to: now)!, [
                Anomaly(metric: .sleep, severity: .high,
                        message: String(localized: "Severe sleep deficit"),
                        detail: "Last night 4h30m, well below avg 7h12m",
                        currentValue: 270, baselineValue: 432, zScore: -2.3),
                Anomaly(metric: .restingHeartRate, severity: .medium,
                        message: String(localized: "Resting HR elevated"),
                        detail: "Current 68bpm, above avg 58bpm",
                        currentValue: 68, baselineValue: 58, zScore: 1.7)
            ]),
        ]
    }
}
