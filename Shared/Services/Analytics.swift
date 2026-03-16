import TelemetryDeck
import Foundation

/// 统一埋点管理 — 所有事件通过这里发送到 TelemetryDeck
enum Analytics {

    // MARK: - 初始化

    /// App 启动时调用一次
    static func initialize() {
        let config = TelemetryDeck.Config(
            appID: "YOUR_TELEMETRYDECK_APP_ID"  // TODO: 替换为真实 App ID
        )
        TelemetryDeck.initialize(config: config)
    }

    // MARK: - 事件

    /// App 启动
    static func trackAppLaunch() {
        TelemetryDeck.signal("app_launch")
    }

    /// 切换 Tab
    static func trackTabSwitch(to tab: String) {
        TelemetryDeck.signal("tab_switch", parameters: ["tab": tab])
    }

    /// 健康数据同步完成
    static func trackHealthDataSync(recordCount: Int = 0) {
        TelemetryDeck.signal("health_data_sync", parameters: [
            "record_count": "\(recordCount)"
        ])
    }

    /// 训练开始
    static func trackWorkoutStart(type: String) {
        TelemetryDeck.signal("workout_start", parameters: ["type": type])
    }

    /// 训练完成
    static func trackWorkoutComplete(type: String, durationMinutes: Int = 0) {
        TelemetryDeck.signal("workout_complete", parameters: [
            "type": type,
            "duration_minutes": "\(durationMinutes)"
        ])
    }

    /// 到达健身房
    static func trackGymArrival() {
        TelemetryDeck.signal("gym_arrival")
    }

    /// 查看评分
    static func trackScoreViewed(score: Int? = nil) {
        var params: [String: String] = [:]
        if let score { params["score"] = "\(score)" }
        TelemetryDeck.signal("score_viewed", parameters: params)
    }

    /// 打开设置
    static func trackSettingsOpened() {
        TelemetryDeck.signal("settings_opened")
    }

    /// 分享按钮
    static func trackShareTapped(source: String = "unknown") {
        TelemetryDeck.signal("share_tapped", parameters: ["source": source])
    }

    /// Onboarding 完成
    static func trackOnboardingCompleted() {
        TelemetryDeck.signal("onboarding_completed")
    }

    /// OpenClaw 配对成功
    static func trackOpenClawPaired() {
        TelemetryDeck.signal("openclaw_paired")
    }

    /// 周报查看
    static func trackWeeklyReportViewed() {
        TelemetryDeck.signal("weekly_report_viewed")
    }
}
