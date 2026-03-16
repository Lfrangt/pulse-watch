import Foundation
import SwiftData
import os

// MARK: - 配置

/// OpenClaw Gateway 连接配置
struct PulseOpenClawConfig: Codable, Equatable {
    var gatewayURL: String
    var token: String
    var agentID: String

    static let defaultAgentID = "openclaw:main"
    private static let tokenKeychainKey = "pulse.openclaw.token"

    /// 从 UserDefaults + Keychain 加载
    static func load() -> PulseOpenClawConfig? {
        guard let url = UserDefaults.standard.string(forKey: "pulse.openclaw.gatewayURL"),
              let token = KeychainHelper.load(forKey: tokenKeychainKey),
              !url.isEmpty, !token.isEmpty else { return nil }
        let agent = UserDefaults.standard.string(forKey: "pulse.openclaw.agentID") ?? defaultAgentID
        return PulseOpenClawConfig(gatewayURL: url, token: token, agentID: agent)
    }

    /// 保存 — URL/agentID 存 UserDefaults，Token 存 Keychain
    func save() {
        UserDefaults.standard.set(gatewayURL, forKey: "pulse.openclaw.gatewayURL")
        KeychainHelper.save(token, forKey: Self.tokenKeychainKey)
        UserDefaults.standard.set(agentID, forKey: "pulse.openclaw.agentID")
    }

    /// 清除配置
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "pulse.openclaw.gatewayURL")
        KeychainHelper.delete(forKey: tokenKeychainKey)
        UserDefaults.standard.removeObject(forKey: "pulse.openclaw.agentID")
    }

    /// 构建 API endpoint URL
    var completionsURL: URL? {
        let base = gatewayURL.hasSuffix("/") ? String(gatewayURL.dropLast()) : gatewayURL
        return URL(string: "\(base)/v1/chat/completions")
    }

    /// 构建健康检查 URL
    var healthURL: URL? {
        let base = gatewayURL.hasSuffix("/") ? String(gatewayURL.dropLast()) : gatewayURL
        return URL(string: "\(base)/health")
    }
}

// MARK: - Agent 回复模型

/// Agent 返回的健康建议结构
struct AgentHealthAdvice: Codable {
    let morningBrief: String?
    let trainingAdvice: String?
    let alerts: [String]?
    let recoveryScore: Int?
    let summary: String?
}

/// OpenClaw 集成桥接层
/// 通过 HTTP API 向用户的 OpenClaw Gateway 推送健康数据并接收 AI 分析
@Observable
final class OpenClawBridge {

