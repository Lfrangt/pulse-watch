import Foundation
import UserNotifications
import SwiftData
import os

/// Morning Brief 通知系统
/// 每日定时推送健康摘要 + 异常实时告警
@Observable
final class MorningBriefService: NSObject {

    static let shared = MorningBriefService()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "MorningBrief")

    // MARK: - 通知标识

    private enum NotificationID {
        static let morningBrief = "com.abundra.pulse.morning-brief"
        static let anomalyPrefix = "com.abundra.pulse.anomaly"
    }

    /// 通知 Category 标识
    private enum CategoryID {
        static let morningBrief = "MORNING_BRIEF"
        static let anomalyAlert = "ANOMALY_ALERT"
    }

    /// Notification Actions
    private enum ActionID {
        static let viewDetail = "VIEW_DETAIL"
        static let skipToday = "SKIP_TODAY"
        static let dismiss = "DISMISS"
    }

    // MARK: - 用户设置

    /// 通知时间（默认 7:30）
    var scheduledHour: Int {
        get {
            let key = "pulse.brief.hour"
            return UserDefaults.standard.object(forKey: key) != nil
                ? UserDefaults.standard.integer(forKey: key)
                : 7
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "pulse.brief.hour")
            rescheduleMorningBrief()
        }
    }

    var scheduledMinute: Int {
        get {
            let key = "pulse.brief.minute"
            return UserDefaults.standard.object(forKey: key) != nil
                ? UserDefaults.standard.integer(forKey: key)
                : 30
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "pulse.brief.minute")
            rescheduleMorningBrief()
        }
    }

    /// 是否启用 Morning Brief
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "pulse.brief.enabled") as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: "pulse.brief.enabled")
            if newValue {
                rescheduleMorningBrief()
            } else {
                cancelMorningBrief()
            }
        }
    }

    /// 今日是否已跳过
    private var skippedToday = false

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - 初始化通知系统

    /// 在 App 启动时调用，注册 categories 并请求权限
    func setup() {
        registerCategories()
        requestAuthorization()
        rescheduleMorningBrief()
        scheduleWeeklyReportReminder()
    }

    /// 请求通知权限
    private func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                self.logger.info("通知权限已获取")
            } else if let error {
                self.logger.error("通知权限请求失败: \(error.localizedDescription)")
            }
        }
        center.delegate = self
    }

    /// 注册通知 Categories 和 Actions
    private func registerCategories() {
        let viewAction = UNNotificationAction(
            identifier: ActionID.viewDetail,
            title: String(localized: "View Details"),
            options: .foreground
        )

        let skipAction = UNNotificationAction(
            identifier: ActionID.skipToday,
            title: String(localized: "Skip Today"),
            options: .destructive
        )

        let dismissAction = UNNotificationAction(
            identifier: ActionID.dismiss,
            title: String(localized: "Got it"),
            options: .destructive
        )

        let morningCategory = UNNotificationCategory(
            identifier: CategoryID.morningBrief,
            actions: [viewAction, skipAction],
            intentIdentifiers: []
        )

        let anomalyCategory = UNNotificationCategory(
            identifier: CategoryID.anomalyAlert,
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([morningCategory, anomalyCategory])
    }

    // MARK: - Morning Brief 定时调度

    /// 调度每日 Morning Brief 通知
    func rescheduleMorningBrief() {
        guard isEnabled else { return }

        let center = UNUserNotificationCenter.current()

        // 先移除旧的
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.morningBrief])

        // 创建定时触发器（每天重复）
        var dateComponents = DateComponents()
        dateComponents.hour = scheduledHour
        dateComponents.minute = scheduledMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // 通知内容在触发时由 Notification Service Extension 动态填充
        // 这里用占位内容，实际在 willPresent / didReceive 中更新
        let content = UNMutableNotificationContent()
        content.title = String(localized: "☀️ Good Morning, Pulse")
        content.body = String(localized: "Daily health summary ready")
        content.sound = .default
        content.categoryIdentifier = CategoryID.morningBrief
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: NotificationID.morningBrief,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                self.logger.error("Morning Brief 调度失败: \(error.localizedDescription)")
            } else {
                self.logger.info("Morning Brief 已调度 → \(self.scheduledHour):\(String(format: "%02d", self.scheduledMinute))")
            }
        }
    }

    /// 取消 Morning Brief
    private func cancelMorningBrief() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [NotificationID.morningBrief])
        logger.info("Morning Brief 已取消")
    }

    // MARK: - 生成 Morning Brief 内容

    /// 从 HealthAnalyzer 生成通知内容（使用 AI 分析引擎）
    @MainActor
    func generateBriefContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = CategoryID.morningBrief
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // 使用 HealthAnalyzer 引擎生成洞察
        let insight = HealthAnalyzer.shared.generateInsight()

        let summary = HealthDataService.shared.fetchTodaySummary()
        let sleepMinutes = summary?.sleepDurationMinutes ?? 0

        // 睡眠显示
        let sleepDisplay: String
        if sleepMinutes > 0 {
            sleepDisplay = "\(sleepMinutes / 60)h\(sleepMinutes % 60)m"
        } else {
            sleepDisplay = String(localized: "No Data")
        }

        content.title = "☀️ Morning · Score \(insight.dailyScore)"
        content.subtitle = "Sleep \(sleepDisplay) · Recovery \(insight.recoveryScore)"
        content.body = insight.insights.first ?? insight.trainingAdvice.label

        return content
    }

    // MARK: - 异常告警

    /// 检查异常并主动推送告警
    /// 由 HealthKitService 在数据更新后调用
    /// 使用 HealthAnalyzer 的标准差方法进行个性化异常检测
    @MainActor
    func checkAndNotifyAnomalies() {
        guard !skippedToday else { return }

        // 使用 HealthAnalyzer 引擎的异常检测（基于个人基线标准差）
        let insight = HealthAnalyzer.shared.generateInsight()
        let detectedAnomalies = insight.anomalies

        for (index, anomaly) in detectedAnomalies.enumerated() {
            // 只推送 medium 及以上级别
            guard anomaly.severity >= .medium else { continue }

            let content = UNMutableNotificationContent()
            content.categoryIdentifier = CategoryID.anomalyAlert
            content.interruptionLevel = anomaly.severity == .high ? .critical : .timeSensitive
            content.title = anomaly.severity == .high ? "🔴 \(anomaly.message)" : "⚠️ \(anomaly.message)"
            content.body = anomaly.detail
            content.sound = anomaly.severity == .high ? .defaultCritical : .default

            let identifier = "\(NotificationID.anomalyPrefix).\(index).\(Date().timeIntervalSince1970)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil // 立即推送
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    self.logger.error("异常告警推送失败: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 评分计算

    /// 睡眠质量评分 (0-100)
    private func calculateSleepScore(minutes: Int, deep: Int) -> Int {
        var score = 0

        // 时长评分 (0-60分)
        switch minutes {
        case 450...: score += 60        // 7.5h+ 满分
        case 420..<450: score += 55     // 7h+
        case 390..<420: score += 45     // 6.5h+
        case 360..<390: score += 35     // 6h+
        case 300..<360: score += 20     // 5h+
        default: score += 5
        }

        // 深睡评分 (0-40分)
        switch deep {
        case 90...: score += 40         // 1.5h+ 深睡
        case 60..<90: score += 30       // 1h+
        case 30..<60: score += 20       // 0.5h+
        default: score += 5
        }

        return min(score, 100)
    }

    /// 恢复评分 (0-100)，基于 HRV 和静息心率
    private func calculateRecoveryScore(hrv: Double?, restingHR: Double?) -> Int {
        var score = 50

        if let hrv {
            if hrv > 65 { score += 25 }
            else if hrv > 50 { score += 15 }
            else if hrv > 35 { score += 5 }
            else { score -= 15 }
        }

        if let rhr = restingHR {
            if rhr < 55 { score += 20 }
            else if rhr < 60 { score += 15 }
            else if rhr < 65 { score += 5 }
            else if rhr > 75 { score -= 10 }
            else if rhr > 85 { score -= 20 }
        }

        return max(0, min(100, score))
    }

    /// 一句话建议
    private func generateAdvice(score: Int, sleepMinutes: Int, hrv: Double?) -> String {
        if score >= 80 {
            return String(localized: "Ready for high intensity today 💪")
        } else if score >= 65 {
            if sleepMinutes < 360 {
                return String(localized: "Short on sleep — train but don't overdo it")
            }
            return String(localized: "Decent — train normally")
        } else if score >= 45 {
            if let hrv, hrv < 30 {
                return String(localized: "HRV low — consider a light recovery day 🧘")
            }
            return String(localized: "Light recovery day — walk or stretch")
        } else {
            return String(localized: "Your body says stop — rest up 😴")
        }
    }

    // MARK: - 周报提醒

    /// 每周日晚 20:00 推送周报提醒
    func scheduleWeeklyReportReminder() {
        let center = UNUserNotificationCenter.current()
        let identifier = "com.abundra.pulse.weekly-report"

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // 周日
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "📊 Weekly health report ready")
        content.body = String(localized: "Your weekly health performance, trends, and advice")
        content.sound = .default
        content.categoryIdentifier = CategoryID.morningBrief
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                self.logger.error("周报提醒调度失败: \(error.localizedDescription)")
            } else {
                self.logger.info("周报提醒已调度 → 每周日 20:00")
            }
        }
    }

    // MARK: - 手动触发（用于测试 / 刷新）

    /// 立即推送一次 Morning Brief（用于手动测试）
    @MainActor
    func sendBriefNow() {
        let content = generateBriefContent()

        let request = UNNotificationRequest(
            identifier: "\(NotificationID.morningBrief).manual",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                self.logger.error("手动 Brief 推送失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension MorningBriefService: UNUserNotificationCenterDelegate {

    /// 前台收到通知 — 仍然显示
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// 用户点击通知 Action
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case ActionID.viewDetail:
            // 发送通知让 App 导航到详情页
            NotificationCenter.default.post(name: .morningBriefTapped, object: nil)

        case ActionID.skipToday:
            skippedToday = true
            logger.info("用户选择跳过今天的通知")

        case ActionID.dismiss:
            break

        case UNNotificationDefaultActionIdentifier:
            // 用户直接点击通知横幅
            NotificationCenter.default.post(name: .morningBriefTapped, object: nil)

        default:
            break
        }

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Morning Brief 被点击，App 应导航到详情
    static let morningBriefTapped = Notification.Name("pulse.morningBriefTapped")
}

