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
        get { UserDefaults.standard.integer(forKey: "pulse.brief.hour").nonZero ?? 7 }
        set {
            UserDefaults.standard.set(newValue, forKey: "pulse.brief.hour")
            rescheduleMorningBrief()
        }
    }

    var scheduledMinute: Int {
        get { UserDefaults.standard.integer(forKey: "pulse.brief.minute").nonZero ?? 30 }
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
            title: "查看详情",
            options: .foreground
        )

        let skipAction = UNNotificationAction(
            identifier: ActionID.skipToday,
            title: "跳过今天",
            options: .destructive
        )

        let dismissAction = UNNotificationAction(
            identifier: ActionID.dismiss,
            title: "知道了",
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
        content.title = "☀️ 早安 Pulse"
        content.body = "今日健康摘要已准备好，点击查看"
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
            sleepDisplay = "无数据"
        }

        content.title = "☀️ 早安 · 状态 \(insight.dailyScore)分"
        content.subtitle = "睡眠 \(sleepDisplay) · 恢复 \(insight.recoveryScore)分"
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
            return "今天适合高强度训练 💪"
        } else if score >= 65 {
            if sleepMinutes < 360 {
                return "睡眠偏少，训练可以但别过猛"
            }
            return "状态还不错，正常安排训练"
        } else if score >= 45 {
            if let hrv, hrv < 30 {
                return "HRV 偏低，建议轻松恢复日 🧘"
            }
            return "建议轻松恢复日，散步或拉伸"
        } else {
            return "身体在喊停，今天好好休息吧 😴"
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

// MARK: - Helper

private extension Int {
    /// 返回非零值，零值返回 nil（用于 UserDefaults 默认值处理）
    var nonZero: Int? { self != 0 ? self : nil }
}
