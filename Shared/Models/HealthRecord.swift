import Foundation
import SwiftData

/// 健康数据记录类型
enum HealthMetricType: String, Codable, CaseIterable {
    case heartRate = "heartRate"                 // bpm
    case heartRateVariability = "hrv"            // ms (SDNN)
    case restingHeartRate = "restingHR"          // bpm
    case bloodOxygen = "bloodOxygen"             // 百分比 0-100
    case stepCount = "steps"                     // 步数
    case activeCalories = "activeCalories"       // kcal
    case restingCalories = "restingCalories"     // kcal
    case sleepAnalysis = "sleep"                 // 分钟
    case sleepDeep = "sleepDeep"                 // 深睡分钟
    case sleepREM = "sleepREM"                   // REM 分钟
    case sleepCore = "sleepCore"                 // 核心睡眠分钟
    case exerciseTime = "exerciseTime"           // 分钟（Apple Watch appleExerciseTime）

    var displayName: String {
        switch self {
        case .heartRate: return String(localized: "Heart Rate")
        case .heartRateVariability: return String(localized: "HRV")
        case .restingHeartRate: return String(localized: "Resting HR")
        case .bloodOxygen: return String(localized: "Blood Oxygen")
        case .stepCount: return String(localized: "Steps")
        case .activeCalories: return String(localized: "Active Calories")
        case .restingCalories: return String(localized: "Resting Calories")
        case .sleepAnalysis: return String(localized: "Sleep")
        case .sleepDeep: return String(localized: "Deep Sleep")
        case .sleepREM: return String(localized: "REM Sleep")
        case .sleepCore: return String(localized: "Core Sleep")
        case .exerciseTime: return String(localized: "Exercise Time")
        }
    }

    var unit: String {
        switch self {
        case .heartRate, .restingHeartRate: return "bpm"
        case .heartRateVariability: return "ms"
        case .bloodOxygen: return "%"
        case .stepCount: return "steps"
        case .activeCalories, .restingCalories: return "kcal"
        case .sleepAnalysis, .sleepDeep, .sleepREM, .sleepCore: return "min"
        case .exerciseTime: return "min"
        }
    }
}

/// 单条健康数据记录 — 从 HealthKit 采集后写入 SwiftData
@Model
final class HealthRecord {
    var id: UUID
    var metricType: String               // HealthMetricType.rawValue
    var value: Double
    @Attribute(.spotlight) var timestamp: Date  // 索引加速按日期范围查询
    var source: String                   // 数据来源（Apple Watch、iPhone 等）
    @Attribute(.unique) var sampleUUID: String  // HKSample.uuid 去重键

    /// 方便类型安全访问
    var metric: HealthMetricType? {
        HealthMetricType(rawValue: metricType)
    }

    init(
        metricType: HealthMetricType,
        value: Double,
        timestamp: Date = .now,
        source: String = "HealthKit",
        sampleUUID: String = UUID().uuidString
    ) {
        self.id = UUID()
        self.metricType = metricType.rawValue
        self.value = value
        self.timestamp = timestamp
        self.source = source
        self.sampleUUID = sampleUUID
    }
}
