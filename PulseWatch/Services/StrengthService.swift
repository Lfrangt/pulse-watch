import Foundation
import SwiftData
import os

/// 力量三大项评估服务
/// 深蹲/卧推/硬拉 — 体重倍数评级 + 综合力量评分
final class StrengthService {

    static let shared = StrengthService()

    // MARK: - Lift Types

    enum LiftType: String, CaseIterable, Identifiable {
        case squat = "squat"
        case bench = "bench"
        case deadlift = "deadlift"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .squat:    return String(localized: "Squat")
            case .bench:    return String(localized: "Bench Press")
            case .deadlift: return String(localized: "Deadlift")
            }
        }

        var icon: String {
            switch self {
            case .squat:    return "figure.strengthtraining.traditional"
            case .bench:    return "dumbbell.fill"
            case .deadlift: return "figure.strengthtraining.functional"
            }
        }

        var color: String {
            switch self {
            case .squat:    return "C75C5C"
            case .bench:    return "5C7BC7"
            case .deadlift: return "7FC75C"
            }
        }

        /// 体重倍数阈值 [beginner, intermediate, advanced, elite]
        var thresholds: [Double] {
            switch self {
            case .squat, .deadlift: return [1.0, 1.5, 2.0, 2.5]
            case .bench:            return [0.75, 1.0, 1.5, 2.0]
            }
        }
    }

    // MARK: - Strength Level

    enum StrengthLevel: Int, Comparable {
        case beginner = 0
        case intermediate = 1
        case advanced = 2
        case elite = 3

        static func < (lhs: StrengthLevel, rhs: StrengthLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var label: String {
            switch self {
            case .beginner:     return String(localized: "Beginner")
            case .intermediate: return String(localized: "Intermediate")
            case .advanced:     return String(localized: "Advanced")
            case .elite:        return String(localized: "Elite")
            }
        }

        var color: String {
            switch self {
            case .beginner:     return "8B8B8B"
            case .intermediate: return "D4A056"
            case .advanced:     return "5CC7C1"
            case .elite:        return "C75CC7"
            }
        }
    }

    // MARK: - Assessment

    struct LiftAssessment {
        let liftType: LiftType
        let best1RM: Double
        let bodyweightRatio: Double
        let level: StrengthLevel
        let nextLevelKg: Double?     // 距离下一级还差多少 kg
        let score: Int               // 0-25 per lift
    }

    struct StrengthAssessment {
        let lifts: [LiftAssessment]
        let totalScore: Int          // 0-100
        let totalLevel: StrengthLevel

        /// 三项合计 (estimated 1RM total)
        var total1RM: Double { lifts.map(\.best1RM).reduce(0, +) }
    }

    /// 评估力量水平
    func assess(records: [StrengthRecord], bodyweightKg: Double) -> StrengthAssessment? {
        guard bodyweightKg > 0 else { return nil }

        var assessments: [LiftAssessment] = []

        for type in LiftType.allCases {
            let typeRecords = records.filter { $0.liftType == type.rawValue }
            let best = typeRecords.max(by: { $0.estimated1RM < $1.estimated1RM })
            let best1RM = best?.estimated1RM ?? 0
            let ratio = best1RM / bodyweightKg

            let thresholds = type.thresholds
            let level: StrengthLevel
            let nextLevelKg: Double?

            switch ratio {
            case thresholds[3]...:
                level = .elite
                nextLevelKg = nil
            case thresholds[2]...:
                level = .advanced
                nextLevelKg = thresholds[3] * bodyweightKg - best1RM
            case thresholds[1]...:
                level = .intermediate
                nextLevelKg = thresholds[2] * bodyweightKg - best1RM
            case thresholds[0]...:
                level = .beginner
                nextLevelKg = thresholds[1] * bodyweightKg - best1RM
            default:
                level = .beginner
                nextLevelKg = thresholds[0] * bodyweightKg - best1RM
            }

            // 每项最多 25 分（按 ratio 线性插值到 elite 阈值）
            let maxRatio = thresholds[3]
            let score = min(25, Int((ratio / maxRatio) * 25))

            assessments.append(LiftAssessment(
                liftType: type,
                best1RM: best1RM,
                bodyweightRatio: ratio,
                level: level,
                nextLevelKg: nextLevelKg,
                score: score
            ))
        }

        let total = assessments.map(\.score).reduce(0, +)
        // 额外 25 分给综合表现（三项都有记录且都过 beginner）
        let allAboveBeginner = assessments.allSatisfy { $0.level >= .intermediate }
        let bonusScore = allAboveBeginner ? 25 : assessments.filter { $0.best1RM > 0 }.count * 8
        let totalScore = min(100, total + bonusScore)

        let totalLevel: StrengthLevel
        switch totalScore {
        case 80...: totalLevel = .elite
        case 60...: totalLevel = .advanced
        case 35...: totalLevel = .intermediate
        default:    totalLevel = .beginner
        }

        return StrengthAssessment(lifts: assessments, totalScore: totalScore, totalLevel: totalLevel)
    }
}
