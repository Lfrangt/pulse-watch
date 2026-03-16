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
            insight: String(localized: "身体恢复不错，适合中等强度训练"),
            sleepSummary: "7h12m",
            recoveryNote: nil,
            trainingPlan: TrainingPlan(
                targetMuscleGroup: "chest",
                daysSinceLastTrained: 3,
                suggestedExercises: [
                    SuggestedExercise(name: String(localized: "平板卧推"), sets: 4, reps: 8, suggestedWeight: 80),
                    SuggestedExercise(name: String(localized: "上斜哑铃卧推"), sets: 3, reps: 10, suggestedWeight: 30),
                    SuggestedExercise(name: String(localized: "绳索飞鸟"), sets: 3, reps: 12, suggestedWeight: 15),
                ],
                intensity: .moderate,
                reason: String(localized: "上次练胸是3天前")
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
                String(localized: "HRV 趋势上升 12%"),
                String(localized: "睡眠连续 3 天超 7 小时"),
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
                title: String(localized: "入睡"),
                detail: String(localized: "总计 7h12m · 深睡约 1.8h"),
                impact: String(localized: "恢复 +15"),
                impactPositive: true,
                color: Color(hex: "8B7EC8")
            ),
            TimelineEvent(
                time: wakeTime,
                icon: "sunrise.fill",
                title: String(localized: "醒来"),
                detail: String(localized: "静息心率 58bpm"),
                impact: String(localized: "恢复良好"),
                impactPositive: true,
                color: PulseTheme.statusGood
            ),
            TimelineEvent(
                time: activityTime,
                icon: "figure.walk",
                title: String(localized: "日间活动"),
                detail: String(localized: "8.4k 步 · 活跃卡路里 +320kcal"),
                impact: String(localized: "活跃 +"),
                impactPositive: true,
                color: PulseTheme.accent
            ),
            TimelineEvent(
                time: now,
                icon: "heart.text.clipboard",
                title: String(localized: "当前状态"),
                detail: String(localized: "HRV 48ms ↑ · 中等强度"),
                impact: String(localized: "可以训练"),
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
}
