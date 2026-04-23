import Foundation
import UserNotifications
import SwiftData
import os

/// Streak — 用户每日健康连续记录
/// 检查每天是否有步数或心率数据，有则 streak +1，无则归零
/// milestone 7天/30天 触发庆祝通知
final class StreakService {

    static let shared = StreakService()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "Streak")

    // MARK: - Persisted State

    var currentStreak: Int {
        get { UserDefaults.standard.integer(forKey: "pulse.streak.current") }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.streak.current") }
    }

    var bestStreak: Int {
        get { UserDefaults.standard.integer(forKey: "pulse.streak.best") }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.streak.best") }
    }

    /// Last date streak was successfully updated (yyyy-MM-dd)
    private var lastStreakDate: String {
        get { UserDefaults.standard.string(forKey: "pulse.streak.lastDate") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.streak.lastDate") }
    }

    // MARK: - Public API

    /// App 启动或数据刷新后调用，重新计算今日 streak
    func refresh(modelContext: ModelContext) {
        let today = dateString(for: .now)
        guard today != lastStreakDate else {
            logger.debug("Streak already updated today (\(today))")
            return
        }

        let hasDataToday = queryHasData(on: today, modelContext: modelContext)

        if hasDataToday {
            let yesterday = dateString(for: Calendar.current.safeDate(byAdding: .day, value: -1, to: .now))
            let hadDataYesterday = (lastStreakDate == yesterday) || queryHasData(on: yesterday, modelContext: modelContext)

            if hadDataYesterday || lastStreakDate.isEmpty {
                currentStreak += 1
            } else {
                // gap — reset
                currentStreak = 1
            }

            lastStreakDate = today

            if currentStreak > bestStreak {
                bestStreak = currentStreak
            }

            checkMilestone(streak: currentStreak)
            logger.info("Streak updated → \(self.currentStreak) days (best: \(self.bestStreak))")

        } else {
            // No data yet today — check if yesterday's streak is broken
            let yesterday = dateString(for: Calendar.current.safeDate(byAdding: .day, value: -1, to: .now))
            if lastStreakDate != yesterday && !lastStreakDate.isEmpty {
                // missed yesterday → reset
                currentStreak = 0
                logger.info("Streak broken → reset to 0")
            }
        }
    }

    /// Demo mode — set a fake streak for previews
    func setDemoStreak(_ value: Int = 12) {
        currentStreak = value
        if value > bestStreak { bestStreak = value }
    }

    // MARK: - Helpers

    private func queryHasData(on dateStr: String, modelContext: ModelContext) -> Bool {
        let predicate = #Predicate<DailySummary> { $0.dateString == dateStr }
        let descriptor = FetchDescriptor<DailySummary>(predicate: predicate)
        let results = (try? modelContext.fetch(descriptor)) ?? []
        guard let summary = results.first else { return false }
        // "有数据"定义：步数 > 0 或有心率记录
        let hasSteps = (summary.totalSteps ?? 0) > 0
        let hasHR = summary.averageHeartRate != nil
        return hasSteps || hasHR
    }

    private func dateString(for date: Date) -> String {
        DailySummary.dateFormatter.string(from: date)
    }

    // MARK: - Milestone Notifications

    private let milestones = [7, 30, 100, 365]

    private func checkMilestone(streak: Int) {
        guard milestones.contains(streak) else { return }

        let center = UNUserNotificationCenter.current()
        let id = "com.abundra.pulse.streak.milestone.\(streak)"

        // Avoid duplicate
        center.getPendingNotificationRequests { requests in
            guard !requests.contains(where: { $0.identifier == id }) else { return }

            let content = UNMutableNotificationContent()
            content.title = String(format: String(localized: "🔥 %d-Day Streak!"), streak)
            content.body = String(format: String(localized: "You've tracked your health for %d days straight. Keep it up!"), streak)
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let request = UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            )

            center.add(request) { error in
                if let error {
                    self.logger.error("Milestone \(streak) notification failed: \(error.localizedDescription)")
                } else {
                    self.logger.info("🔥 Milestone \(streak)-day streak notification sent")
                }
            }
        }
    }
}
