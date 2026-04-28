import Foundation
import SwiftUI

// MARK: - MuscleGroup

enum MuscleGroup: String, CaseIterable, Codable, Identifiable {
    case chest      = "chest"
    case back       = "back"
    case legs       = "legs"
    case shoulders  = "shoulders"
    case arms       = "arms"
    case core       = "core"
    case fullBody   = "fullBody"
    case cardio     = "cardio"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest:     return String(localized: "Chest")
        case .back:      return String(localized: "Back")
        case .legs:      return String(localized: "Legs")
        case .shoulders: return String(localized: "Shoulders")
        case .arms:      return String(localized: "Arms")
        case .core:      return String(localized: "Core")
        case .fullBody:  return String(localized: "Full Body")
        case .cardio:    return String(localized: "Cardio")
        }
    }

    var emoji: String {
        switch self {
        case .chest:     return "💪"
        case .back:      return "🔙"
        case .legs:      return "🦵"
        case .shoulders: return "🏋️"
        case .arms:      return "💪"
        case .core:      return "🎯"
        case .fullBody:  return "⚡"
        case .cardio:    return "🏃"
        }
    }

    var color: Color {
        switch self {
        case .chest:     return Color(hex: "C75C5C")
        case .back:      return PulseTheme.hrvBlue
        case .legs:      return Color(hex: "7FC75C")
        case .shoulders: return Color(hex: "C7A05C")
        case .arms:      return Color(hex: "C75C9E")
        case .core:      return Color(hex: "5CC7C1")
        case .fullBody:  return Color(hex: "8B5CC7")
        case .cardio:    return Color(hex: "C7735C")
        }
    }
}

// MARK: - MuscleInsightEngine

/// 分析训练部位与 HRV/睡眠恢复的关联
struct MuscleInsightEngine {

    struct Insight: Identifiable {
        let id = UUID()
        let muscleGroup: MuscleGroup
        let insightType: InsightType
        let value: Double       // 变化值（百分比或分钟）
        let sampleCount: Int

        enum InsightType {
            case hrvChange      // HRV 变化（次日）
            case sleepChange    // 睡眠时长变化（当晚）
        }

        var description: String {
            switch insightType {
            case .hrvChange:
                let direction = value > 0 ? String(localized: "increases") : String(localized: "decreases")
                let abs = String(format: "%.0f%%", abs(value))
                return String(format: String(localized: "After %@, your HRV %@ by %@ next day"),
                              muscleGroup.label, direction, abs)
            case .sleepChange:
                let direction = value > 0 ? String(localized: "improves") : String(localized: "decreases")
                let mins = String(format: "%.0f min", abs(value))
                return String(format: String(localized: "After %@, sleep %@ by %@ that night"),
                              muscleGroup.label, direction, mins)
            }
        }

        var isPositive: Bool {
            switch insightType {
            case .hrvChange:   return value > 0
            case .sleepChange: return value > 0
            }
        }
    }

    static let minSamples = 5

    /// 计算所有肌群的关联洞察
    static func compute(
        workouts: [WorkoutHistoryEntry],
        summaries: [DailySummary]
    ) -> [Insight] {
        var insights: [Insight] = []
        let cal = Calendar.current
        let summaryMap = Dictionary(uniqueKeysWithValues: summaries.compactMap { s -> (String, DailySummary)? in
            return (DailySummary.dateFormatter.string(from: s.date), s)
        })

        for group in MuscleGroup.allCases {
            let tagged = workouts.filter { $0.muscleGroupTags.contains(group) }
            guard tagged.count >= minSamples else { continue }

            // HRV 次日变化
            var hrvDeltas: [Double] = []
            for w in tagged {
                let trainDate = DailySummary.dateFormatter.string(from: w.startDate)
                let nextDate = DailySummary.dateFormatter.string(
                    from: cal.date(byAdding: .day, value: 1, to: w.startDate)!
                )
                guard let trainSummary = summaryMap[trainDate],
                      let nextSummary = summaryMap[nextDate],
                      let baseHRV = trainSummary.averageHRV,
                      let nextHRV = nextSummary.averageHRV,
                      baseHRV > 0 else { continue }
                hrvDeltas.append((nextHRV - baseHRV) / baseHRV * 100)
            }
            if hrvDeltas.count >= minSamples {
                let avg = hrvDeltas.reduce(0, +) / Double(hrvDeltas.count)
                insights.append(Insight(muscleGroup: group, insightType: .hrvChange,
                                        value: avg, sampleCount: hrvDeltas.count))
            }

            // 睡眠当晚变化（vs 本人平均）
            let allSleepMins = summaries.compactMap(\.sleepDurationMinutes).map(Double.init)
            guard !allSleepMins.isEmpty else { continue }
            let avgSleep = allSleepMins.reduce(0, +) / Double(allSleepMins.count)

            var sleepDeltas: [Double] = []
            for w in tagged {
                let trainDate = DailySummary.dateFormatter.string(from: w.startDate)
                guard let s = summaryMap[trainDate],
                      let mins = s.sleepDurationMinutes else { continue }
                sleepDeltas.append(Double(mins) - avgSleep)
            }
            if sleepDeltas.count >= minSamples {
                let avg = sleepDeltas.reduce(0, +) / Double(sleepDeltas.count)
                insights.append(Insight(muscleGroup: group, insightType: .sleepChange,
                                        value: avg, sampleCount: sleepDeltas.count))
            }
        }

        // 只返回最显著的 (|value| > 5% or 10min)，最多 6 条
        return insights
            .filter { ins in
                switch ins.insightType {
                case .hrvChange:   return abs(ins.value) > 3
                case .sleepChange: return abs(ins.value) > 5
                }
            }
            .sorted { abs($0.value) > abs($1.value) }
            .prefix(6)
            .map { $0 }
    }

    /// 数据不足时的占位洞察（展示积累进度）
    static func pendingInsights(workouts: [WorkoutHistoryEntry]) -> [(MuscleGroup, Int)] {
        return MuscleGroup.allCases.compactMap { group in
            let count = workouts.filter { $0.muscleGroupTags.contains(group) }.count
            guard count < minSamples && count > 0 else { return nil }
            return (group, count)
        }
    }
}
