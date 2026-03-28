import SwiftUI

// MARK: - 身体恢复时间线组件
// 展示过去 24 小时的身体变化事件，垂直时间线设计

// MARK: - 时间线事件数据模型

struct TimelineEvent: Identifiable {
    let id = UUID()
    let time: Date
    let icon: String          // SF Symbol 名称
    let title: String         // 事件标题
    let detail: String        // 事件详情
    let impact: String        // 影响描述（显示为标签）
    let impactPositive: Bool  // 影响是正面还是负面
    let color: Color          // 节点颜色
    let isCurrent: Bool       // 是否为String(localized: "Current")节点（底部脉冲动画）

    init(
        time: Date,
        icon: String,
        title: String,
        detail: String,
        impact: String,
        impactPositive: Bool,
        color: Color,
        isCurrent: Bool = false
    ) {
        self.time = time
        self.icon = icon
        self.title = title
        self.detail = detail
        self.impact = impact
        self.impactPositive = impactPositive
        self.color = color
        self.isCurrent = isCurrent
    }
}

// MARK: - 时间线事件生成器

/// 从 HealthKit 真实数据构建时间线事件，数据不足时用占位结构
enum TimelineEventBuilder {

    /// 睡眠事件专用颜色 — 柔和紫
    static let sleepColor = PulseTheme.sleepAccent

    /// 从 HealthKitManager 和 HealthAnalyzer 数据构建事件列表
    @MainActor
    static func buildEvents() -> [TimelineEvent] {
        let hk = HealthKitManager.shared
        let insight = HealthAnalyzer.shared.generateInsight()
        let calendar = Calendar.current
        let now = Date()

        var events: [TimelineEvent] = []

        // ── 1. 睡眠事件 ──
        let sleepMinutes = hk.lastNightSleepMinutes
        if sleepMinutes > 0, let sleepStart = hk.lastNightSleepStart, let sleepEnd = hk.lastNightSleepEnd {
            let sleepHours = sleepMinutes / 60
            let sleepMins = sleepMinutes % 60
            // 使用 HealthKit 真实深睡数据，有数据才显示
            let deepMinutes = hk.lastNightDeepSleepMinutes
            let deepDetail: String
            if deepMinutes > 0 {
                deepDetail = " · \(String(localized: "Deep")) \(String(format: "%.1f", Double(deepMinutes) / 60.0))h"
            } else {
                deepDetail = ""
            }

            events.append(TimelineEvent(
                time: sleepStart,
                icon: "moon.fill",
                title: String(localized: "Asleep"),
                detail: "\(sleepHours)h\(sleepMins)m\(deepDetail)",
                impact: insight.sleepScore >= 70 ? String(localized: "Recovery +\(min(20, insight.sleepScore / 5))") : String(localized: "Fair recovery"),
                impactPositive: insight.sleepScore >= 50,
                color: sleepColor
            ))

            // 醒来时间 — 使用 HealthKit 真实数据
            let rhrText: String
            let rhrGood: Bool
            if let rhr = hk.latestRestingHR {
                rhrText = String(localized: "Resting HR \(Int(rhr))bpm")
                rhrGood = rhr < 70
            } else {
                rhrText = String(localized: "Resting HR --")
                rhrGood = true
            }

            events.append(TimelineEvent(
                time: sleepEnd,
                icon: "sunrise.fill",
                title: String(localized: "Awake"),
                detail: rhrText,
                impact: rhrGood ? String(localized: "Good recovery") : String(localized: "Weak recovery"),
                impactPositive: rhrGood,
                color: rhrGood ? PulseTheme.statusGood : PulseTheme.statusModerate
            ))
        } else {
            // 无睡眠数据 — 只显示一个占位，不显示假的醒来时间
            events.append(TimelineEvent(
                time: calendar.date(byAdding: .hour, value: -8, to: now) ?? now,
                icon: "moon.fill",
                title: String(localized: "Sleep"),
                detail: String(localized: "No sleep data"),
                impact: String(localized: "Awaiting sync"),
                impactPositive: true,
                color: sleepColor
            ))
        }

        // ── 2. 日间活动事件 ──
        let steps = hk.todaySteps
        let calories = hk.todayActiveCalories

        if steps > 0 || calories > 0 {
            // 优先使用今日最近一次 workout 的真实开始时间，没有则不显示精确时间（用 now）
            let activityTime = hk.todayLastWorkoutStart ?? now

            let stepsText: String
            if steps >= 10000 {
                stepsText = String(format: String(localized: "%.1fk steps"), Double(steps) / 1000)
            } else if steps >= 1000 {
                stepsText = String(format: String(localized: "%.1fk steps"), Double(steps) / 1000)
            } else {
                stepsText = "\(steps) steps"
            }

            let activeCal = String(localized: "Active cal")
            events.append(TimelineEvent(
                time: activityTime,
                icon: "figure.walk",
                title: String(localized: "Daily Activity"),
                detail: "\(stepsText) · \(activeCal) +\(Int(calories))kcal",
                impact: steps >= 8000 ? String(localized: "Keep it up") : String(localized: "Keep moving"),
                impactPositive: steps >= 5000,
                color: PulseTheme.accent
            ))
        }

        // ── 3. 当前状态事件（始终显示，底部脉冲） ──
        let hrvText: String
        let currentGood: Bool
        if let hrv = hk.latestHRV {
            let arrow = insight.recoveryScore >= 60 ? "↑" : "↓"
            hrvText = "HRV \(Int(hrv))ms \(arrow)"
            currentGood = insight.recoveryScore >= 60
        } else {
            hrvText = "HRV --"
            currentGood = true
        }

        let adviceText = insight.trainingAdvice.label

        events.append(TimelineEvent(
            time: now,
            icon: "heart.text.clipboard",
            title: String(localized: "Current Status"),
            detail: "\(hrvText) · \(adviceText)",
            impact: currentGood ? String(localized: "Ready to train") : String(localized: "Rest recommended"),
            impactPositive: currentGood,
            color: PulseTheme.accent,
            isCurrent: true
        ))

        // 按时间排序
        return events.sorted { $0.time < $1.time }
    }
}

