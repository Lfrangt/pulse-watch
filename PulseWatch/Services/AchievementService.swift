import Foundation
import UserNotifications
import os

/// 力量训练成就系统
final class AchievementService {

    static let shared = AchievementService()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "Achievement")

    // MARK: - Achievement Definitions

    enum Achievement: String, CaseIterable, Identifiable {
        case firstRep = "firstRep"
        case bodyweightSquat = "bodyweightSquat"
        case onePlateClub = "onePlateClub"
        case twoPlateClub = "twoPlateClub"
        case bigThree300 = "bigThree300"
        case prStreak = "prStreak"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .firstRep:         return String(localized: "First Rep")
            case .bodyweightSquat:  return String(localized: "Body Weight Squat")
            case .onePlateClub:     return String(localized: "1 Plate Club")
            case .twoPlateClub:     return String(localized: "2 Plate Club")
            case .bigThree300:      return String(localized: "Big Three 300")
            case .prStreak:         return String(localized: "PR Streak")
            }
        }

        var description: String {
            switch self {
            case .firstRep:         return String(localized: "Record your first lift")
            case .bodyweightSquat:  return String(localized: "Squat your body weight")
            case .onePlateClub:     return String(localized: "Hit 60kg on any Big 3 lift")
            case .twoPlateClub:     return String(localized: "Hit 100kg on any Big 3 lift")
            case .bigThree300:      return String(localized: "Total 300kg across all three lifts")
            case .prStreak:         return String(localized: "Set a new PR 4 weeks in a row")
            }
        }

        var medal: String {
            switch self {
            case .firstRep:         return "🥉"
            case .bodyweightSquat:  return "🥈"
            case .onePlateClub:     return "🥇"
            case .twoPlateClub:     return "💪"
            case .bigThree300:      return "🏆"
            case .prStreak:         return "🔥"
            }
        }
    }

    // MARK: - Unlocked State

    private func isUnlocked(_ achievement: Achievement) -> Bool {
        UserDefaults.standard.bool(forKey: "pulse.achievement.\(achievement.rawValue)")
    }

    private func unlock(_ achievement: Achievement) {
        guard !isUnlocked(achievement) else { return }
        UserDefaults.standard.set(true, forKey: "pulse.achievement.\(achievement.rawValue)")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "pulse.achievement.\(achievement.rawValue).date")
        logger.info("🏆 Achievement unlocked: \(achievement.title)")
    }

    func unlockedDate(_ achievement: Achievement) -> Date? {
        let ts = UserDefaults.standard.double(forKey: "pulse.achievement.\(achievement.rawValue).date")
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    // MARK: - Check All

    struct CheckResult {
        let newlyUnlocked: [Achievement]
    }

    /// Check all achievements. Returns newly unlocked ones (for celebration animation).
    func checkAll(records: [StrengthRecord], bodyweightKg: Double) -> CheckResult {
        var newlyUnlocked: [Achievement] = []

        // First Rep
        if !records.isEmpty && !isUnlocked(.firstRep) {
            unlock(.firstRep)
            newlyUnlocked.append(.firstRep)
        }

        // Max 1RMs
        let squat1RM = records.filter { $0.liftType == "squat" }.map(\.estimated1RM).max() ?? 0
        let bench1RM = records.filter { $0.liftType == "bench" }.map(\.estimated1RM).max() ?? 0
        let deadlift1RM = records.filter { $0.liftType == "deadlift" }.map(\.estimated1RM).max() ?? 0
        let total = squat1RM + bench1RM + deadlift1RM

        // Bodyweight Squat
        if bodyweightKg > 0 && squat1RM >= bodyweightKg && !isUnlocked(.bodyweightSquat) {
            unlock(.bodyweightSquat)
            newlyUnlocked.append(.bodyweightSquat)
        }

        // 1 Plate Club (60kg)
        if [squat1RM, bench1RM, deadlift1RM].contains(where: { $0 >= 60 }) && !isUnlocked(.onePlateClub) {
            unlock(.onePlateClub)
            newlyUnlocked.append(.onePlateClub)
        }

        // 2 Plate Club (100kg)
        if [squat1RM, bench1RM, deadlift1RM].contains(where: { $0 >= 100 }) && !isUnlocked(.twoPlateClub) {
            unlock(.twoPlateClub)
            newlyUnlocked.append(.twoPlateClub)
        }

        // Big Three 300
        if total >= 300 && !isUnlocked(.bigThree300) {
            unlock(.bigThree300)
            newlyUnlocked.append(.bigThree300)
        }

        // PR Streak — 4 consecutive weeks with at least 1 PR
        let cal = Calendar.current
        let now = Date()
        var consecutiveWeeks = 0
        for weekOffset in 0..<4 {
            let weekStart = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: now)!
            let weekStartDay = cal.startOfDay(for: cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!)
            let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStartDay)!
            let weekPRs = records.filter { $0.isPersonalRecord && $0.date >= weekStartDay && $0.date < weekEnd }
            if weekPRs.isEmpty { break }
            consecutiveWeeks += 1
        }
        if consecutiveWeeks >= 4 && !isUnlocked(.prStreak) {
            unlock(.prStreak)
            newlyUnlocked.append(.prStreak)
        }

        return CheckResult(newlyUnlocked: newlyUnlocked)
    }

    /// All achievements with unlock status
    func allAchievements() -> [(Achievement, Bool, Date?)] {
        Achievement.allCases.map { ($0, isUnlocked($0), unlockedDate($0)) }
    }

    // MARK: - Weekly PB Reminder

    func scheduleWeeklyPBReminder() {
        let enabled = UserDefaults.standard.object(forKey: "pulse.pb.reminder.enabled") as? Bool ?? true
        guard enabled else { return }

        let center = UNUserNotificationCenter.current()
        let id = "com.abundra.pulse.pb-reminder"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        var components = DateComponents()
        components.weekday = 1  // Sunday
        components.hour = 20
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Any new PRs this week? 💪")
        content.body = String(localized: "Record your lifts and track your progress")
        content.sound = .default
        content.userInfo = ["destination": "strength"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        logger.info("PB reminder scheduled → Sunday 20:00")
    }

    func cancelWeeklyPBReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["com.abundra.pulse.pb-reminder"])
    }
}
