import TelemetryDeck
import Foundation
import os

/// 统一埋点管理 — 所有事件通过这里发送到 TelemetryDeck
/// 所有 track 方法内置防御性检查，未初始化时静默跳过，避免 crash
enum Analytics {

    // MARK: - 初始化

    private static var isInitialized = false
    private static let logger = Logger(subsystem: "com.abundra.pulse", category: "Analytics")

    /// App 启动时调用一次
    static func initialize() {
        guard !isInitialized else { return }
        let appID = Bundle.main.infoDictionary?["TELEMETRYDECK_APP_ID"] as? String ?? ""
        let fallback = "B5A8E4A0-1F2C-4D3E-9A7B-6C8D0E2F1A3B"
        let resolvedID = appID.isEmpty || appID == "YOUR_TELEMETRYDECK_APP_ID" ? fallback : appID
        let config = TelemetryDeck.Config(appID: resolvedID)
        TelemetryDeck.initialize(config: config)
        isInitialized = true
        logger.info("TelemetryDeck initialized (appID: \(resolvedID.prefix(8))...)")
    }

    // MARK: - 内部发送

    /// 统一信号发送入口 — 未初始化时静默跳过并记录日志
    private static func send(_ signal: String, parameters: [String: String] = [:]) {
        guard isInitialized else {
            logger.warning("Analytics.send(\(signal)) skipped — not initialized")
            return
        }
        TelemetryDeck.signal(signal, parameters: parameters)
    }

    // MARK: - 事件

    /// App 启动
    static func trackAppLaunch() {
        send("app_launch")
    }

    /// 切换 Tab
    static func trackTabSwitch(to tab: String) {
        send("tab_switch", parameters: ["tab": tab])
    }

    /// 健康数据同步完成
    static func trackHealthDataSync(recordCount: Int = 0) {
        send("health_data_sync", parameters: ["record_count": "\(recordCount)"])
    }

    /// 训练开始
    static func trackWorkoutStart(type: String) {
        send("workout_start", parameters: ["type": type])
    }

    /// 训练完成（不发送时长，保护用户行为隐私）
    static func trackWorkoutComplete(type: String) {
        send("workout_complete", parameters: ["type": type])
    }

    /// 到达健身房
    static func trackGymArrival() {
        send("gym_arrival")
    }

    /// 查看评分（不发送评分值，保护健康数据隐私）
    static func trackScoreViewed() {
        send("score_viewed")
    }

    /// 打开设置
    static func trackSettingsOpened() {
        send("settings_opened")
    }

    /// 分享按钮
    static func trackShareTapped(source: String = "unknown") {
        send("share_tapped", parameters: ["source": source])
    }

    /// Onboarding 完成
    static func trackOnboardingCompleted() {
        send("onboarding_completed")
    }

    /// OpenClaw 配对成功
    static func trackOpenClawPaired() {
        send("openclaw_paired")
    }

    /// 周报查看
    static func trackWeeklyReportViewed() {
        send("weekly_report_viewed")
    }
}
