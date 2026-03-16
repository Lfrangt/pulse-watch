import Foundation
import SwiftData

/// 心率异常事件记录
@Model
final class HeartRateAlertEvent {

    /// 事件发生时间
    var timestamp: Date

    /// 触发时的心率值 (bpm)
    var heartRate: Double

    /// 异常类型: "high" 或 "low"
    var alertType: String

    /// 用户设置的阈值（记录触发时的阈值，便于历史追溯）
    var threshold: Double

    init(timestamp: Date = .now, heartRate: Double, alertType: String, threshold: Double) {
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.alertType = alertType
        self.threshold = threshold
    }
}
