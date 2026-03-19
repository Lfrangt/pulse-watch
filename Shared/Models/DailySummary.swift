import Foundation
import SwiftData

/// 按天聚合的健康摘要 — 由 HealthKitService 每次后台采集时更新
/// dateString 作为逻辑唯一键，在代码中通过 fetch + upsert 保证唯一性
@Model
final class DailySummary {
    var id: UUID
    var dateString: String               // "yyyy-MM-dd" 格式，用作唯一键
    var date: Date                       // 当天 00:00:00

    // 心率
    var averageHeartRate: Double?        // bpm
    var minHeartRate: Double?
    var maxHeartRate: Double?
    var restingHeartRate: Double?        // bpm

    // HRV
    var averageHRV: Double?             // ms (SDNN)

    // 血氧
    var averageBloodOxygen: Double?     // 百分比 0-100
    var minBloodOxygen: Double?

    // 活动
    var totalSteps: Int?
    var activeCalories: Double?         // kcal
    var exerciseMinutes: Double?        // Apple Watch appleExerciseTime（真实运动分钟，非估算）
    var restingCalories: Double?        // kcal
    var totalCalories: Double? {        // 活跃 + 静息
        guard let active = activeCalories else { return restingCalories }
        return active + (restingCalories ?? 0)
    }

    // 睡眠
    var sleepDurationMinutes: Int?
    var deepSleepMinutes: Int?
    var remSleepMinutes: Int?
    var coreSleepMinutes: Int?

    // 综合评分
    var dailyScore: Int?                // 0-100

    // 更新时间
    var lastUpdated: Date

    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.dateString = Self.dateFormatter.string(from: date)
        self.lastUpdated = .now
    }

    /// 共享的日期格式化器
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}
