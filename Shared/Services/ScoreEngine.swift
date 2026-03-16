import Foundation

/// Generates daily insights and training suggestions
/// This is the "brain" — turns raw data into actionable advice
struct ScoreEngine {
    
    // MARK: - Daily Brief
    
    struct DailyBrief {
        let score: Int                    // 0-100
        let headline: String             // String(localized: "状态良好") / String(localized: "需要休息")
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
    
    private static func calculateScore(
        hrv: Double?,
        restingHR: Double?,
        bloodOxygen: Double?,
        sleepMinutes: Int
    ) -> Int {
        var score = 50
        
        if let hrv {
            if hrv > 65 { score += 20 }
            else if hrv > 45 { score += 10 }
            else if hrv > 30 { score += 0 }
            else { score -= 15 }
        }
        
        if let rhr = restingHR {
            if rhr < 55 { score += 10 }
            else if rhr < 65 { score += 5 }
            else if rhr > 80 { score -= 10 }
        }
        
        if sleepMinutes >= 450 { score += 15 }       // 7.5h+
        else if sleepMinutes >= 390 { score += 10 }   // 6.5h+
        else if sleepMinutes >= 330 { score += 0 }     // 5.5h+
        else { score -= 15 }
        
        if let spo2 = bloodOxygen {
            if spo2 >= 97 { score += 5 }
            else if spo2 < 93 { score -= 10 }
        }
        
        return max(0, min(100, score))
    }
    
    // MARK: - Insight Generation
    
    private static func generateInsight(score: Int, hrv: Double?, sleepMinutes: Int) -> String {
        if score >= 80 {
            return String(localized: "身体恢复很好，适合高强度训练")
        } else if score >= 60 {
            if sleepMinutes < 360 {
                return String(localized: "睡眠不足，今天注意补觉")
            }
            return String(localized: "状态不错，正常安排就好")
        } else if score >= 40 {
            if let hrv, hrv < 30 {
                return String(localized: "HRV偏低，建议轻量活动或休息")
            }
            return String(localized: "身体在恢复中，避免高强度")
        } else {
            return String(localized: "身体需要休息，今天别硬撑")
        }
    }
    
    // MARK: - Sleep Formatting
    
    private static func formatSleep(total: Int, deep: Int, rem: Int) -> String? {
        guard total > 0 else { return nil }
        let hours = total / 60
        let mins = total % 60
        let deepLabel = String(localized: "深睡")
        return "\(hours)h\(mins)m · \(deepLabel) \(deep)m · REM \(rem)m"
    }
    
    // MARK: - Recovery Note
    
    private static func generateRecoveryNote(score: Int, hrv: Double?, restingHR: Double?) -> String? {
        guard score < 60 else { return nil }
        
        var notes: [String] = []
        if let hrv, hrv < 35 {
            notes.append("HRV 偏低(\(Int(hrv))ms)")
        }
        if let rhr = restingHR, rhr > 75 {
            notes.append("静息心率偏高(\(Int(rhr))bpm)")
        }
        
        return notes.isEmpty ? nil : notes.joined(separator: "，")
    }
    
    // MARK: - Training Suggestion
    
    private static func suggestTraining(score: Int, recentWorkouts: [WorkoutRecord]) -> TrainingPlan? {
        guard score >= 30 else {
            return TrainingPlan(
                targetMuscleGroup: "rest",
                daysSinceLastTrained: 0,
                suggestedExercises: [],
                intensity: .light,
                reason: String(localized: "身体需要休息，建议今天不训练")
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
            reason: "上次练\(localizedGroup(bestGroup))是\(maxDays)天前"
        )
    }
    
    private static func localizedGroup(_ group: String) -> String {
        switch group {
        case "chest": return String(localized: "胸")
        case "back": return String(localized: "背")
        case "legs": return String(localized: "腿")
        case "shoulders": return String(localized: "肩")
        case "arms": return String(localized: "手臂")
        default: return group
        }
    }
    
    private static func defaultExercises(for group: String, intensity: TrainingPlan.Intensity) -> [SuggestedExercise] {
        let sets = intensity == .heavy ? 4 : 3
        let reps = intensity == .heavy ? 8 : 10
        
        switch group {
        case "chest":
            return [
                SuggestedExercise(name: String(localized: "平板卧推"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "上斜哑铃卧推"), sets: 3, reps: 10, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "绳索飞鸟"), sets: 3, reps: 12, suggestedWeight: nil),
            ]
        case "back":
            return [
                SuggestedExercise(name: String(localized: "引体向上"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "杠铃划船"), sets: 3, reps: 10, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "坐姿划船"), sets: 3, reps: 12, suggestedWeight: nil),
            ]
        case "legs":
            return [
                SuggestedExercise(name: String(localized: "深蹲"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "腿举"), sets: 3, reps: 10, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "罗马尼亚硬拉"), sets: 3, reps: 10, suggestedWeight: nil),
            ]
        case "shoulders":
            return [
                SuggestedExercise(name: String(localized: "哑铃推举"), sets: sets, reps: reps, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "侧平举"), sets: 3, reps: 12, suggestedWeight: nil),
                SuggestedExercise(name: String(localized: "面拉"), sets: 3, reps: 15, suggestedWeight: nil),
            ]
        default:
            return []
        }
    }
}
