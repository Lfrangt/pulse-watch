import Foundation
import SwiftData

/// 持久化的训练记录 — 从 HealthKit HKWorkout 同步到本地 SwiftData
/// 解决训练完成后数据消失的痛点，支持离线查看历史
@Model
final class WorkoutHistoryEntry {
    var id: UUID
    var hkWorkoutUUID: String            // HKWorkout.uuid.uuidString，用于去重
    var activityType: Int                // HKWorkoutActivityType.rawValue
    var startDate: Date
    var endDate: Date
    var durationSeconds: Double
    var totalCalories: Double?           // kcal
    var totalDistance: Double?            // meters
    var averageHeartRate: Double?         // bpm
    var maxHeartRate: Double?             // bpm
    var sourceName: String               // 数据来源（Apple Watch 等）
    var heartRateZonesData: Data?        // JSON encoded [HRZoneEntry]
    var syncedAt: Date                   // 同步时间

    init(
        hkWorkoutUUID: String,
        activityType: Int,
        startDate: Date,
        endDate: Date,
        durationSeconds: Double,
        totalCalories: Double? = nil,
        totalDistance: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        sourceName: String = "HealthKit"
    ) {
        self.id = UUID()
        self.hkWorkoutUUID = hkWorkoutUUID
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.totalCalories = totalCalories
        self.totalDistance = totalDistance
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.sourceName = sourceName
        self.syncedAt = .now
    }

    // MARK: - 心率区间存取

    var heartRateZones: [HRZoneEntry] {
        get {
            guard let data = heartRateZonesData else { return [] }
            return (try? JSONDecoder().decode([HRZoneEntry].self, from: data)) ?? []
        }
        set {
            heartRateZonesData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - 计算属性

    var durationMinutes: Int {
        Int(durationSeconds / 60)
    }

    var activityName: String {
        WorkoutActivityHelper.name(for: activityType)
    }

    var activityIcon: String {
        WorkoutActivityHelper.icon(for: activityType)
    }

    var activityColor: String {
        WorkoutActivityHelper.colorHex(for: activityType)
    }
}

// MARK: - 心率区间条目

struct HRZoneEntry: Codable, Identifiable {
    var id: String { name }
    let name: String
    let percentage: Double  // 0.0 ~ 1.0
    let colorHex: String
}

// MARK: - 运动类型辅助

enum WorkoutActivityHelper {

    static func name(for rawValue: Int) -> String {
        switch UInt(rawValue) {
        case 37: return String(localized: "Running")
        case 13: return String(localized: "Cycling")
        case 46: return String(localized: "Swimming")
        case 52: return String(localized: "Walking")
        case 24: return String(localized: "Hiking")
        case 50: return String(localized: "Yoga")
        case 20: return String(localized: "Functional Strength")
        case 50: return String(localized: "Yoga")
        case 58: return String(localized: "Strength Training")
        case 63: return String(localized: "HIIT")
        case 14: return String(localized: "Dance")
        case 18: return String(localized: "Elliptical")
        case 35: return String(localized: "Rowing")
        case 44: return String(localized: "Stair Climbing")
        case  4: return String(localized: "Basketball")
        case 43: return String(localized: "Soccer")
        case 47: return String(localized: "Tennis")
        case 48: return String(localized: "Table Tennis")
        case  2: return String(localized: "Badminton")
        case 72: return String(localized: "Cooldown")
        default: return String(localized: "Exercise")
        }
    }

    static func icon(for rawValue: Int) -> String {
        switch UInt(rawValue) {
        case 37: return "figure.run"
        case 13: return "figure.outdoor.cycle"
        case 46: return "figure.pool.swim"
        case 52: return "figure.walk"
        case 24: return "figure.hiking"
        case 50: return "figure.yoga"
        case 20, 58: return "dumbbell.fill"
        case 63: return "flame.fill"
        case 14: return "figure.dance"
        case 18: return "figure.elliptical"
        case 35: return "figure.rower"
        case 44: return "figure.stair.stepper"
        case  4: return "basketball.fill"
        case 43: return "soccerball"
        case 47: return "tennisball.fill"
        case 48: return "figure.table.tennis"
        case  2: return "figure.badminton"
        case 72: return "wind"
        default: return "figure.mixed.cardio"
        }
    }

    static func colorHex(for rawValue: Int) -> String {
        switch UInt(rawValue) {
        case 37, 63:            return "C75C5C"  // 跑步/HIIT — 红色
        case 13, 46, 35:        return "D4B478"  // 骑行/游泳/划船 — accent
        case 52, 24, 50, 72:    return "7FB069"  // 步行/瑜伽/恢复 — 绿色
        case 20, 58:            return "D4A056"  // 力量训练 — 琥珀色
        default:                return "D4B478"  // 默认 accent
        }
    }
}