    static let shared = OpenClawBridge()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "OpenClawBridge")

    // MARK: - 状态

    /// 是否启用 OpenClaw 连接
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pulse.openclaw.enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "pulse.openclaw.enabled")
            if newValue {
                Task { @MainActor in
                    await pushHealthStatus()
                }
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

    /// 最新的 agent 分析结果
    var latestAdvice: AgentHealthAdvice?

    /// 配置
    var config: PulseOpenClawConfig? {
        PulseOpenClawConfig.load()
    }

    /// 上次推送的评分（用于检测重大变化）
    private var lastPushedScore: Int?

    /// 推送间隔（秒）
    private let pushInterval: TimeInterval = 1800 // 30 分钟

    /// 重大变化阈值
    private let significantChangeThreshold = 15

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        checkConnection()
    }

    // MARK: - 健康状态数据格式

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
        let scoreTrend: String
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

    // MARK: - 配对验证

    /// 验证 Gateway 连通性 — 先尝试 GET /health，回退到 POST /v1/chat/completions
    func verifyConnection(url: String, token: String) async -> Bool {
        let base = url.hasSuffix("/") ? String(url.dropLast()) : url

        // 1) 尝试 GET /health
        if let healthEndpoint = URL(string: "\(base)/health") {
            var healthReq = URLRequest(url: healthEndpoint)
            healthReq.httpMethod = "GET"
            healthReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            healthReq.timeoutInterval = 10

            if let (_, resp) = try? await session.data(for: healthReq),
               let http = resp as? HTTPURLResponse,
               (200..<300).contains(http.statusCode) {
                return true
            }
        }

        // 2) 回退：POST /v1/chat/completions 发送 ping
        guard let endpoint = URL(string: "\(base)/v1/chat/completions") else { return false }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": PulseOpenClawConfig.defaultAgentID,
            "messages": [["role": "user", "content": "ping"]],
            "max_tokens": 10
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return false }
        request.httpBody = bodyData

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200..<300).contains(http.statusCode)
            }
            return false
        } catch {
            logger.error("Gateway 连通性验证失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 保存配置并验证
    func pair(gatewayURL: String, token: String, agentID: String? = nil) async -> Bool {
        let ok = await verifyConnection(url: gatewayURL, token: token)
        if ok {
            let cfg = PulseOpenClawConfig(
                gatewayURL: gatewayURL,
                token: token,
                agentID: agentID ?? PulseOpenClawConfig.defaultAgentID
            )
            cfg.save()
            await MainActor.run {
                connectionStatus = .connected
            }
            logger.info("OpenClaw Gateway 配对成功")
        }
        return ok
    }

    // MARK: - 推送健康数据

    /// 将健康数据打包发送给 OpenClaw Agent，接收分析结果
    @MainActor
    func pushHealthStatus() async {
        guard isEnabled else { return }
        guard let cfg = config else {
            connectionStatus = .disconnected
            logger.info("未配置 OpenClaw Gateway")
            return
        }
        guard let endpoint = cfg.completionsURL else {
            connectionStatus = .error
            return
        }

        connectionStatus = .syncing

        let status = buildHealthStatus()

        // 将健康数据编码为 JSON 字符串作为 user message
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let statusData = try? encoder.encode(status),
              let statusJSON = String(data: statusData, encoding: .utf8) else {
            connectionStatus = .error
            return
        }

        let messageContent = """
        [HEALTH_DATA]
        \(statusJSON)
        [/HEALTH_DATA]

        请根据以上健康数据，给出今日健康摘要和训练建议。用 JSON 格式回复，包含 morningBrief、trainingAdvice、alerts、recoveryScore、summary 字段。
        """

        let body: [String: Any] = [
            "model": cfg.agentID,
            "messages": [
                ["role": "system", "content": String(localized: "You are Pulse Coach, a personal fitness AI. Analyze HealthKit data and provide health insights and training advice. Reply in JSON.")],
                ["role": "user", "content": messageContent]
            ],
            "max_tokens": 1024
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            connectionStatus = .error
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cfg.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                logger.error("OpenClaw API 错误: HTTP \(code)")
                connectionStatus = .error
                return
            }

            // 解析 OpenAI-compatible 回复
            if let advice = parseAgentResponse(data) {
                latestAdvice = advice
            }

            lastSyncTime = Date()
            lastPushedScore = status.recoveryScore
            connectionStatus = .connected

            // 同时写入 App Group 供 Widget 读取
            writeToAppGroup(status)

            logger.info("健康数据已推送到 OpenClaw — 恢复评分: \(status.recoveryScore)")

        } catch {
            logger.error("推送健康数据失败: \(error.localizedDescription)")
            connectionStatus = .error
        }
    }

    /// 检查是否有重大变化需要立即推送
    @MainActor
    func checkAndPushIfNeeded() {
        guard isEnabled, config != nil else { return }

        let insight = HealthAnalyzer.shared.generateInsight()
        let currentScore = insight.recoveryScore

        var shouldPush = false

        // 评分变化超过阈值
        if let lastScore = lastPushedScore, abs(currentScore - lastScore) >= significantChangeThreshold {
            logger.info("检测到评分重大变化: \(lastScore) → \(currentScore)，立即推送")
            shouldPush = true
        }

        // 超过推送间隔
        if let lastSync = lastSyncTime {
            if Date().timeIntervalSince(lastSync) >= pushInterval {
                shouldPush = true
            }
        } else {
            shouldPush = true // 从未推送过
        }

        if shouldPush {
            Task { @MainActor in
                await pushHealthStatus()
            }
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

        let todaySummary = TodaySummaryPayload(
            date: DailySummary.dateFormatter.string(from: Date()),
            dailyScore: today?.dailyScore,
            sleepHours: today?.sleepDurationMinutes.map { Double($0) / 60.0 },
            deepSleepMinutes: today?.deepSleepMinutes,
            remSleepMinutes: today?.remSleepMinutes,
            totalSteps: today?.totalSteps,
            activeCalories: today?.activeCalories
        )

        let vitalsPayload = VitalsPayload(
            heartRate: vitals.heartRate,
            hrv: vitals.hrv,
            restingHeartRate: vitals.restingHeartRate,
            bloodOxygen: vitals.bloodOxygen,
            lastUpdated: vitals.lastUpdated
        )

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

    // MARK: - 解析 Agent 回复

    /// 解析 OpenAI-compatible chat completion 响应
    private func parseAgentResponse(_ data: Data) -> AgentHealthAdvice? {
        // 标准 OpenAI 格式: { choices: [{ message: { content: "..." } }] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            logger.warning("无法解析 Agent 回复结构")
            return nil
        }

        // 尝试从 content 中提取 JSON
        let jsonContent = extractJSON(from: content)
        if let jsonData = jsonContent.data(using: .utf8),
           let advice = try? JSONDecoder().decode(AgentHealthAdvice.self, from: jsonData) {
            return advice
        }

        // 如果不是 JSON，包装为 summary
        return AgentHealthAdvice(
            morningBrief: nil,
            trainingAdvice: nil,
            alerts: nil,
            recoveryScore: nil,
            summary: content
        )
    }

    /// 从可能包含 markdown code block 的文本中提取 JSON
    private func extractJSON(from text: String) -> String {
        // 匹配 ```json ... ``` 或 ``` ... ```
        if let range = text.range(of: "```(?:json)?\\s*\\n([\\s\\S]*?)\\n```",
                                   options: .regularExpression) {
            let match = text[range]
            // 去掉 ``` 标记
            let lines = match.split(separator: "\n", omittingEmptySubsequences: false)
            if lines.count > 2 {
                return lines.dropFirst().dropLast().joined(separator: "\n")
            }
        }

        // 尝试找第一个 { 到最后一个 }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }

        return text
    }

    // MARK: - App Group (Widget 兼容)

    private static let appGroupID = "group.com.abundra.pulse.shared"

    /// 写入 App Group 供 Widget 读取
    private func writeToAppGroup(_ status: HealthStatus) {
        guard let sharedDefaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        if let data = try? JSONEncoder().encode(status) {
            sharedDefaults.set(data, forKey: "pulse.healthStatus")
            sharedDefaults.set(Date(), forKey: "pulse.healthStatus.timestamp")
        }
    }

    // MARK: - URL Scheme 处理（保持兼容）

    /// 处理来自 OpenClaw 的 URL Scheme 请求
    @MainActor
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "pulse-health" else { return false }
        guard isEnabled else {
            logger.info("OpenClaw 请求被忽略：未启用")
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

    @MainActor
    private func handleQuery(params: [URLQueryItem]) {
        let type = params.first { $0.name == "type" }?.value ?? "status"
        switch type {
        case "status", "vitals", "report":
            Task { @MainActor in
                await pushHealthStatus()
            }
        default:
            logger.info("未知查询类型: \(type)")
        }
    }

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
        case "requestReport", "refreshData":
            Task { @MainActor in
                await pushHealthStatus()
            }
        default:
            logger.info("未知指令: \(action)")
        }
    }

    // MARK: - 连接管理

    private func checkConnection() {
        if isEnabled, config != nil {
            if let lastSync = lastSyncTime,
               Date().timeIntervalSince(lastSync) < 7200 {
                connectionStatus = .connected
            } else {
                connectionStatus = .disconnected
            }
        } else {
            connectionStatus = .disconnected
        }
    }

    // MARK: - 格式化

    var lastSyncDisplay: String {
        guard let time = lastSyncTime else { return String(localized: "Never synced") }

        let interval = Date().timeIntervalSince(time)
        if interval < 60 {
            return String(localized: "Just now")
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
