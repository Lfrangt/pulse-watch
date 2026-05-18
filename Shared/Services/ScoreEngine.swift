import Foundation

/// Generates daily insights and training suggestions
/// This is the "brain" — turns raw data into actionable advice
struct ScoreEngine {
    
    // MARK: - Daily Brief
    
    struct DailyBrief {
        let score: Int                    // 0-100
        let headline: String             // String(localized: "Good") / String(localized: "Rest")
        let insight: String              // One-line actionable insight
        let sleepSummary: String?
        let recoveryNote: String?
        let trainingPlan: TrainingPlan?
    }
    
    static func generateBrief(
        hrv: Double?,
        restingHR: Double?,
        bloodOxygen: Double?,
        sleepMinutes: Int,
        deepSleepMinutes: Int,
        remSleepMinutes: Int,
        steps: Int,
        recentWorkouts: [WorkoutRecord]
    ) -> DailyBrief {
        
        let score = calculateScore(
            hrv: hrv,
            restingHR: restingHR,
            bloodOxygen: bloodOxygen,
            sleepMinutes: sleepMinutes
        )
        
        let headline = PulseTheme.statusLabel(for: score)
        let insight = generateInsight(score: score, hrv: hrv, sleepMinutes: sleepMinutes)
        let sleepSummary = formatSleep(total: sleepMinutes, deep: deepSleepMinutes, rem: remSleepMinutes)
        let recoveryNote = generateRecoveryNote(score: score, hrv: hrv, restingHR: restingHR)
        let trainingPlan = suggestTraining(score: score, recentWorkouts: recentWorkouts)
        
        return DailyBrief(
            score: score,
            headline: headline,
            insight: insight,
            sleepSummary: sleepSummary,
            recoveryNote: recoveryNote,
            trainingPlan: trainingPlan
        )
    }
    
    // MARK: - Score Calculation
    //
    // Weighted average of 4 components — realistic, hard to max out.
    // Each component scores 0-100, final = weighted sum.
    // Weights: HRV 35% | Sleep 30% | RHR 25% | SpO2 10%
    //
    // Design goal: genuinely excellent metrics → 88-92
    //              good metrics → 70-82
    //              average → 55-68
    //              poor → below 50

    private static func calculateScore(
        hrv: Double?,
        restingHR: Double?,
        bloodOxygen: Double?,
        sleepMinutes: Int
    ) -> Int {

        // HRV component (35%) — higher = better
        // Young adult population ranges: ~20-120ms, median ~50ms
        let hrvScore: Double = {
            guard let hrv else { return 55 } // no data → average
            switch hrv {
            case ..<20:   return 10
            case 20..<30: return 28
            case 30..<40: return 45
            case 40..<50: return 60
            case 50..<62: return 72
            case 62..<75: return 82
            case 75..<90: return 88
            case 90..<110: return 93
            default:      return 96 // >110ms — elite
            }
        }()

        // RHR component (25%) — lower = better, but <40 may indicate overtraining
        let rhrScore: Double = {
            guard let rhr = restingHR else { return 55 }
            switch rhr {
            case ..<40:    return 78 // possibly overtraining
            case 40..<48:  return 92 // elite
            case 48..<55:  return 85 // very good
            case 55..<63:  return 72 // good
            case 63..<70:  return 60 // average
            case 70..<78:  return 45 // below average
            case 78..<88:  return 28
            default:       return 15
            }
        }()

        // Sleep component (30%) — optimal 7-8.5h, penalise both short and long
        let sleepScore: Double = {
            guard sleepMinutes > 0 else { return 30 }
            let h = Double(sleepMinutes) / 60.0
            switch h {
            case ..<5.0:       return 15
            case 5.0..<6.0:    return 35
            case 6.0..<6.5:    return 52
            case 6.5..<7.0:    return 67
            case 7.0..<7.5:    return 80
            case 7.5..<8.5:    return 90 // optimal window
            case 8.5..<9.5:    return 78 // slightly long
            default:           return 60 // oversleeping
            }
        }()

        // SpO2 component (10%) — mostly binary
        let spo2Score: Double = {
            guard let spo2 = bloodOxygen else { return 78 }
            switch spo2 {
            case 98...:     return 100
            case 96..<98:   return 88
            case 94..<96:   return 65
            case 92..<94:   return 38
            default:        return 18
            }
        }()

        let raw = hrvScore * 0.35 + rhrScore * 0.25 + sleepScore * 0.30 + spo2Score * 0.10

        // Apply a soft ceiling: scores above 85 are progressively harder
        let adjusted: Double
        if raw > 85 {
            adjusted = 85 + (raw - 85) * 0.45
        } else {
            adjusted = raw
        }

        return max(0, min(100, Int(adjusted.rounded())))
    }
    
    // MARK: - Insight Generation
    
