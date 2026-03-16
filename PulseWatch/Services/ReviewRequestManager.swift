import StoreKit
import SwiftUI

/// App Store 评价引导管理器 — 智能触发策略
///
/// 触发条件（任一满足即可弹出）：
///   a) 完成第 3 次训练
///   b) 连续使用 app 3 天
///   c) 首次查看趋势图且有 7 天完整数据
///
/// 防骚扰：
///   - 同一触发条件 90 天内不重复
///   - 两次弹窗间隔至少 30 天
@MainActor
final class ReviewRequestManager: ObservableObject {

    static let shared = ReviewRequestManager()

    // MARK: - Counters

    @AppStorage("pulse.review.workoutCount") private var workoutCount: Int = 0
    @AppStorage("pulse.review.consecutiveDays") private var consecutiveDays: Int = 0
    @AppStorage("pulse.review.lastActiveDate") private var lastActiveDateString: String = ""

    // MARK: - Last prompt date (global cooldown)

    @AppStorage("pulse.review.lastPromptDate") private var lastPromptDateString: String = ""

    // MARK: - Per-condition last trigger dates (90-day cooldown)

    @AppStorage("pulse.review.lastWorkoutTriggerDate") private var lastWorkoutTriggerDateString: String = ""
    @AppStorage("pulse.review.lastConsecutiveDaysTriggerDate") private var lastDaysTriggerDateString: String = ""
    @AppStorage("pulse.review.lastTrendsTriggerDate") private var lastTrendsTriggerDateString: String = ""

    // MARK: - Thresholds & cooldowns

    private let workoutThreshold = 3
    private let consecutiveDaysThreshold = 3
    private let conditionCooldownDays = 90
    private let globalCooldownDays = 30

    private init() {}

    // MARK: - 事件记录

    /// 用户完成一次 workout 时调用
    func recordWorkoutCompleted() {
        workoutCount += 1
        tryRequestReview(for: .workout)
    }

    /// 同步 HealthKit workout 总数（避免重复计数）
    func syncWorkoutCount(_ total: Int) {
        guard total > workoutCount else { return }
        workoutCount = total
        tryRequestReview(for: .workout)
    }

    /// App 启动 / 进入前台时调用，记录连续使用天数
    func recordAppActive() {
        let today = dateString(from: .now)
        guard today != lastActiveDateString else { return }

        if isConsecutiveDay(last: lastActiveDateString, current: today) {
            consecutiveDays += 1
        } else {
            consecutiveDays = 1
        }

        lastActiveDateString = today
        tryRequestReview(for: .consecutiveDays)
    }

    /// 用户查看趋势图时调用
    /// - Parameter hasSevenDayData: 是否有 7 天完整数据
    func recordTrendsViewed(hasSevenDayData: Bool) {
        guard hasSevenDayData else { return }
        tryRequestReview(for: .trendsViewed)
    }

    // MARK: - 核心逻辑

    private enum TriggerCondition {
        case workout
        case consecutiveDays
        case trendsViewed
    }

    private func tryRequestReview(for condition: TriggerCondition) {
        // 1. Global cooldown: 两次弹窗间隔至少 30 天
        if let lastPrompt = date(from: lastPromptDateString),
           daysSince(lastPrompt) < globalCooldownDays {
            return
        }

        // 2. Check if the specific condition is met + not in 90-day cooldown
        switch condition {
        case .workout:
            guard workoutCount >= workoutThreshold else { return }
            guard conditionNotInCooldown(lastTriggerDateString: lastWorkoutTriggerDateString) else { return }
            lastWorkoutTriggerDateString = dateString(from: .now)

        case .consecutiveDays:
            guard consecutiveDays >= consecutiveDaysThreshold else { return }
            guard conditionNotInCooldown(lastTriggerDateString: lastDaysTriggerDateString) else { return }
            lastDaysTriggerDateString = dateString(from: .now)

        case .trendsViewed:
            guard conditionNotInCooldown(lastTriggerDateString: lastTrendsTriggerDateString) else { return }
            lastTrendsTriggerDateString = dateString(from: .now)
        }

        // 3. Fire!
        requestReview()
    }

    private func conditionNotInCooldown(lastTriggerDateString: String) -> Bool {
        guard let lastTrigger = date(from: lastTriggerDateString) else {
            return true // 从未触发过
        }
        return daysSince(lastTrigger) >= conditionCooldownDays
    }

    private func requestReview() {
        lastPromptDateString = dateString(from: .now)

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        SKStoreReviewController.requestReview(in: scene)
    }

    // MARK: - Date helpers

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private func date(from string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.date(from: string)
    }

    private func daysSince(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: .now))
        return components.day ?? 0
    }

    private func isConsecutiveDay(last: String, current: String) -> Bool {
        guard let lastDate = date(from: last),
              let currentDate = date(from: current) else {
            return false
        }
        let diff = Calendar.current.dateComponents([.day], from: lastDate, to: currentDate).day ?? 0
        return diff == 1
    }
}
