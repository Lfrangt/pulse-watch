import Foundation
import SwiftData
import os
#if os(iOS)
import BackgroundTasks
#endif

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

/// OpenClaw 下发的待写入训练记录
struct PendingWorkoutEntry: Codable {
    let id: String            // UUID string, 用于去重
    let type: String          // "strength", "running", "cycling" 等
    let timestamp: String?    // ISO 8601
    let durationMinutes: Int?
    let notes: String?
    let muscleGroups: [String]?
}

/// Agent 返回的健康建议结构
struct AgentHealthAdvice: Codable {
    let morningBrief: String?
    let trainingAdvice: String?
    let alerts: [String]?
    let recoveryScore: Int?
    let summary: String?
    let pendingWorkouts: [PendingWorkoutEntry]?
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

    /// SwiftData ModelContainer，由 App 在启动时注入，用于写入训练记录
    var modelContainer: ModelContainer?

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
        let recentWorkouts: [RecentWorkoutPayload]?
    }

    struct RecentWorkoutPayload: Codable {
        let activityType: String
        let date: String
        let durationMinutes: Int
        let calories: Double?
        let averageHeartRate: Double?
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
        case connected = "Connected"
        case disconnected = "Disconnected"
        case syncing = "Syncing"
        case error = "Error"

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
                // 确保 isEnabled = true，触发数据推送
                UserDefaults.standard.set(true, forKey: "pulse.openclaw.enabled")
            }
            logger.info("OpenClaw Gateway 配对成功")
            // 配对成功后立即推送健康数据
            await pushHealthStatus()
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

        // Build health_sync format expected by Health Coach skill
        let healthSyncJSON = buildHealthSyncJSON(from: status)

        let messageContent = """
        [HEALTH_DATA]
        \(healthSyncJSON)
        [/HEALTH_DATA]

        This is an automated health sync from the user's PulseWatch app.

        REQUIRED: Reply ONLY with a JSON object with these fields:
        {
          "morningBrief": "string or null",
          "trainingAdvice": "string or null",
          "alerts": [],
          "recoveryScore": number or null,
          "summary": "string or null",
          "pendingWorkouts": []
        }

        For the "pendingWorkouts" field: read the file at ~/workspace/pulse-pending-workouts.json using the exec tool, extract the "pending" array, and include it in your reply. After including it, clear the file with: echo '{"pending":[]}' > ~/workspace/pulse-pending-workouts.json
        If the file is empty or doesn't exist, use [].
        """

        let body: [String: Any] = [
            "model": cfg.agentID,
            "messages": [
                ["role": "system", "content": "You are Pulse Coach. When you receive a health_sync message, you MUST: 1) Read ~/workspace/pulse-pending-workouts.json with exec tool 2) Include its pending[] array in pendingWorkouts field of your JSON reply 3) Clear the file after reading. Always reply with valid JSON only, no markdown."],
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
                // 处理 OpenClaw 下发的待写入训练记录（agent 回复路径）
                if let pending = advice.pendingWorkouts, !pending.isEmpty {
                    await processPendingWorkouts(pending)
                }
            }

            // 主动拉取 pending queue（不依赖 agent 在回复里携带）
            await fetchAndProcessPendingQueue(cfg: cfg)

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

        // Recent workouts (last 7 days)
        let recentWorkouts = dataService.fetchRecentWorkouts(days: 7).map { entry in
            RecentWorkoutPayload(
                activityType: entry.activityName,
                date: DailySummary.dateFormatter.string(from: entry.startDate),
                durationMinutes: Int(entry.durationSeconds / 60),
                calories: entry.totalCalories,
                averageHeartRate: entry.averageHeartRate
            )
        }

        return HealthStatus(
            timestamp: Date(),
            lastSyncTime: Date(),
            todaySummary: todaySummary,
            latestVitals: vitalsPayload,
            weekTrend: weekTrend,
            recoveryScore: insight.recoveryScore,
            trainingAdvice: insight.trainingAdvice.rawValue,
            recentWorkouts: recentWorkouts.isEmpty ? nil : recentWorkouts
        )
    }

    // MARK: - health_sync Format

    /// Convert internal HealthStatus into the health_sync JSON format expected by Health Coach.
    @MainActor
    private func buildHealthSyncJSON(from status: HealthStatus) -> String {
        let dateStr = DailySummary.dateFormatter.string(from: Date())
        let ts = status.todaySummary
        let v = status.latestVitals

        // Compute light sleep = total - deep - rem (if available)
        let totalSleepMin = ts.sleepHours.map { Int($0 * 60) }
        let lightMin: Int? = {
            guard let total = totalSleepMin else { return nil }
            let deep = ts.deepSleepMinutes ?? 0
            let rem = ts.remSleepMinutes ?? 0
            let light = total - deep - rem
            return light > 0 ? light : nil
        }()

        // Build workouts array including Watch real-time data
        var workouts: [[String: Any]] = (status.recentWorkouts ?? []).map { w in
            var workout: [String: Any] = [
                "type": w.activityType,
                "date": w.date,
                "durationMinutes": w.durationMinutes
            ]
            if let cal = w.calories { workout["calories"] = Int(cal) }
            if let hr = w.averageHeartRate { workout["averageHeartRate"] = Int(hr) }
            return workout
        }

        // Append pending Watch workout if recent
        if let w = lastWatchWorkout,
           Date().timeIntervalSince(w.timestamp) < 300 {
            workouts.insert([
                "type": w.category,
                "date": dateStr,
                "durationMinutes": w.durationSeconds / 60,
                "calories": Int(w.activeCalories),
                "averageHeartRate": Int(w.averageHeartRate),
                "maxHeartRate": Int(w.maxHeartRate),
                "source": "watch_realtime"
            ], at: 0)
            lastWatchWorkout = nil
        }

        var metrics: [String: Any] = [:]

        // Heart rate
        var hr: [String: Any] = [:]
        if let resting = v.restingHeartRate { hr["resting"] = Int(resting) }
        if let current = v.heartRate { hr["average"] = Int(current) }
        if !hr.isEmpty { metrics["heartRate"] = hr }

        // HRV
        if let hrv = v.hrv { metrics["hrv"] = ["average": Int(hrv)] }

        // Blood oxygen
        if let spo2 = v.bloodOxygen { metrics["bloodOxygen"] = ["average": Int(spo2)] }

        // Sleep
        var sleep: [String: Any] = [:]
        if let total = totalSleepMin { sleep["totalMinutes"] = total }
        if let deep = ts.deepSleepMinutes { sleep["deepMinutes"] = deep }
        if let rem = ts.remSleepMinutes { sleep["remMinutes"] = rem }
        if let light = lightMin { sleep["lightMinutes"] = light }
        if !sleep.isEmpty { metrics["sleep"] = sleep }

        // Activity
        var activity: [String: Any] = [:]
        if let steps = ts.totalSteps { activity["steps"] = steps }
        if let cal = ts.activeCalories { activity["activeCalories"] = Int(cal) }
        if !activity.isEmpty { metrics["activity"] = activity }

        // Recovery
        metrics["recoveryScore"] = status.recoveryScore

        // Week trend
        let wt = status.weekTrend
        var trend: [String: Any] = [
            "scoreTrend": wt.scoreTrend,
            "hrvTrend": wt.hrvTrend,
            "sleepTrend": wt.sleepTrend
        ]
        if let avg = wt.averageScore { trend["averageScore"] = avg }
        trend["dailyScores"] = wt.dailyScores.map { ["date": $0.date, "score": $0.score] }
        metrics["weekTrend"] = trend

        let payload: [String: Any] = [
            "type": "health_sync",
            "date": dateStr,
            "metrics": metrics,
            "workouts": workouts
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"type\":\"health_sync\",\"date\":\"\(dateStr)\",\"metrics\":{}}"
        }
        return json
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
            summary: content,
            pendingWorkouts: nil
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

    // MARK: - Watch 数据处理

    /// 处理从 Watch 通过 WCSession 接收到的训练完成数据。
    /// 将 Watch 端实时数据直接附加到下一次推送中，无需等待 HealthKit 同步。
    @MainActor
    func handleWatchWorkoutCompleted(_ data: [String: Any]) {
        guard isEnabled, config != nil else { return }

        // 缓存 Watch 端实时训练数据用于下次推送
        lastWatchWorkout = WatchWorkoutData(
            category: data["category"] as? String ?? "unknown",
            durationSeconds: data["durationSeconds"] as? Int ?? 0,
            activeCalories: data["activeCalories"] as? Double ?? 0,
            averageHeartRate: data["averageHeartRate"] as? Double ?? 0,
            maxHeartRate: data["maxHeartRate"] as? Double ?? 0,
            timestamp: Date()
        )

        logger.info("收到 Watch 训练数据: \(self.lastWatchWorkout?.category ?? "")")

        // 立即推送（无需等待 HealthKit 同步延迟）
        Task { @MainActor in
            await pushHealthStatus()
        }
    }

    /// 处理 Watch 推送的健康快照数据
    @MainActor
    func handleWatchHealthSnapshot(_ data: [String: Any]) {
        guard isEnabled, config != nil else { return }
        checkAndPushIfNeeded()
    }

    /// 缓存的 Watch 实时训练数据
    private var lastWatchWorkout: WatchWorkoutData?

    struct WatchWorkoutData {
        let category: String
        let durationSeconds: Int
        let activeCalories: Double
        let averageHeartRate: Double
        let maxHeartRate: Double
        let timestamp: Date
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

    // MARK: - Auto-Reconnect + Subnet Discovery

    /// Silently reconnect using saved credentials on launch / foreground.
    /// If the saved URL is unreachable, scans the local /24 subnet for the gateway.
    func attemptAutoReconnect() async {
        guard isEnabled else { return }
        guard let cfg = config else { return }

        // Already confirmed recently — skip
        if connectionStatus == .connected,
           let lastSync = lastSyncTime,
           Date().timeIntervalSince(lastSync) < 300 {
            return
        }

        logger.info("Auto-reconnect: verifying saved gateway \(cfg.gatewayURL)")

        // 1) Try the saved URL first
        let reachable = await verifyConnection(url: cfg.gatewayURL, token: cfg.token)
        if reachable {
            await MainActor.run { connectionStatus = .connected }
            logger.info("Auto-reconnect: saved gateway reachable")
            return
        }

        // 2) Saved URL failed — attempt subnet discovery
        logger.info("Auto-reconnect: saved URL unreachable, starting subnet scan")
        await MainActor.run { connectionStatus = .syncing }

        guard let savedURL = URL(string: cfg.gatewayURL),
              let port = savedURL.port.map({ UInt16($0) }) ?? Optional(SubnetScanner.defaultPort)
        else {
            await MainActor.run { connectionStatus = .error }
            return
        }

        guard let discoveredBase = await SubnetScanner.shared.findGateway(port: port) else {
            logger.warning("Auto-reconnect: subnet scan found nothing")
            await MainActor.run { connectionStatus = .error }
            return
        }

        // 3) Verify the discovered host with saved token
        let verified = await verifyConnection(url: discoveredBase, token: cfg.token)
        if verified {
            // Update saved URL to new IP
            let updated = PulseOpenClawConfig(
                gatewayURL: discoveredBase,
                token: cfg.token,
                agentID: cfg.agentID
            )
            updated.save()
            await MainActor.run {
                connectionStatus = .connected
                // Sync @AppStorage used by SettingsView
                UserDefaults.standard.set(discoveredBase, forKey: "pulse.openclaw.gatewayURL")
            }
            logger.info("Auto-reconnect: migrated gateway to \(discoveredBase)")
        } else {
            logger.warning("Auto-reconnect: discovered host rejected token")
            await MainActor.run { connectionStatus = .error }
        }
    }

    // MARK: - Background Sync (BGAppRefreshTask)

    #if os(iOS)
    static let bgTaskID = "com.abundra.pulse.health-sync"

    /// Register background sync task — call once at app launch
    func registerBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskID,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleBGSync(task: task)
        }
        scheduleBackgroundSync()
    }

    /// Schedule next background sync (30 min from now)
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background health sync scheduled")
        } catch {
            logger.error("Failed to schedule BG sync: \(error.localizedDescription)")
        }
    }

    private func handleBGSync(task: BGAppRefreshTask) {
        // Schedule next
        scheduleBackgroundSync()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            await pushHealthStatus()
            task.setTaskCompleted(success: true)
        }
    }
    #endif

    // MARK: - Pending Queue 主动拉取（通过 agent exec 工具）

    /// health sync prompt 已要求 agent 读取并返回 pendingWorkouts
    /// 此处仅作为备用：如果 agent 回复里没有，由 agent 在下次 sync 处理
    @MainActor
    private func fetchAndProcessPendingQueue(cfg: PulseOpenClawConfig) async {
        // Agent 已通过 exec 工具读取并在 JSON 回复里携带 pendingWorkouts
        // 此方法保留为 no-op，实际处理在 parseAgentResponse 后执行
        logger.debug("fetchAndProcessPendingQueue: 由 agent 在回复中处理 pendingWorkouts")
    }

    // MARK: - Pending Workouts 处理

    /// 将 OpenClaw 下发的 pendingWorkouts 写入 SwiftData，已存在则跳过
    @MainActor
    private func processPendingWorkouts(_ pending: [PendingWorkoutEntry]) async {
        guard let container = modelContainer else {
            logger.warning("processPendingWorkouts: modelContainer 未注入，跳过")
            return
        }

        let context = ModelContext(container)
        var written = 0

        for entry in pending {
            let uuid = "openclaw-\(entry.id)"

            // 去重：检查是否已存在
            let descriptor = FetchDescriptor<WorkoutHistoryEntry>(
                predicate: #Predicate { $0.hkWorkoutUUID == uuid }
            )
            if let existing = try? context.fetch(descriptor), !existing.isEmpty {
                logger.debug("processPendingWorkouts: 已存在 \(uuid)，跳过")
                continue
            }

            // 解析时间
            let startDate: Date
            if let ts = entry.timestamp {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                startDate = iso.date(from: ts) ?? Date()
            } else {
                startDate = Date()
            }

            let durationSec = Double((entry.durationMinutes ?? 10) * 60)
            let endDate = startDate.addingTimeInterval(durationSec)

            // 类型映射
            let activityType: Int
            switch entry.type.lowercased() {
            case "strength":   activityType = 58
            case "running":    activityType = 37
            case "cycling":    activityType = 13
            case "swimming":   activityType = 46
            case "yoga":       activityType = 50
            case "basketball": activityType = 4
            case "soccer":     activityType = 43
            default:           activityType = 3  // HKWorkoutActivityTypeFunctionalStrengthTraining fallback
            }

            let record = WorkoutHistoryEntry(
                hkWorkoutUUID: uuid,
                activityType: activityType,
                startDate: startDate,
                endDate: endDate,
                durationSeconds: durationSec,
                sourceName: "OpenClaw",
                isManual: true,
                notes: entry.notes
            )

            // 设置肌群标签
            if let groups = entry.muscleGroups, !groups.isEmpty {
                let mapped = groups.compactMap { MuscleGroup(rawValue: $0) }
                if !mapped.isEmpty {
                    record.muscleGroupTags = mapped
                }
            }

            context.insert(record)
            written += 1
        }

        if written > 0 {
            do {
                try context.save()
                logger.info("processPendingWorkouts: 成功写入 \(written) 条训练记录")
            } catch {
                logger.error("processPendingWorkouts: 写入失败 — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 格式化

    var lastSyncDisplay: String {
        guard let time = lastSyncTime else { return String(localized: "Never synced") }

        let interval = Date().timeIntervalSince(time)
        if interval < 60 {
            return String(localized: "Just now")
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d HH:mm"
            return fmt.string(from: time)
        }
    }
}
