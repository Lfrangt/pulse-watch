import Foundation
import SwiftData

/// 用户设定的健康目标 — 支持每日/每周维度的目标追踪
@Model
final class HealthGoal {
    var id: UUID
    var metricType: String          // "steps", "sleep_hours", "workout_count", "daily_score"
    var targetValue: Double         // 目标值
    var period: String              // "daily" 或 "weekly"
    var isActive: Bool
    var createdAt: Date

    init(metricType: String, targetValue: Double, period: String = "daily") {
        self.id = UUID()
        self.metricType = metricType
        self.targetValue = targetValue
        self.period = period
        self.isActive = true
        self.createdAt = .now
    }
}

// MARK: - 目标类型

enum GoalMetricType: String, CaseIterable {
    case steps = "steps"
    case sleepHours = "sleep_hours"
    case workoutCount = "workout_count"
    case dailyScore = "daily_score"

    var label: String {
        switch self {
        case .steps: return String(localized: "每日步数")
        case .sleepHours: return String(localized: "睡眠时长")
        case .workoutCount: return String(localized: "每周训练次数")
        case .dailyScore: return String(localized: "每日评分")
        }
    }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .sleepHours: return "moon.fill"
        case .workoutCount: return "dumbbell.fill"
        case .dailyScore: return "chart.line.uptrend.xyaxis"
        }
    }

    var unit: String {
        switch self {
        case .steps: return String(localized: "步")
        case .sleepHours: return "h"
        case .workoutCount: return String(localized: "次/周")
        case .dailyScore: return String(localized: "分")
        }
    }

    var defaultTarget: Double {
        switch self {
        case .steps: return 10000
        case .sleepHours: return 7.5
        case .workoutCount: return 4
        case .dailyScore: return 70
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .steps: return 3000...30000
        case .sleepHours: return 5...10
        case .workoutCount: return 1...7
        case .dailyScore: return 50...95
        }
    }

    var step: Double {
        switch self {
        case .steps: return 1000
        case .sleepHours: return 0.5
        case .workoutCount: return 1
        case .dailyScore: return 5
        }
    }

    var defaultPeriod: String {
        self == .workoutCount ? "weekly" : "daily"
    }
}
