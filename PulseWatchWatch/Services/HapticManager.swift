import WatchKit

/// Watch 触觉反馈统一管理器
/// 在关键交互节点提供触觉反馈，增强体感
enum HapticManager {

    /// 评分刷新完成 — 成功感
    static func scoreRefreshed() {
        WKInterfaceDevice.current().play(.success)
    }

    /// 异常告警（评分过低/指标异常）— 警告感
    static func alertTriggered() {
        WKInterfaceDevice.current().play(.failure)
    }

    /// 训练开始 — 启动感
    static func workoutStarted() {
        WKInterfaceDevice.current().play(.start)
    }

    /// 训练结束 — 停止感
    static func workoutStopped() {
        WKInterfaceDevice.current().play(.stop)
    }

    /// Complication / 导航点击 — 轻触感
    static func tap() {
        WKInterfaceDevice.current().play(.click)
    }

    /// 下拉刷新 — 方向感
    static func pullToRefresh() {
        WKInterfaceDevice.current().play(.directionUp)
    }
}
