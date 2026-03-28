import TelemetryDeck
import Foundation

/// 统一埋点管理 — 所有事件通过这里发送到 TelemetryDeck
enum Analytics {

    // MARK: - 初始化

    /// App 启动时调用一次
    static func initialize() {
        // TelemetryDeck App ID — set via TELEMETRYDECK_APP_ID in build settings
        // or replace with your real App ID from https://dashboard.telemetrydeck.com
        let appID = Bundle.main.infoDictionary?["TELEMETRYDECK_APP_ID"] as? String
            ?? "B5A8E4A0-1F2C-4D3E-9A7B-6C8D0E2F1A3B"
        guard !appID.isEmpty, appID != "YOUR_TELEMETRYDECK_APP_ID" else {
            // Skip analytics initialization if no valid App ID configured
            return
        }
        let config = TelemetryDeck.Config(appID: appID)
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

    /// 训练完成（不发送时长，保护用户行为隐私）
    static func trackWorkoutComplete(type: String) {
        TelemetryDeck.signal("workout_complete", parameters: [
            "type": type
        ])
    }

    /// 到达健身房
    static func trackGymArrival() {
        TelemetryDeck.signal("gym_arrival")
    }

    /// 查看评分（不发送评分值，保护健康数据隐私）
    static func trackScoreViewed() {
        TelemetryDeck.signal("score_viewed")
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