// MARK: - 时间线主视图

struct RecoveryTimelineView: View {
    /// 时间线事件列表
    let events: [TimelineEvent]

    /// 外部传入或自动构建
    init(events: [TimelineEvent]? = nil) {
        self.events = events ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // ── 标题区 ──
            sectionHeader

            // ── 时间线内容 ──
            if events.isEmpty {
                emptyState
            } else {
                timelineContent
            }
        }
        .pulseCard()
    }

    // MARK: - 标题

    private var sectionHeader: some View {
        HStack(spacing: PulseTheme.spacingS) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
            }

            Text("Body Timeline")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // 时间范围标签
            Text("Past 24h")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(PulseTheme.textTertiary)
                    .accessibilityHidden(true)

                Text("No timeline data yet")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .padding(.vertical, PulseTheme.spacingXL)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 时间线主体

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                TimelineNodeView(
                    event: event,
                    isFirst: index == 0,
                    isLast: index == events.count - 1
                )
                .staggered(index: index + 1) // +1 因为标题占了 index 0
            }
        }
    }
}

// MARK: - 单个时间线节点

struct TimelineNodeView: View {
    let event: TimelineEvent
    let isFirst: Bool
    let isLast: Bool

    /// "当前"节点的脉冲动画状态
    @State private var isPulsing = false

    /// 节点圆的大小
    private let nodeSize: CGFloat = 11
    /// 时间线宽度
    private let lineWidth: CGFloat = 2
    /// 节点区域总宽度（左侧留给线 + 圆 + 间距）
    private let leadingWidth: CGFloat = 40

