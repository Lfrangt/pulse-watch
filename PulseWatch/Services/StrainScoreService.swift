import Foundation
import SwiftData
import SwiftUI
import os

/// Strain Score — 当日运动负荷评分 (0-100)
/// 算法：心率区间加权求和 → Zone1×1 + Zone2×2 + Zone3×4 + Zone4×7 + Zone5×10 → 归一化到 0-100
final class StrainScoreService {

    static let shared = StrainScoreService()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "Strain")

    // Zone weights（与 HRZoneEntry names 匹配）
    private static let zoneWeights: [String: Double] = [
        "Warm-up":   1,   // Zone 1
        "Fat Burn":  2,   // Zone 2
        "Cardio":    4,   // Zone 3
        "Anaerobic": 7,   // Zone 4
        "Peak":      10,  // Zone 5
    ]

    /// 理论最大加权值（100% 在 Peak = 10.0）
    private static let maxWeighted: Double = 10.0

    // MARK: - 单次训练 Strain

    /// 计算单次训练的 Strain Score (0-100)
    static func computeForWorkout(_ entry: WorkoutHistoryEntry) -> Int {
        let zones = entry.heartRateZones
        guard !zones.isEmpty else { return 0 }

        var weighted: Double = 0
        for zone in zones {
            let w = zoneWeights[zone.name] ?? 1
            weighted += zone.percentage * w
        }

        // 归一化到 0-100
        let raw = (weighted / maxWeighted) * 100
        return max(0, min(100, Int(raw)))
    }

    // MARK: - 当日 Strain（所有训练合计）

    /// 计算今日所有训练合并的 Strain Score
    func todayStrain(modelContext: ModelContext) -> Int {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: .now)

        let workouts: [WorkoutHistoryEntry]
        do {
            let descriptor = FetchDescriptor<WorkoutHistoryEntry>(
                predicate: #Predicate<WorkoutHistoryEntry> { $0.startDate >= startOfDay },
                sortBy: [SortDescriptor(\.startDate)]
            )
            workouts = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch today workouts: \(error.localizedDescription)")
            return 0
        }

        guard !workouts.isEmpty else { return 0 }

        // 合并所有训练的 zone 百分比（按时长加权）
        var totalDuration: Double = 0
        var mergedWeighted: Double = 0

        for w in workouts {
            let dur = w.durationSeconds
            totalDuration += dur
            let zones = w.heartRateZones
            for zone in zones {
                let weight = Self.zoneWeights[zone.name] ?? 1
                mergedWeighted += zone.percentage * weight * dur
            }
        }

        guard totalDuration > 0 else { return 0 }

        // 平均加权值
        let avgWeighted = mergedWeighted / totalDuration
        let raw = (avgWeighted / Self.maxWeighted) * 100

        // Duration bonus: 超过 60 分钟的训练给额外 bonus（最多 +15）
        let durationMinutes = totalDuration / 60
        let durationBonus = min(15, max(0, (durationMinutes - 30) * 0.3))

        let score = raw + durationBonus
        return max(0, min(100, Int(score)))
    }

    /// Demo 模式的 strain
    static let demoStrain: Int = 62

    // MARK: - Strain Level

    enum StrainLevel {
        case light      // 0-33
        case moderate   // 34-66
        case intense    // 67-100

        init(score: Int) {
            switch score {
            case 0...33:  self = .light
            case 34...66: self = .moderate
            default:      self = .intense
            }
        }

        var label: String {
            switch self {
            case .light:    return String(localized: "Light")
            case .moderate: return String(localized: "Moderate Strain")
            case .intense:  return String(localized: "High Strain")
            }
        }

        var color: String {
            switch self {
            case .light:    return "7FC75C"  // green
            case .moderate: return "D4A056"  // yellow
            case .intense:  return "C75C5C"  // red
            }
        }

        var pulseColor: Color {
            switch self {
            case .light:    return PulseTheme.statusGood
            case .moderate: return PulseTheme.statusWarning
            case .intense:  return PulseTheme.statusPoor
            }
        }
    }

    // MARK: - Strain vs Recovery 提示

    /// 当 Strain > Recovery + 30 时返回休息提示
    static func overtrainWarning(strain: Int, recovery: Int) -> String? {
        guard strain > recovery + 30 else { return nil }
        return String(localized: "High strain vs low recovery — consider resting tomorrow")
    }
}
