import Foundation
import SwiftData

/// 按天聚合的健康摘要 — 由 HealthKitService 每次后台采集时更新
/// dateString 使用 @Attribute(.unique) 保证数据库级唯一性，防止并发写入创建重复记录
@Model
final class DailySummary {
    var id: UUID
    @Attribute(.unique) var dateString: String  // "yyyy-MM-dd" 格式，数据库级唯一键
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

    // 压力��分
    var stressScore: Int?               // 0-100 (0=chill, 100=maxed out)

    // ���新时间
    var lastUpdated: Date

    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.dateString = Self.dateFormatter.string(from: date)
        self.lastUpdated = .now
    }

    /// 共享的日期格式化器 — 使用 ISO8601DateFormatter（线程安全，无需加锁）
    static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        f.timeZone = .current
        return f
    }()
}