    var body: some View {
        HStack(alignment: .top, spacing: PulseTheme.spacingM) {
            // ── 左侧：垂直线 + 节点圆 ──
            timelineTrack
                .frame(width: leadingWidth)

            // ── 右侧：事件内容 ──
            eventContent
        }
        .padding(.vertical, PulseTheme.spacingXS)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(formattedTime), \(event.title)")
        .accessibilityValue("\(event.detail). \(event.impact)")
        .onAppear {
            // 当前节点启动脉冲动画
            if event.isCurrent {
                withAnimation(
                    .easeInOut(duration: 1.6)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
        }
    }

    // MARK: - 左侧轨道（垂直线 + 圆点）

    private var timelineTrack: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2

            ZStack(alignment: .top) {
                // 垂直连接线 — 上半段（非第一个节点时显示）
                if !isFirst {
                    Rectangle()
                        .fill(PulseTheme.border)
                        .frame(width: lineWidth)
                        .frame(height: geo.size.height / 2)
                        .position(x: centerX, y: geo.size.height / 4)
                }

                // 垂直连接线 — 下半段（非最后一个节点时显示）
                if !isLast {
                    Rectangle()
                        .fill(PulseTheme.border)
                        .frame(width: lineWidth)
                        .frame(height: geo.size.height / 2)
                        .position(x: centerX, y: geo.size.height * 3 / 4)
                }

                // 节点圆
                ZStack {
                    // 脉冲光晕 — 仅"当前"节点
                    if event.isCurrent {
                        Circle()
                            .fill(event.color.opacity(0.25))
                            .frame(width: nodeSize + 12, height: nodeSize + 12)
                            .scaleEffect(isPulsing ? 1.6 : 1.0)
                            .opacity(isPulsing ? 0.0 : 0.5)

                        Circle()
                            .fill(event.color.opacity(0.15))
                            .frame(width: nodeSize + 6, height: nodeSize + 6)
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                            .opacity(isPulsing ? 0.2 : 0.4)
                    }

                    // 主圆点
                    Circle()
                        .fill(event.color)
                        .frame(width: nodeSize, height: nodeSize)

                    // 内部高光 — 增加质感
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.3), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: nodeSize / 2
                            )
                        )
                        .frame(width: nodeSize, height: nodeSize)
                }
                .position(x: centerX, y: geo.size.height / 2)
            }
        }
        .frame(minHeight: 60)
    }

    // MARK: - 右侧事件内容

    private var eventContent: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
            // 时间标签
            Text(formattedTime)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)

            // 事件标题 + 图标
            HStack(spacing: PulseTheme.spacingXS + 2) {
                Image(systemName: event.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(event.color)

                Text(event.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
            }

            // 详情描述
            Text(event.detail)
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // 影响标签（彩色胶囊）
            impactCapsule
        }
        .padding(.vertical, PulseTheme.spacingXS)
    }

    // MARK: - 影响胶囊标签

    private var impactCapsule: some View {
        let capsuleColor = event.impactPositive ? PulseTheme.statusGood : PulseTheme.statusModerate

        return Text(event.impact)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(capsuleColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(capsuleColor.opacity(0.12))
            )
    }

    // MARK: - 时间格式化

    private var formattedTime: String {
        if event.isCurrent {
            return String(localized: "Current")
        }

        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: event.time)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let timeStr = String(format: "%02d:%02d", hour, minute)

        // 判断是否是昨天
        if !calendar.isDate(event.time, inSameDayAs: now) {
            return "\(String(localized: "Last night")) \(timeStr)"
        }

        // 根据时段添加前缀
        switch hour {
        case 0..<6:
            return "\(timeStr)"
        case 6..<9:
            return "\(timeStr)"
        case 9..<12:
            return "\(timeStr)"
        case 12..<14:
            return "\(timeStr)"
        case 14..<18:
            return "\(timeStr)"
        case 18..<21:
            return "\(timeStr)"
        default:
            return "\(timeStr)"
        }
    }
}

// MARK: - 便捷初始化（自动从 HealthKit 构建）

struct RecoveryTimelineSection: View {
    @State private var events: [TimelineEvent] = []

    var body: some View {
        RecoveryTimelineView(events: events)
            .task {
                await buildTimeline()
            }
    }

    @MainActor
    private func buildTimeline() async {
        events = TimelineEventBuilder.buildEvents()
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        VStack(spacing: PulseTheme.spacingM) {
            // 使用模拟数据预览
            RecoveryTimelineView(events: previewEvents)
        }
        .padding()
    }
    .background(PulseTheme.background)
    .preferredColorScheme(.dark)
}

/// 预览用模拟事件
private var previewEvents: [TimelineEvent] {
    let calendar = Calendar.current
    let now = Date()

    let bedtime = calendar.date(bySettingHour: 23, minute: 30, second: 0, of:
        calendar.date(byAdding: .day, value: -1, to: now)!
    )!

    let wakeTime = calendar.date(bySettingHour: 7, minute: 5, second: 0, of: now)!
    let activityTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now)!

    return [
        TimelineEvent(
            time: bedtime,
            icon: "moon.fill",
            title: String(localized: "Asleep"),
            detail: String(localized: "Total 7h35m · Deep ~2.1h"),
            impact: String(localized: "Recovery +15"),
            impactPositive: true,
            color: PulseTheme.sleepAccent
        ),
        TimelineEvent(
            time: wakeTime,
            icon: "sunrise.fill",
            title: String(localized: "Awake"),
            detail: String(localized: "Resting HR 62bpm"),
            impact: String(localized: "Good recovery"),
            impactPositive: true,
            color: PulseTheme.statusGood
        ),
        TimelineEvent(
            time: activityTime,
            icon: "figure.walk",
            title: String(localized: "Daily Activity"),
            detail: String(localized: "3.0k steps · Active calories +120kcal"),
            impact: String(localized: "Keep it up"),
            impactPositive: true,
            color: PulseTheme.accent
        ),
        TimelineEvent(
            time: now,
            icon: "heart.text.clipboard",
            title: String(localized: "Current Status"),
            detail: String(localized: "HRV 48ms ↑ · Moderate"),
            impact: String(localized: "Ready to train"),
            impactPositive: true,
            color: PulseTheme.accent,
            isCurrent: true
        ),
    ]
}
