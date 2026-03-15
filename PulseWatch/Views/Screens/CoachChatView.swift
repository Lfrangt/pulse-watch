import SwiftUI
import SwiftData

// MARK: - 聊天消息模型

/// 单条聊天消息
private struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date

    enum Role {
        case user   // 用户
        case coach  // AI 教练
    }

    init(role: Role, text: String, timestamp: Date = .now) {
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - 教练大脑 — 基于健康数据生成回复

/// 纯本地 AI 教练逻辑，不调用任何外部 API
private struct CoachBrain {

    /// 根据用户提问生成教练回复
    static func respond(
        to question: String,
        insight: HealthInsight?,
        brief: ScoreEngine.DailyBrief?,
        healthManager: HealthKitManager
    ) -> String {

        // 快捷问题匹配
        if question.contains("今天练什么") || question.contains("训练计划") {
            return trainingResponse(insight: insight, brief: brief)
        }

        if question.contains("身体状态") || question.contains("状态怎么样") || question.contains("今天状态") {
            return statusResponse(insight: insight, brief: brief, healthManager: healthManager)
        }

        if question.contains("需要休息") || question.contains("要不要休息") || question.contains("该休息") {
            return restResponse(insight: insight, brief: brief)
        }

        // 自由文本关键词匹配
        if question.contains("训练") || question.contains("练") || question.contains("workout") || question.contains("运动") {
            return trainingResponse(insight: insight, brief: brief)
        }

        if question.contains("睡眠") || question.contains("sleep") || question.contains("睡觉") || question.contains("失眠") {
            return sleepResponse(insight: insight, brief: brief)
        }

        if question.contains("心率") || question.contains("HRV") || question.contains("hrv") || question.contains("心跳") {
            return vitalsResponse(healthManager: healthManager, insight: insight)
        }

        if question.contains("恢复") || question.contains("recovery") {
            return recoveryResponse(insight: insight, brief: brief)
        }

        if question.contains("步数") || question.contains("走路") || question.contains("步行") {
            return stepsResponse(healthManager: healthManager)
        }

        if question.contains("血氧") || question.contains("氧") {
            return bloodOxygenResponse(healthManager: healthManager)
        }

        // 兜底通用回复
        return fallbackResponse(insight: insight, brief: brief)
    }

    // MARK: - 训练建议回复

    private static func trainingResponse(
        insight: HealthInsight?,
        brief: ScoreEngine.DailyBrief?
    ) -> String {
        var lines: [String] = []

        if let advice = insight?.trainingAdvice {
            lines.append("根据你当前的身体数据，今天建议：\(advice.label)")

            switch advice {
            case .intense:
                lines.append("身体恢复得很好，可以挑战高强度训练。")
            case .moderate:
                lines.append("状态不错，适合中等强度的训练。")
            case .light:
                lines.append("身体还在恢复中，建议做些轻松的活动，比如瑜伽或散步。")
            case .rest:
                lines.append("身体信号显示需要休息，今天就好好恢复吧。")
            }
        }

        if let plan = brief?.trainingPlan, plan.targetMuscleGroup != "rest" {
            let groupName = localizedMuscleGroup(plan.targetMuscleGroup)
            lines.append("推荐练\(groupName)，上次练这个部位已经过了 \(plan.daysSinceLastTrained) 天。")

            if !plan.suggestedExercises.isEmpty {
                let exerciseNames = plan.suggestedExercises.prefix(3).map(\.name).joined(separator: "、")
                lines.append("参考动作：\(exerciseNames)")
            }

            lines.append("建议强度：\(plan.intensity.rawValue)")
        }

        if lines.isEmpty {
            lines.append("目前数据还不够充分，建议先做一次轻度训练，让我更好地了解你的身体状况。")
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: - 身体状态回复

    private static func statusResponse(
        insight: HealthInsight?,
        brief: ScoreEngine.DailyBrief?,
        healthManager: HealthKitManager
    ) -> String {
        var lines: [String] = []

        if let brief {
            lines.append("今日状态评分：\(brief.score) 分 — \(brief.headline)")
        }

        if let insight {
            lines.append("恢复评分：\(insight.recoveryScore)")
            lines.append("睡眠评分：\(insight.sleepScore)")
        }

        // 生命体征
        var vitals: [String] = []
        if let hr = healthManager.latestHeartRate {
            vitals.append("心率 \(Int(hr)) bpm")
        }
        if let hrv = healthManager.latestHRV {
            vitals.append("HRV \(Int(hrv)) ms")
        }
        if let rhr = healthManager.latestRestingHR {
            vitals.append("静息心率 \(Int(rhr)) bpm")
        }
        if let spo2 = healthManager.latestBloodOxygen {
            vitals.append("血氧 \(Int(spo2))%")
        }

        if !vitals.isEmpty {
            lines.append("关键指标：\(vitals.joined(separator: " / "))")
        }

        // 异常提醒
        if let anomalies = insight?.anomalies, !anomalies.isEmpty {
            for anomaly in anomalies.prefix(2) {
                lines.append("注意：\(anomaly.message) — \(anomaly.detail)")
            }
        }

        if lines.isEmpty {
            lines.append("暂时还没有足够的数据来评估你的状态，戴上手表一段时间后我会给你详细分析。")
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: - 休息建议回复

    private static func restResponse(
        insight: HealthInsight?,
        brief: ScoreEngine.DailyBrief?
    ) -> String {
        guard let insight else {
            return "数据不足，无法准确判断。如果感觉身体疲惫，听从身体的声音，适当休息总是好的。"
        }

        let recovery = insight.recoveryScore

        switch recovery {
        case 0..<40:
            return "建议今天休息。你的恢复评分只有 \(recovery) 分，身体明确需要恢复。好好睡一觉，明天会更好。"
        case 40..<60:
            return "可以做些轻松的活动，比如散步或拉伸，但不建议高强度训练。恢复评分 \(recovery) 分，身体还在恢复中。"
        case 60..<80:
            return "不需要完全休息，恢复评分 \(recovery) 分，状态还不错。可以正常训练，但注意控制强度。"
        default:
            return "完全不需要休息！恢复评分 \(recovery) 分，身体状态很好。今天是挑战自我的好时机，去练吧！"
        }
    }

    // MARK: - 睡眠回复

    private static func sleepResponse(
        insight: HealthInsight?,
        brief: ScoreEngine.DailyBrief?
    ) -> String {
        var lines: [String] = []

        if let sleepSummary = brief?.sleepSummary {
            lines.append("昨晚睡眠时长：\(sleepSummary)")
        }

        if let sleepScore = insight?.sleepScore {
            let evaluation: String
            switch sleepScore {
            case 80...: evaluation = "非常好"
            case 60..<80: evaluation = "还不错"
            case 40..<60: evaluation = "一般"
            default: evaluation = "较差"
            }
            lines.append("睡眠质量评分：\(sleepScore) 分（\(evaluation)）")
        }

        if let trends = insight?.trends {
            lines.append("睡眠趋势：\(trends.sleepTrend.label)")
        }

        if lines.isEmpty {
            lines.append("暂时没有获取到睡眠数据。确保佩戴手表入睡，我会为你分析睡眠质量。")
        } else {
            if (insight?.sleepScore ?? 100) < 60 {
                lines.append("建议今晚早点休息，保持规律的作息时间会帮助提高睡眠质量。")
            }
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: - 生命体征回复

    private static func vitalsResponse(
        healthManager: HealthKitManager,
        insight: HealthInsight?
    ) -> String {
        var lines: [String] = []

        if let hr = healthManager.latestHeartRate {
            lines.append("当前心率：\(Int(hr)) bpm")
        }

        if let hrv = healthManager.latestHRV {
            lines.append("HRV（心率变异性）：\(Int(hrv)) ms")
            if hrv > 60 {
                lines.append("HRV 水平不错，说明自主神经系统恢复良好。")
            } else if hrv < 30 {
                lines.append("HRV 偏低，可能是疲劳或压力较大的信号，注意休息。")
            }
        }

        if let rhr = healthManager.latestRestingHR {
            lines.append("静息心率：\(Int(rhr)) bpm")
        }

        if let trends = insight?.trends {
            if trends.hrvTrend != .insufficient {
                lines.append("HRV 趋势：\(trends.hrvTrend.label)")
            }
            if trends.rhrTrend != .insufficient {
                lines.append("静息心率趋势：\(trends.rhrTrend.label)")
            }
        }

        if lines.isEmpty {
            lines.append("暂时没有心率相关数据，确保手表佩戴正确后稍等片刻。")
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: - 恢复状态回复

    private static func recoveryResponse(
        insight: HealthInsight?,
        brief: ScoreEngine.DailyBrief?
    ) -> String {
        guard let insight else {
            return "暂时没有足够的数据来评估恢复状态。戴上手表，让我持续追踪你的身体指标。"
        }

        var lines: [String] = []
        lines.append("恢复评分：\(insight.recoveryScore) 分")

        if let note = brief?.recoveryNote {
            lines.append(note)
        }

        // 趋势信息
        let scoreTrend = insight.trends.scoreTrend
        if scoreTrend != .insufficient {
            lines.append("整体状态趋势：\(scoreTrend.label)")
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: - 步数回复

    private static func stepsResponse(healthManager: HealthKitManager) -> String {
        let steps = healthManager.todaySteps
        let calories = healthManager.todayActiveCalories

        if steps == 0 && calories == 0 {
            return "今天还没有记录到步数。起来走走吧，日常活动也是恢复的重要部分。"
        }

        var lines: [String] = []
        lines.append("今日步数：\(formatNumber(steps)) 步")

        if calories > 0 {
            lines.append("活动消耗：\(Int(calories)) 千卡")
        }

        if steps >= 10000 {
            lines.append("太棒了，已经达到一万步目标！")
        } else if steps >= 6000 {
            lines.append("活动量不错，继续保持。")
        } else {
            lines.append("可以再多走走，适量活动有助于恢复。")
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: - 血氧回复

    private static func bloodOxygenResponse(healthManager: HealthKitManager) -> String {
        guard let spo2 = healthManager.latestBloodOxygen else {
            return "暂时没有血氧数据。Apple Watch 会在后台自动测量，稍后再来查看。"
        }

        var lines: [String] = []
        lines.append("血氧饱和度：\(Int(spo2))%")

        if spo2 >= 96 {
            lines.append("血氧水平正常，身体供氧良好。")
        } else if spo2 >= 92 {
            lines.append("血氧略低于正常范围，注意观察。如果持续偏低建议咨询医生。")
        } else {
            lines.append("血氧偏低，请注意。如果感觉呼吸不适，建议及时就医。")
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: - 兜底回复

    private static func fallbackResponse(
        insight: HealthInsight?,
        brief: ScoreEngine.DailyBrief?
    ) -> String {
        if let brief {
            return "你的今日状态评分是 \(brief.score) 分（\(brief.headline)）。\(brief.insight)\n\n你可以问我具体的问题，比如「今天练什么」「身体状态」「需要休息吗」，我会根据你的健康数据给出建议。"
        }
        return "你好！我是你的 AI 健身教练。你可以问我「今天练什么」「身体状态怎么样」「需要休息吗」，我会根据你的实时健康数据给出个性化建议。"
    }

    // MARK: - 工具方法

    /// 肌群名称本地化
    private static func localizedMuscleGroup(_ group: String) -> String {
        switch group {
        case "chest": return "胸"
        case "back": return "背"
        case "legs": return "腿"
        case "shoulders": return "肩"
        case "arms": return "手臂"
        case "cardio": return "有氧"
        default: return group
        }
    }

    /// 数字格式化（千位逗号）
    private static func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - AI 教练聊天界面

/// Tab: AI 教练 — 基于健康数据的智能对话
struct CoachChatView: View {

    @State private var healthManager = HealthKitManager.shared
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var insight: HealthInsight?
    @State private var brief: ScoreEngine.DailyBrief?

    /// 打字机效果：当前正在显示的文字
    @State private var typingText: String = ""
    /// 打字机效果：完整回复文字
    @State private var fullReplyText: String = ""
    /// 打字机效果：当前字符索引
    @State private var typingIndex: Int = 0
    /// 是否正在打字（防止重复发送）
    @State private var isTyping: Bool = false
    /// 打字机计时器
    @State private var typingTimer: Timer?

    @Query(sort: \WorkoutRecord.date, order: .reverse) private var recentWorkouts: [WorkoutRecord]

    /// 快捷问题列表
    private let quickQuestions = ["今天练什么？", "身体状态", "需要休息吗？"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 聊天内容区域
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: PulseTheme.spacingM) {
                            // 快捷问题按钮
                            quickQuestionBar
                                .padding(.top, PulseTheme.spacingS)

                            // 消息气泡列表
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                messageBubble(message)
                                    .id(message.id)
                                    .staggered(index: index)
                            }

                            // 打字机效果气泡（正在生成回复时显示）
                            if isTyping {
                                typingBubble
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, PulseTheme.spacingM)
                        .padding(.bottom, PulseTheme.spacingM)
                    }
                    .onChange(of: messages.count) {
                        // 新消息时滚动到底部
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if let lastId = messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: typingText) {
                        // 打字中持续滚动
                        if isTyping {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }

                // 底部输入区域
                inputBar
            }
            .background(PulseTheme.background)
            .navigationTitle("AI 教练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: PulseTheme.spacingS) {
                        // 教练头像（小号）
                        coachAvatar(size: 28)

                        Text("AI 教练")
                            .font(PulseTheme.headlineFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
                }
            }
            .task {
                await loadHealthData()
                // 首次进入显示欢迎消息
                if messages.isEmpty {
                    sendWelcomeMessage()
                }
            }
        }
    }

    // MARK: - 教练头像

    /// 暖色调圆形教练头像
    private func coachAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PulseTheme.accent, PulseTheme.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Image(systemName: "figure.mind.and.body")
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(PulseTheme.background)
        }
    }

    // MARK: - 快捷问题栏

    private var quickQuestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PulseTheme.spacingS) {
                ForEach(quickQuestions, id: \.self) { question in
                    Button {
                        sendMessage(question)
                    } label: {
                        Text(question)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(PulseTheme.accent)
                            .padding(.horizontal, PulseTheme.spacingM)
                            .padding(.vertical, PulseTheme.spacingS)
                            .background(
                                Capsule()
                                    .fill(PulseTheme.accent.opacity(0.12))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(PulseTheme.accent.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isTyping)
                    .opacity(isTyping ? 0.5 : 1.0)
                }
            }
            .padding(.horizontal, PulseTheme.spacingXS)
        }
    }

    // MARK: - 消息气泡

    /// 根据角色渲染不同样式的消息气泡
    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            userBubble(message.text)
        case .coach:
            coachBubble(message.text)
        }
    }

    /// 用户消息：右对齐，金色气泡
    private func userBubble(_ text: String) -> some View {
        HStack(alignment: .bottom, spacing: PulseTheme.spacingS) {
            Spacer(minLength: 60)

            Text(text)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.background)
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.vertical, PulseTheme.spacingS + 2)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .fill(PulseTheme.accent)
                )
        }
    }

    /// 教练消息：左对齐，暗色卡片气泡 + 头像
    private func coachBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: PulseTheme.spacingS) {
            coachAvatar(size: 32)

            Text(text)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.vertical, PulseTheme.spacingS + 2)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .fill(PulseTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
                        )
                )

            Spacer(minLength: 40)
        }
    }

    /// 打字机效果气泡 — 正在逐字显示回复
    private var typingBubble: some View {
        HStack(alignment: .top, spacing: PulseTheme.spacingS) {
            coachAvatar(size: 32)

            HStack(spacing: 0) {
                Text(typingText)
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                // 闪烁光标
                Text("|")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.accent)
                    .opacity(typingText.isEmpty ? 0 : 1)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: typingText.count
                    )
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.vertical, PulseTheme.spacingS + 2)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                            .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
                    )
            )

            Spacer(minLength: 40)
        }
    }

    // MARK: - 底部输入栏

    private var inputBar: some View {
        HStack(spacing: PulseTheme.spacingS) {
            TextField("问教练点什么...", text: $inputText)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.vertical, PulseTheme.spacingS + 2)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                        .fill(PulseTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                                .stroke(PulseTheme.border, lineWidth: 0.5)
                        )
                )
                .submitLabel(.send)
                .onSubmit {
                    sendCurrentInput()
                }

            // 发送按钮
            Button {
                sendCurrentInput()
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? PulseTheme.accent : PulseTheme.border)
                        .frame(width: 36, height: 36)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(canSend ? PulseTheme.background : PulseTheme.textTertiary)
                }
            }
            .disabled(!canSend)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSend)
        }
        .padding(.horizontal, PulseTheme.spacingM)
        .padding(.vertical, PulseTheme.spacingS)
        .background(
            PulseTheme.surface
                .shadow(color: .black.opacity(0.3), radius: 10, y: -4)
        )
    }

    /// 是否可以发送消息
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    // MARK: - 发送逻辑

    /// 发送当前输入框的文字
    private func sendCurrentInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isTyping else { return }
        inputText = ""
        sendMessage(text)
    }

    /// 发送消息并生成 AI 回复
    private func sendMessage(_ text: String) {
        guard !isTyping else { return }

        // 添加用户消息
        let userMessage = ChatMessage(role: .user, text: text)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(userMessage)
        }

        // 生成 AI 回复（本地计算，无延迟）
        let reply = CoachBrain.respond(
            to: text,
            insight: insight,
            brief: brief,
            healthManager: healthManager
        )

        // 开始打字机效果
        startTypewriterEffect(reply)
    }

    /// 发送欢迎消息
    private func sendWelcomeMessage() {
        let greeting: String
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  greeting = "早上好"
        case 12..<14: greeting = "中午好"
        case 14..<18: greeting = "下午好"
        case 18..<22: greeting = "晚上好"
        default:      greeting = "夜深了"
        }

        var welcomeText = "\(greeting)！我是你的 AI 健身教练。"

        if let brief {
            welcomeText += "\n\n你今天的状态评分是 \(brief.score) 分（\(brief.headline)）。"

            if let advice = insight?.trainingAdvice {
                welcomeText += "建议今天\(advice.label)。"
            }
        } else {
            welcomeText += "\n\n我会根据你的实时健康数据，为你提供个性化的训练建议。"
        }

        welcomeText += "\n\n有什么想问我的吗？你也可以点击上面的快捷按钮。"

        startTypewriterEffect(welcomeText)
    }

    // MARK: - 打字机效果

    /// 开启打字机逐字显示效果
    private func startTypewriterEffect(_ text: String) {
        // 停止之前的计时器
        typingTimer?.invalidate()

        fullReplyText = text
        typingText = ""
        typingIndex = 0
        isTyping = true

        // 每 30ms 显示一个字符
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            guard typingIndex < fullReplyText.count else {
                // 打字完成
                timer.invalidate()
                finishTyping()
                return
            }

            let index = fullReplyText.index(fullReplyText.startIndex, offsetBy: typingIndex)
            typingText.append(fullReplyText[index])
            typingIndex += 1
        }
    }

    /// 打字机效果完成 — 将完整回复添加到消息列表
    private func finishTyping() {
        let coachMessage = ChatMessage(role: .coach, text: fullReplyText)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(coachMessage)
        }

        // 清理打字机状态
        typingText = ""
        fullReplyText = ""
        typingIndex = 0
        isTyping = false
        typingTimer = nil
    }

    // MARK: - 数据加载

    /// 加载健康数据（仅本地，不调用 API）
    private func loadHealthData() async {
        do {
            try await healthManager.requestAuthorization()
            await healthManager.refreshAll()

            let sleep = try await healthManager.fetchLastNightSleep()

            brief = ScoreEngine.generateBrief(
                hrv: healthManager.latestHRV,
                restingHR: healthManager.latestRestingHR,
                bloodOxygen: healthManager.latestBloodOxygen,
                sleepMinutes: sleep.total,
                deepSleepMinutes: sleep.deep,
                remSleepMinutes: sleep.rem,
                steps: healthManager.todaySteps,
                recentWorkouts: recentWorkouts
            )

            insight = await MainActor.run {
                HealthAnalyzer.shared.generateInsight()
            }
        } catch {
            print("CoachChat: 健康数据加载失败 \(error)")
        }
    }
}

// MARK: - 预览

#Preview {
    CoachChatView()
        .preferredColorScheme(.dark)
}
