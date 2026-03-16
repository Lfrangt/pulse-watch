import StoreKit
import SwiftUI

/// App Store 评价引导管理器
/// 触发条件（任一满足）：完成第3次workout / 连续使用7天 / 查看评分≥10次
/// 每个版本最多请求一次
@MainActor
final class ReviewManager: ObservableObject {

    static let shared = ReviewManager()

    // MARK: - 持久化计数器（@AppStorage）

    @AppStorage("pulse.review.workoutCount") private var workoutCount: Int = 0
    @AppStorage("pulse.review.scoreViewCount") private var scoreViewCount: Int = 0
    @AppStorage("pulse.review.consecutiveDays") private var consecutiveDays: Int = 0
    @AppStorage("pulse.review.lastActiveDate") private var lastActiveDateString: String = ""
    @AppStorage("pulse.review.lastRequestedVersion") private var lastRequestedVersion: String = ""

    // MARK: - 阈值

    private let workoutThreshold = 3
    private let consecutiveDaysThreshold = 7
    private let scoreViewThreshold = 10

    private init() {}

    // MARK: - 事件记录

    /// 用户完成一次 workout 时调用
    func recordWorkoutCompleted() {
        workoutCount += 1
        tryRequestReview()
    }

    /// 同步 HealthKit workout 总数（避免重复计数）
    func syncWorkoutCount(_ total: Int) {
        guard total > workoutCount else { return }
        workoutCount = total
        tryRequestReview()
    }

    /// 用户查看评分时调用
    func recordScoreViewed() {
        scoreViewCount += 1
        tryRequestReview()
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
        tryRequestReview()
    }

    // MARK: - 核心逻辑

    private func tryRequestReview() {
        guard shouldRequestReview() else { return }
        requestReview()
    }

    private func shouldRequestReview() -> Bool {
        // 当前版本已请求过 → 跳过
        let currentVersion = appVersion
        guard lastRequestedVersion != currentVersion else { return false }

        // 任一条件满足即可触发
        let workoutMet = workoutCount >= workoutThreshold
        let daysMet = consecutiveDays >= consecutiveDaysThreshold
        let scoreViewMet = scoreViewCount >= scoreViewThreshold

        return workoutMet || daysMet || scoreViewMet
    }

    private func requestReview() {
        lastRequestedVersion = appVersion

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        SKStoreReviewController.requestReview(in: scene)
    }

    // MARK: - 辅助

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    /// 判断两个日期字符串是否是连续天
    private func isConsecutiveDay(last: String, current: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        guard let lastDate = formatter.date(from: last),
              let currentDate = formatter.date(from: current) else {
            return false
        }

        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: lastDate, to: currentDate).day ?? 0
        return diff == 1
    }
}
