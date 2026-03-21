import Foundation
import UserNotifications
import SwiftData
import os

/// Monthly Health Summary — 每月1号 9:00 推送月度报告通知
@MainActor
final class MonthlySummaryService {

    static let shared = MonthlySummaryService()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "MonthlySummary")

    private enum NotificationID {
        static let monthlySummary = "com.abundra.pulse.monthly-summary"
    }

    // MARK: - 用户设置

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "pulse.monthly.summary.enabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "pulse.monthly.summary.enabled")
            if newValue {
                scheduleMonthlySummary()
            } else {
                cancelMonthlySummary()
            }
        }
    }

    // MARK: - 调度

    func scheduleMonthlySummary() {
        guard isEnabled else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.monthlySummary])

        var components = DateComponents()
        components.day = 1      // 每月 1 号
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Monthly Health Report")
        content.body = String(localized: "Your monthly health performance summary is ready")
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["destination": "monthly-report"]

        let request = UNNotificationRequest(
            identifier: NotificationID.monthlySummary,
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] error in
            if let error {
                self?.logger.error("Monthly summary 调度失败: \(error.localizedDescription)")
            } else {
                self?.logger.info("Monthly summary 已调度 → 每月1号 09:00")
            }
        }
    }

    func cancelMonthlySummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [NotificationID.monthlySummary])
        logger.info("Monthly summary 已取消")
    }

    // MARK: - 实时推送

    @MainActor
    func deliver(modelContext: ModelContext) {
        guard isEnabled else { return }

        let stats = computeStats(modelContext: modelContext)
        let content = buildContent(stats: stats)

        let request = UNNotificationRequest(
            identifier: "\(NotificationID.monthlySummary).instant",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.logger.error("Monthly summary 推送失败: \(error.localizedDescription)")
            } else {
                self?.logger.info("Monthly summary 已推送")
            }
        }
    }

    // MARK: - 数据计算

    struct MonthlyStats {
        let monthLabel: String
        let avgScore: Int?
        let prevAvgScore: Int?
        let workoutCount: Int
        let prevWorkoutCount: Int
        let avgRestingHR: Double?
        let avgHRV: Double?
        let avgSleepHours: Double?
        let totalSteps: Int
        let bestDay: (date: Date, score: Int)?
        let worstDay: (date: Date, score: Int)?
    }

    func computeStats(modelContext: ModelContext) -> MonthlyStats {
        let cal = Calendar.current
        let now = Date()

        // 本月
        let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let lastMonthStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart)!

        let allSummaries: [DailySummary]
        let allWorkouts: [WorkoutHistoryEntry]

        do {
            allSummaries = try modelContext.fetch(FetchDescriptor<DailySummary>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ))
            allWorkouts = try modelContext.fetch(FetchDescriptor<WorkoutHistoryEntry>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            ))
        } catch {
            logger.error("数据查询失败: \(error.localizedDescription)")
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy年M月"
            return MonthlyStats(monthLabel: fmt.string(from: lastMonthStart),
                                avgScore: nil, prevAvgScore: nil,
                                workoutCount: 0, prevWorkoutCount: 0,
                                avgRestingHR: nil, avgHRV: nil, avgSleepHours: nil,
                                totalSteps: 0, bestDay: nil, worstDay: nil)
        }

        // 用上个月数据（月初时报告上月）
        let prevMonthStart = cal.date(byAdding: .month, value: -1, to: lastMonthStart)!

        let thisSummaries = allSummaries.filter { $0.date >= lastMonthStart && $0.date < thisMonthStart }
        let prevSummaries = allSummaries.filter { $0.date >= prevMonthStart && $0.date < lastMonthStart }

        let thisWorkouts = allWorkouts.filter { $0.startDate >= lastMonthStart && $0.startDate < thisMonthStart }
        let prevWorkouts = allWorkouts.filter { $0.startDate >= prevMonthStart && $0.startDate < lastMonthStart }

        func avg(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }

        let scores = thisSummaries.compactMap(\.dailyScore)
        let prevScores = prevSummaries.compactMap(\.dailyScore)

        let bestDay = thisSummaries
            .compactMap { s -> (Date, Int)? in s.dailyScore.map { (s.date, $0) } }
            .max(by: { $0.1 < $1.1 })

        let worstDay = thisSummaries
            .compactMap { s -> (Date, Int)? in s.dailyScore.map { (s.date, $0) } }
            .min(by: { $0.1 < $1.1 })

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月"

        return MonthlyStats(
            monthLabel: fmt.string(from: lastMonthStart),
            avgScore: scores.isEmpty ? nil : scores.reduce(0, +) / scores.count,
            prevAvgScore: prevScores.isEmpty ? nil : prevScores.reduce(0, +) / prevScores.count,
            workoutCount: thisWorkouts.count,
            prevWorkoutCount: prevWorkouts.count,
            avgRestingHR: avg(thisSummaries.compactMap(\.restingHeartRate)),
            avgHRV: avg(thisSummaries.compactMap(\.averageHRV)),
            avgSleepHours: avg(thisSummaries.compactMap(\.sleepDurationMinutes).map { Double($0) / 60.0 }),
            totalSteps: thisSummaries.compactMap(\.totalSteps).reduce(0, +),
            bestDay: bestDay,
            worstDay: worstDay
        )
    }

    // MARK: - 通知内容构建

    private func buildContent(stats: MonthlyStats) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["destination": "monthly-report"]

        if let score = stats.avgScore {
            let trend = scoreTrend(current: score, prev: stats.prevAvgScore)
            content.title = String(format: String(localized: "%@ · Avg Score: %d%@"), stats.monthLabel, score, trend)
        } else {
            content.title = String(format: String(localized: "%@ Monthly Report"), stats.monthLabel)
        }

        var lines: [String] = []
        lines.append(String(format: String(localized: "Workouts: %d"), stats.workoutCount))
        if let rhr = stats.avgRestingHR {
            lines.append(String(format: String(localized: "RHR: %.0f bpm"), rhr))
        }
        if let sleep = stats.avgSleepHours {
            lines.append(String(format: String(localized: "Sleep: %.1fh"), sleep))
        }

        content.body = lines.joined(separator: "  ·  ")
        return content
    }

    private func scoreTrend(current: Int, prev: Int?) -> String {
        guard let prev else { return "" }
        let diff = current - prev
        if diff > 2 { return " ↑\(diff)" }
        if diff < -2 { return " ↓\(abs(diff))" }
        return ""
    }
}