    private static func generateInsight(score: Int, hrv: Double?, sleepMinutes: Int) -> String {
        switch score {
        case 88...:
            return String(localized: "Peak recovery — go all out today")
        case 78..<88:
            return String(localized: "Feeling good — train as planned")
        case 65..<78:
            if sleepMinutes < 390 {
                return String(localized: "Sleep deficit — train lightly, rest early tonight")
            }
            return String(localized: "Good recovery — moderate intensity training")
        case 50..<65:
            if let hrv, hrv < 35 {
                return String(localized: "HRV is low — focus on recovery, avoid high intensity")
            }
            return String(localized: "Still recovering — light activity only")
        default:
            return String(localized: "Rest day — your body needs full recovery")
        }
    }
    
    // MARK: - Sleep Formatting
    
    private static func formatSleep(total: Int, deep: Int, rem: Int) -> String? {
        guard total > 0 else { return nil }
        let hours = total / 60
        let mins = total % 60
        let deepLabel = String(localized: "Deep")
        return "\(hours)h\(mins)m · \(deepLabel) \(deep)m · REM \(rem)m"
    }
    
    // MARK: - Recovery Note
    
    private static func generateRecoveryNote(score: Int, hrv: Double?, restingHR: Double?) -> String? {
        guard score < 60 else { return nil }
        
        var notes: [String] = []
        if let hrv, hrv < 35 {
            notes.append("HRV low (\(Int(hrv))ms)")
        }
        if let rhr = restingHR, rhr > 75 {
            notes.append("RHR elevated (\(Int(rhr))bpm)")
        }
        
        return notes.isEmpty ? nil : notes.joined(separator: ", ")
    }
    
    // MARK: - Training Suggestion
    
    private static func suggestTraining(score: Int, recentWorkouts: [WorkoutRecord]) -> TrainingPlan? {
        guard score >= 30 else {
            return TrainingPlan(
                targetMuscleGroup: "rest",
                daysSinceLastTrained: 0,
                suggestedExercises: [],
                intensity: .light,
                reason: String(localized: "Rest day — skip training today")
            )
        }
        
        // Determine which muscle group to train based on rotation
        let muscleGroups = ["chest", "back", "legs", "shoulders"]
        let today = Date()
        
        // Find least recently trained group
        var bestGroup = muscleGroups[0]
        var maxDays = 0
        
        for group in muscleGroups {
            let lastWorkout = recentWorkouts
                .filter { $0.category == group }
                .sorted { $0.date > $1.date }
                .first
            
            let days: Int
            if let lastWorkout {
                days = Calendar.current.dateComponents([.day], from: lastWorkout.date, to: today).day ?? 999
            } else {
                days = 999
            }
            
            if days > maxDays {
                maxDays = days
                bestGroup = group
            }
        }
        
        let intensity: TrainingPlan.Intensity = score >= 70 ? .heavy : (score >= 50 ? .moderate : .light)
        
        let exercises = defaultExercises(for: bestGroup, intensity: intensity)
        
        return TrainingPlan(
            targetMuscleGroup: bestGroup,
            daysSinceLastTrained: min(maxDays, 99),
            suggestedExercises: exercises,
            intensity: intensity,
            reason: "Last \(localizedGroup(bestGroup)) was \(maxDays)d ago"
        )
    }
    
    private static func localizedGroup(_ group: String) -> String {
        switch group {
        case "chest": return String(localized: "Chest")
        case "back": return String(localized: "Back")
        case "legs": return String(localized: "Legs")
        case "shoulders": return String(localized: "Shoulders")
        case "arms": return String(localized: "Arms")
        default: return group
        }
    }
    
    private static func defaultExercises(for group: String, intensity: TrainingPlan.Intensity) -> [SuggestedExercise] {
        let sets = intensity == .heavy ? 4 : 3
        let reps = intensity == .heavy ? 8 : 10
        
        switch group {
        case "chest":
            return [
                SuggestedExercise(name: String(localized: "Flat Bench Press"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Incline Dumbbell Press"), sets: 3, reps: 10, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Cable Fly"), sets: 3, reps: 12, suggestedWeight: nil),
            ]
        case "back":
            return [
                SuggestedExercise(name: String(localized: "Pull-up"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Barbell Row"), sets: 3, reps: 10, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Seated Row"), sets: 3, reps: 12, suggestedWeight: nil),
            ]
        case "legs":
            return [
                SuggestedExercise(name: String(localized: "Squat"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Leg Press"), sets: 3, reps: 10, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Romanian Deadlift"), sets: 3, reps: 10, suggestedWeight: nil),
            ]
        case "shoulders":
            return [
                SuggestedExercise(name: String(localized: "Dumbbell Press"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Lateral Raise"), sets: 3, reps: 12, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "Face Pull"), sets: 3, reps: 15, suggestedWeight: nil),
            ]
        default:
            return []
        }
    }
}
