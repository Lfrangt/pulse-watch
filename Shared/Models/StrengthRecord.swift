import Foundation
import SwiftData

/// 力量训练三大项记录
@Model
final class StrengthRecord {
    var id: UUID
    var liftType: String           // "squat" / "bench" / "deadlift"
    var weightKg: Double           // 重量 (kg)
    var sets: Int
    var reps: Int
    var date: Date
    var isPersonalRecord: Bool = false
    var notes: String?

    init(liftType: String, weightKg: Double, sets: Int, reps: Int, date: Date, notes: String? = nil) {
        self.id = UUID()
        self.liftType = liftType
        self.weightKg = weightKg
        self.sets = sets
        self.reps = reps
        self.date = date
        self.notes = notes
    }

    /// 估算1RM (Epley公式)
    var estimated1RM: Double {
        guard reps > 0 else { return weightKg }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30.0)
    }
}
