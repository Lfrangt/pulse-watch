import Foundation
import SwiftData

/// 训练挑战 — 如 "30天俯卧撑挑战"
@Model
final class TrainingChallenge {
    var id: UUID
    var name: String                    // "30-Day Push-up Challenge"
    var challengeType: String           // "pushup", "steps", "workout_count", "custom"
    var targetPerDay: Int               // 每日目标量
    var durationDays: Int               // 持续天数
    var startDate: Date
    var completedDaysRaw: String?       // JSON encoded ["2026-03-01", "2026-03-02"]
    var isActive: Bool

    init(name: String, challengeType: String, targetPerDay: Int, durationDays: Int, startDate: Date = .now) {
        self.id = UUID()
        self.name = name
        self.challengeType = challengeType
        self.targetPerDay = targetPerDay
        self.durationDays = durationDays
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.isActive = true
    }

    // MARK: - 已完成天数

    var completedDays: Set<String> {
        get {
            guard let raw = completedDaysRaw,
                  let data = raw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return Set(arr)
        }
        set {
            completedDaysRaw = (try? String(data: JSONEncoder().encode(Array(newValue).sorted()), encoding: .utf8)) ?? nil
        }
    }

    func markCompleted(date: Date) {
        let key = DailySummary.dateFormatter.string(from: date)
        var days = completedDays
        days.insert(key)
        completedDays = days
    }

    func isCompleted(date: Date) -> Bool {
        let key = DailySummary.dateFormatter.string(from: date)
        return completedDays.contains(key)
    }

    // MARK: - 计算属性

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays - 1, to: startDate) ?? startDate
    }

    var completedCount: Int {
        completedDays.count
    }

    var progressPercent: Double {
        durationDays > 0 ? Double(completedCount) / Double(durationDays) : 0
    }

    var isExpired: Bool {
        Date.now > endDate
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: endDate).day ?? 0)
    }
}

// MARK: - 挑战类型

enum ChallengeType: String, CaseIterable {
    case pushup = "pushup"
    case steps = "steps"
    case workoutCount = "workout_count"
    case custom = "custom"

    var label: String {
        switch self {
        case .pushup: return String(localized: "俯卧撑挑战")
        case .steps: return String(localized: "步数挑战")
        case .workoutCount: return String(localized: "训练打卡")
        case .custom: return String(localized: "自定义")
        }
    }

    var icon: String {
        switch self {
        case .pushup: return "figure.strengthtraining.traditional"
        case .steps: return "figure.walk"
        case .workoutCount: return "dumbbell.fill"
        case .custom: return "star.fill"
        }
    }

    var defaultTarget: Int {
        switch self {
        case .pushup: return 100
        case .steps: return 10000
        case .workoutCount: return 1
        case .custom: return 1
        }
    }

    var defaultDuration: Int { 30 }
}
