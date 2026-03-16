import Foundation
import UserNotifications
import SwiftData
import os

/// Weekly Health Summary — 每周日 9:00 推送本地通知
/// 包含：本周平均评分 / 训练次数 / 平均静息心率 / 与上周对比
final class WeeklySummaryService {

    static let shared = WeeklySummaryService()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "WeeklySummary")

    private enum NotificationID {
        static let weeklySummary = "com.abundra.pulse.weekly-summary"
    }

    // MARK: - 用户设置

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "pulse.weekly.summary.enabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "pulse.weekly.summary.enabled")
            if newValue {
                scheduleWeeklySummary()
            } else {
                cancelWeeklySummary()
            }
        }
    }

    // MARK: - 调度

    /// 调度每周日 9:00 通知（仅静态触发；内容在触发前实时计算）
    func scheduleWeeklySummary() {
        guard isEnabled else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.weeklySummary])

        var components = DateComponents()
        components.weekday = 1  // 周日
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        // 静态占位内容 — 实际内容由 deliver() 在触发前更新
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Weekly Health Summary")
        content.body = String(localized: "Your weekly health performance, trends, and advice")
        content.sound = .default
        content.interruptionLevel = .active
        // 点击通知跳转 Dashboard
        content.userInfo = ["destination": "dashboard"]

        let request = UNNotificationRequest(
            identifier: NotificationID.weeklySummary,
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] error in
            if let error {
                self?.logger.error("Weekly summary 调度失败: \(error.localizedDescription)")
            } else {
                self?.logger.info("Weekly summary 已调度 → 每周日 09:00")
            }
        }
    }

    func cancelWeeklySummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [NotificationID.weeklySummary])
        logger.info("Weekly summary 已取消")
    }

    // MARK: - 实时推送（含真实数据）

    /// 立即推送一条包含真实数据的 weekly summary（周日早上触发时调用，或手动测试）
    @MainActor
    func deliver(modelContext: ModelContext) {
        guard isEnabled else { return }

        let stats = computeStats(modelContext: modelContext)
        let content = buildContent(stats: stats)

        let request = UNNotificationRequest(
            identifier: "\(NotificationID.weeklySummary).instant",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                self?.logger.error("Weekly summary 推送失败: \(error.localizedDescription)")
            } else {
                self?.logger.info("Weekly summary 已推送")
            }
        }
    }

    // MARK: - 数据计算

    struct WeeklyStats {
        let avgScore: Int?
        let prevAvgScore: Int?
        let workoutCount: Int
        let prevWorkoutCount: Int
        let avgRestingHR: Double?
        let prevAvgRestingHR: Double?
    }

    private func computeStats(modelContext: ModelContext) -> WeeklyStats {
        let cal = Calendar.current
        let now = Date()

        // 本周：周一到今天
        let thisWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        let lastWeekEnd = thisWeekStart

        // 获取 DailySummary 数据
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
            return WeeklyStats(avgScore: nil, prevAvgScore: nil, workoutCount: 0,
                               prevWorkoutCount: 0, avgRestingHR: nil, prevAvgRestingHR: nil)
        }

        // 本周数据
        let thisSummaries = allSummaries.filter { $0.date >= thisWeekStart && $0.date < now }
        let lastSummaries = allSummaries.filter { $0.date >= lastWeekStart && $0.date < lastWeekEnd }

        let thisWorkouts = allWorkouts.filter { $0.startDate >= thisWeekStart && $0.startDate < now }
        let lastWorkouts = allWorkouts.filter { $0.startDate >= lastWeekStart && $0.startDate < lastWeekEnd }

        func avgScore(_ summaries: [DailySummary]) -> Int? {
            let scores = summaries.compactMap(\.dailyScore)
            guard !scores.isEmpty else { return nil }
            return scores.reduce(0, +) / scores.count
        }

        func avgRHR(_ summaries: [DailySummary]) -> Double? {
            let vals = summaries.compactMap(\.restingHeartRate)
            guard !vals.isEmpty else { return nil }
            return vals.reduce(0, +) / Double(vals.count)
        }

        return WeeklyStats(
            avgScore: avgScore(thisSummaries),
            prevAvgScore: avgScore(lastSummaries),
            workoutCount: thisWorkouts.count,
            prevWorkoutCount: lastWorkouts.count,
            avgRestingHR: avgRHR(thisSummaries),
            prevAvgRestingHR: avgRHR(lastSummaries)
        )
    }

    // MARK: - 通知内容构建

    private func buildContent(stats: WeeklyStats) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["destination": "dashboard"]

        // 标题
        if let score = stats.avgScore {
            let trend = scoreTrend(current: score, prev: stats.prevAvgScore)
            content.title = String(format: String(localized: "Weekly Score: %d%@"), score, trend)
        } else {
            content.title = String(localized: "Weekly Health Summary")
        }

        // 正文：训练次数 + 静息心率 + 对比
        var lines: [String] = []

        // 训练次数
        let workoutDiff = stats.workoutCount - stats.prevWorkoutCount
        let workoutSign = workoutDiff > 0 ? "↑" : (workoutDiff < 0 ? "↓" : "→")
        lines.append(String(format: String(localized: "Workouts: %d sessions%@"),
                            stats.workoutCount,
                            workoutDiff != 0 ? " \(workoutSign)\(abs(workoutDiff))" : ""))

        // 静息心率
        if let rhr = stats.avgRestingHR {
            let rhrStr = String(format: "%.0f bpm", rhr)
            if let prevRhr = stats.prevAvgRestingHR {
                let diff = rhr - prevRhr
                let sign = diff < -0.5 ? "↓" : (diff > 0.5 ? "↑" : "→")
                lines.append(String(format: String(localized: "Resting HR: %@%@"),
                                    rhrStr,
                                    abs(diff) > 0.5 ? " \(sign)\(String(format: "%.0f", abs(diff)))" : ""))
            } else {
                lines.append(String(format: String(localized: "Resting HR: %@"), rhrStr))
            }
        }

        content.body = lines.joined(separator: "  ·  ")
        if content.body.isEmpty {
            content.body = String(localized: "Your weekly health performance, trends, and advice")
        }

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
