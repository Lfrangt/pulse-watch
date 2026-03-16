import Foundation
import UserNotifications
import SwiftData
import os

/// 心率异常检测 + 本地通知推送服务
/// 后台监测静息心率，超出安全阈值时推送通知，1小时内不重复提醒
@Observable
final class HeartRateAlertService {

    static let shared = HeartRateAlertService()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "HeartRateAlert")

    // MARK: - 通知标识

    private enum NotificationID {
        static let prefix = "com.abundra.pulse.hr-alert"
    }

    private enum CategoryID {
        static let heartRateAlert = "HEART_RATE_ALERT"
    }

    private enum ActionID {
        static let viewDetail = "HR_ALERT_VIEW"
        static let dismiss = "HR_ALERT_DISMISS"
    }

    // MARK: - 用户设置 (AppStorage keys)

    /// 心率提醒总开关
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "pulse.hr.alert.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.hr.alert.enabled") }
    }

    /// 高心率阈值 (bpm)
    var highThreshold: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "pulse.hr.alert.high")
            return val > 0 ? val : 120
        }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.hr.alert.high") }
    }

    /// 低心率阈值 (bpm)
    var lowThreshold: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "pulse.hr.alert.low")
            return val > 0 ? val : 40
        }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.hr.alert.low") }
    }

    /// 上次告警时间（同一异常 1 小时内不重复）
    private var lastAlertDate: Date? {
        get { UserDefaults.standard.object(forKey: "pulse.hr.alert.lastDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.hr.alert.lastDate") }
    }

    /// SwiftData ModelContainer — 由 App 启动时注入
    var modelContainer: ModelContainer?

    private init() {}

    // MARK: - 注册通知 Category

    /// 注册心率告警通知类别（app 启动时调用）
    func registerCategory() {
        let viewAction = UNNotificationAction(
            identifier: ActionID.viewDetail,
            title: String(localized: "View Details"),
            options: .foreground
        )

        let dismissAction = UNNotificationAction(
            identifier: ActionID.dismiss,
            title: String(localized: "Got it"),
            options: .destructive
        )

        let category = UNNotificationCategory(
            identifier: CategoryID.heartRateAlert,
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )

        // 追加到现有 categories（不覆盖 MorningBrief 的）
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { existing in
            var categories = existing
            // 移除旧的同名 category（如果有），再加新的
            categories = categories.filter { $0.identifier != CategoryID.heartRateAlert }
            categories.insert(category)
            center.setNotificationCategories(categories)
        }
    }

    // MARK: - 检测 + 告警

    /// HealthKitService 数据更新后调用，检查最新静息心率是否异常
    /// - Parameter restingHeartRate: 最新静息心率 (bpm)
    @MainActor
    func checkHeartRate(_ restingHeartRate: Double) {
        guard isEnabled else { return }

        // 1小时冷却
        if let last = lastAlertDate, Date().timeIntervalSince(last) < 3600 {
            return
        }

        let bpm = Int(restingHeartRate)

        if bpm >= highThreshold {
            triggerAlert(heartRate: restingHeartRate, type: "high", threshold: Double(highThreshold))
        } else if bpm > 0 && bpm <= lowThreshold {
            triggerAlert(heartRate: restingHeartRate, type: "low", threshold: Double(lowThreshold))
        }
    }

    /// 触发告警：推送通知 + 记录事件
    private func triggerAlert(heartRate: Double, type: String, threshold: Double) {
        let bpm = Int(heartRate)

        // 推送本地通知
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = CategoryID.heartRateAlert
        content.interruptionLevel = .timeSensitive
        content.sound = .default

        if type == "high" {
            content.title = String(localized: "⚠️ High Heart Rate Alert")
            content.body = String(localized: "Your resting heart rate is \(bpm) bpm, above your \(Int(threshold)) bpm threshold. Consider resting and monitoring.")
        } else {
            content.title = String(localized: "⚠️ Low Heart Rate Alert")
            content.body = String(localized: "Your resting heart rate is \(bpm) bpm, below your \(Int(threshold)) bpm threshold. If you feel dizzy, seek medical attention.")
        }

        let identifier = "\(NotificationID.prefix).\(type).\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // 立即推送
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                self.logger.error("心率告警推送失败: \(error.localizedDescription)")
            } else {
                self.logger.info("心率告警已推送: \(type) \(bpm)bpm")
            }
        }

        // 更新冷却时间
        lastAlertDate = Date()

        // 记录到 SwiftData
        Task { @MainActor in
            self.saveAlertEvent(heartRate: heartRate, type: type, threshold: threshold)
        }
    }

    // MARK: - 事件持久化

    /// 保存异常事件到 SwiftData
    @MainActor
    private func saveAlertEvent(heartRate: Double, type: String, threshold: Double) {
        guard let container = modelContainer else {
            logger.warning("HeartRateAlertService: modelContainer 未注入，无法保存事件")
            return
        }

        let context = container.mainContext
        let event = HeartRateAlertEvent(
            heartRate: heartRate,
            alertType: type,
            threshold: threshold
        )
        context.insert(event)

        do {
            try context.save()
            logger.info("心率异常事件已记录: \(type) \(Int(heartRate))bpm")
        } catch {
            logger.error("心率异常事件保存失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 历史查询

    /// 获取最近 N 天的异常事件
    @MainActor
    func fetchRecentAlerts(days: Int = 30) -> [HeartRateAlertEvent] {
        guard let container = modelContainer else { return [] }

        let context = container.mainContext
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        let predicate = #Predicate<HeartRateAlertEvent> { $0.timestamp >= startDate }
        var descriptor = FetchDescriptor<HeartRateAlertEvent>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchLimit = 50

        return (try? context.fetch(descriptor)) ?? []
    }
}
