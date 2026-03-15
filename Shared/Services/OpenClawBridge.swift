import Foundation
import SwiftData
import os

/// OpenClaw 集成桥接层
/// 通过 App Group UserDefaults + URL Scheme 向 OpenClaw agent 暴露健康状态
/// 支持定时推送和按需查询
@Observable
final class OpenClawBridge {

    static let shared = OpenClawBridge()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "OpenClawBridge")

    /// App Group 标识（与 OpenClaw 共享）
    static let appGroupID = "group.com.abundra.pulse.shared"

    /// 共享 UserDefaults
    private let sharedDefaults = UserDefaults(suiteName: OpenClawBridge.appGroupID)

    /// URL Scheme 标识
    static let urlScheme = "pulse-health"

    // MARK: - 状态

    /// 是否启用数据共享
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pulse.openclaw.enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "pulse.openclaw.enabled")
            if newValue {
                Task { @MainActor in
                    pushHealthStatus()
                }
            } else {
                clearSharedData()
            }
        }
    }

    /// 连接状态
    var connectionStatus: ConnectionStatus = .disconnected

    /// 最后同步时间
    var lastSyncTime: Date? {
        get { UserDefaults.standard.object(forKey: "pulse.openclaw.lastSync") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "pulse.openclaw.lastSync") }
    }

    /// 上次推送的评分（用于检测重大变化）
    private var lastPushedScore: Int?

    private init() {
        // 检查连接状态
        checkConnection()
    }

    // MARK: - 健康状态数据格式

    /// 完整健康状态 JSON 结构
    struct HealthStatus: Codable {
        let timestamp: Date
        let lastSyncTime: Date
        let todaySummary: TodaySummaryPayload
        let latestVitals: VitalsPayload
        let weekTrend: WeekTrendPayload
        let recoveryScore: Int
        let trainingAdvice: String
    }

    struct TodaySummaryPayload: Codable {
        let date: String
        let dailyScore: Int?
        let sleepHours: Double?
        let deepSleepMinutes: Int?
        let remSleepMinutes: Int?
        let totalSteps: Int?
        let activeCalories: Double?
    }

    struct VitalsPayload: Codable {
        let heartRate: Double?
        let hrv: Double?
        let restingHeartRate: Double?
        let bloodOxygen: Double?
        let lastUpdated: Date?
    }

    struct WeekTrendPayload: Codable {
        let averageScore: Int?
        let scoreTrend: String      // "improving" / "stable" / "declining"
        let hrvTrend: String
        let sleepTrend: String
        let dailyScores: [DayScore]
    }

    struct DayScore: Codable {
        let date: String
        let score: Int
    }

    // MARK: - 连接状态

    enum ConnectionStatus: String {
        case connected = "已连接"
        case disconnected = "未连接"
        case syncing = "同步中"
        case error = "连接错误"

        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "circle.dotted"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var color: String {
            switch self {
            case .connected: return "7FB069"
            case .disconnected: return "5C564F"
            case .syncing: return "D4A056"
            case .error: return "C75C5C"
            }
        }
    }

    // MARK: - 推送健康状态

    /// 生成并推送当前健康状态到 OpenClaw
    /// 通过 App Group UserDefaults 共享数据
    @MainActor
    func pushHealthStatus() {
        guard isEnabled else { return }

        connectionStatus = .syncing

        let status = buildHealthStatus()

        // 写入 App Group UserDefaults
        if let data = try? JSONEncoder().encode(status) {
            sharedDefaults?.set(data, forKey: "pulse.healthStatus")
            sharedDefaults?.set(Date(), forKey: "pulse.healthStatus.timestamp")
            sharedDefaults?.synchronize()
        }

        // 同时写入标准 UserDefaults 作为备份
        if let jsonData = try? JSONEncoder().encode(status),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            UserDefaults.standard.set(jsonString, forKey: "pulse.openclaw.latestStatus")
        }

        lastSyncTime = Date()
        lastPushedScore = status.recoveryScore
        connectionStatus = .connected

        logger.info("健康状态已推送到 OpenClaw — 恢复评分: \(status.recoveryScore)")
    }

    /// 检查是否有重大变化需要立即推送
    @MainActor
    func checkAndPushIfNeeded() {
        guard isEnabled else { return }

        let insight = HealthAnalyzer.shared.generateInsight()
        let currentScore = insight.recoveryScore

        // 评分变化超过 15 分视为重大变化
        if let lastScore = lastPushedScore, abs(currentScore - lastScore) >= 15 {
            logger.info("检测到评分重大变化: \(lastScore) → \(currentScore)，立即推送")
            pushHealthStatus()
            return
        }

        // 检查上次推送时间，超过 1 小时自动推送
        if let lastSync = lastSyncTime {
            let interval = Date().timeIntervalSince(lastSync)
            if interval >= 3600 { // 1 小时
                pushHealthStatus()
            }
        } else {
            // 从未推送过
            pushHealthStatus()
        }
    }

    // MARK: - 构建数据

    @MainActor
    private func buildHealthStatus() -> HealthStatus {
        let dataService = HealthDataService.shared
        let today = dataService.fetchTodaySummary()
        let week = dataService.fetchWeekTrend(days: 7)
        let vitals = dataService.getLatestVitals()
        let insight = HealthAnalyzer.shared.generateInsight()

        // 今日摘要
        let todaySummary = TodaySummaryPayload(
            date: DailySummary.dateFormatter.string(from: Date()),
            dailyScore: today?.dailyScore,
            sleepHours: today?.sleepDurationMinutes.map { Double($0) / 60.0 },
            deepSleepMinutes: today?.deepSleepMinutes,
            remSleepMinutes: today?.remSleepMinutes,
            totalSteps: today?.totalSteps,
            activeCalories: today?.activeCalories
        )

        // 最新生命体征
        let vitalsPayload = VitalsPayload(
            heartRate: vitals.heartRate,
            hrv: vitals.hrv,
            restingHeartRate: vitals.restingHeartRate,
            bloodOxygen: vitals.bloodOxygen,
            lastUpdated: vitals.lastUpdated
        )

        // 周趋势
        let scores = week.compactMap(\.dailyScore)
        let avgScore = scores.isEmpty ? nil : scores.reduce(0, +) / scores.count
        let dailyScores = week.compactMap { s -> DayScore? in
            guard let score = s.dailyScore else { return nil }
            return DayScore(date: s.dateString, score: score)
        }

        let weekTrend = WeekTrendPayload(
            averageScore: avgScore,
            scoreTrend: insight.trends.scoreTrend.rawValue,
            hrvTrend: insight.trends.hrvTrend.rawValue,
            sleepTrend: insight.trends.sleepTrend.rawValue,
            dailyScores: dailyScores
        )

        return HealthStatus(
            timestamp: Date(),
            lastSyncTime: Date(),
            todaySummary: todaySummary,
            latestVitals: vitalsPayload,
            weekTrend: weekTrend,
            recoveryScore: insight.recoveryScore,
            trainingAdvice: insight.trainingAdvice.rawValue
        )
    }

    // MARK: - URL Scheme 处理

    /// 处理来自 OpenClaw 的 URL Scheme 请求
    /// 格式: pulse-health://query?type=status
    /// 格式: pulse-health://command?action=setNotificationTime&hour=7&minute=30
    @MainActor
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == Self.urlScheme else { return false }
        guard isEnabled else {
            logger.info("OpenClaw 请求被忽略：数据共享未启用")
            return false
        }

        let host = url.host()
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        switch host {
        case "query":
            handleQuery(params: params)
            return true

        case "command":
            handleCommand(params: params)
            return true

        default:
            logger.warning("未知的 OpenClaw 请求: \(url.absoluteString)")
            return false
        }
    }

    /// 处理查询请求
    @MainActor
    private func handleQuery(params: [URLQueryItem]) {
        let type = params.first { $0.name == "type" }?.value ?? "status"

        switch type {
        case "status":
            pushHealthStatus()

        case "vitals":
            let vitals = HealthDataService.shared.getLatestVitals()
            if let data = try? JSONEncoder().encode(
                VitalsPayload(
                    heartRate: vitals.heartRate,
                    hrv: vitals.hrv,
                    restingHeartRate: vitals.restingHeartRate,
                    bloodOxygen: vitals.bloodOxygen,
                    lastUpdated: vitals.lastUpdated
                )
            ) {
                sharedDefaults?.set(data, forKey: "pulse.queryResponse")
                sharedDefaults?.synchronize()
            }

        case "report":
            // 触发完整报告生成
            pushHealthStatus()

        default:
            logger.info("未知查询类型: \(type)")
        }
    }

    /// 处理来自 OpenClaw 的指令
    @MainActor
    private func handleCommand(params: [URLQueryItem]) {
        guard let action = params.first(where: { $0.name == "action" })?.value else { return }

        switch action {
        case "setNotificationTime":
            #if os(iOS)
            if let hourStr = params.first(where: { $0.name == "hour" })?.value,
               let minuteStr = params.first(where: { $0.name == "minute" })?.value,
               let hour = Int(hourStr), let minute = Int(minuteStr),
               (5...11).contains(hour), [0, 15, 30, 45].contains(minute) {
                MorningBriefService.shared.scheduledHour = hour
                MorningBriefService.shared.scheduledMinute = minute
                logger.info("OpenClaw 设置通知时间: \(hour):\(String(format: "%02d", minute))")
            }
            #endif

        case "requestReport":
            pushHealthStatus()

        case "refreshData":
            pushHealthStatus()

        default:
            logger.info("未知指令: \(action)")
        }
    }

    // MARK: - 连接管理

    /// 检查 OpenClaw 连接状态
    private func checkConnection() {
        if isEnabled {
            // 检查 App Group 是否可用
            if sharedDefaults != nil {
                // 检查最后同步时间
                if let lastSync = lastSyncTime,
                   Date().timeIntervalSince(lastSync) < 7200 { // 2 小时内
                    connectionStatus = .connected
                } else {
                    connectionStatus = .disconnected
                }
            } else {
                connectionStatus = .error
                logger.error("App Group UserDefaults 不可用")
            }
        } else {
            connectionStatus = .disconnected
        }
    }

    /// 清除共享数据
    private func clearSharedData() {
        sharedDefaults?.removeObject(forKey: "pulse.healthStatus")
        sharedDefaults?.removeObject(forKey: "pulse.healthStatus.timestamp")
        sharedDefaults?.removeObject(forKey: "pulse.queryResponse")
        sharedDefaults?.synchronize()
        connectionStatus = .disconnected
        logger.info("已清除 OpenClaw 共享数据")
    }

    // MARK: - 格式化

    /// 最后同步时间的显示文本
    var lastSyncDisplay: String {
        guard let time = lastSyncTime else { return "从未同步" }

        let interval = Date().timeIntervalSince(time)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600)) 小时前"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "M月d日 HH:mm"
            return fmt.string(from: time)
        }
    }
}
