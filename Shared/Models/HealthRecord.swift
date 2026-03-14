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

    var displayName: String {
        switch self {
        case .heartRate: return "心率"
        case .heartRateVariability: return "心率变异性"
        case .restingHeartRate: return "静息心率"
        case .bloodOxygen: return "血氧"
        case .stepCount: return "步数"
        case .activeCalories: return "活跃卡路里"
        case .restingCalories: return "静息卡路里"
        case .sleepAnalysis: return "睡眠"
        }
    }

    var unit: String {
        switch self {
        case .heartRate, .restingHeartRate: return "bpm"
        case .heartRateVariability: return "ms"
        case .bloodOxygen: return "%"
        case .stepCount: return "步"
        case .activeCalories, .restingCalories: return "kcal"
        case .sleepAnalysis: return "分钟"
        }
    }
}

/// 单条健康数据记录 — 从 HealthKit 采集后写入 SwiftData
@Model
final class HealthRecord {
    var id: UUID
    var metricType: String               // HealthMetricType.rawValue
    var value: Double
    var timestamp: Date
    var source: String                   // 数据来源（Apple Watch、iPhone 等）
    var anchorKey: String?               // 用于 Anchored Object Query 去重

    /// 方便类型安全访问
    var metric: HealthMetricType? {
        HealthMetricType(rawValue: metricType)
    }

    init(
        metricType: HealthMetricType,
        value: Double,
        timestamp: Date = .now,
        source: String = "HealthKit"
    ) {
        self.id = UUID()
        self.metricType = metricType.rawValue
        self.value = value
        self.timestamp = timestamp
        self.source = source
    }
}
