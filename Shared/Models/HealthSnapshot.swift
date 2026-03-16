import Foundation
import SwiftData

/// A point-in-time capture of health metrics
@Model
final class HealthSnapshot {
    var id: UUID
    var timestamp: Date
    
    // Heart
    var heartRate: Double?           // bpm
    var restingHeartRate: Double?    // bpm
    var heartRateVariability: Double? // ms (SDNN)
    
    // Blood
    var bloodOxygen: Double?         // percentage (0-100)
    
    // Activity
    var steps: Int?
    var activeCalories: Double?
    var standHours: Int?
    var exerciseMinutes: Int?
    
    // Sleep (from last night)
    var sleepDurationMinutes: Int?
    var deepSleepMinutes: Int?
    var remSleepMinutes: Int?
    var sleepScore: Int?             // 0-100 computed
    
    // Computed daily score
    var dailyScore: Int?             // 0-100
    
    init(timestamp: Date = .now) {
        self.id = UUID()
        self.timestamp = timestamp
    }
}

/// Workout record
@Model
final class WorkoutRecord {
    var id: UUID
    var date: Date
    var durationMinutes: Int
    var category: String             // "chest", "back", "legs", "shoulders", "arms", "cardio"
    var exercises: [ExerciseEntry]
    var averageHeartRate: Double?
    var caloriesBurned: Double?
    var notes: String?
    
    init(date: Date = .now, category: String, durationMinutes: Int = 0) {
        self.id = UUID()
        self.date = date
        self.category = category
        self.durationMinutes = durationMinutes
        self.exercises = []
    }
}

/// Single exercise within a workout
struct ExerciseEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String                 // "Bench Press"
    var sets: [SetEntry]
    
    var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}

/// A single set
struct SetEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var weight: Double               // kg
    var reps: Int
    var isWarmup: Bool = false
}

/// Known location for geofencing
@Model
final class SavedLocation {
    var id: UUID
    var name: String                 // "健身房", "学校", "家"
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var locationType: String         // "gym", "school", "home", "work", "other"
    var isActive: Bool
    
    init(name: String, latitude: Double, longitude: Double, radiusMeters: Double = 100, locationType: String) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.locationType = locationType
        self.isActive = true
    }
}

/// Training plan suggestion
struct TrainingPlan: Codable {
    var targetMuscleGroup: String
    var daysSinceLastTrained: Int
    var suggestedExercises: [SuggestedExercise]
    var intensity: Intensity
    var reason: String               // "HRV 正常，上次练胸是 3 天前"
    
    enum Intensity: String, Codable {
        case light = "Light"
        case moderate = "Moderate"
        case heavy = "High Intensity"
    }
}

struct SuggestedExercise: Codable {
    var name: String
    var sets: Int
    var reps: Int
    var suggestedWeight: Double?     // kg, based on history
}
