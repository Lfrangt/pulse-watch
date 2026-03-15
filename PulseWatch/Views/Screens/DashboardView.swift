import SwiftUI
import SwiftData

/// Tab 1: 今日状态总览 — 评分大圆环 + 洞察卡片 + 指标网格 + 训练建议
struct DashboardView: View {

    @State private var healthManager = HealthKitManager.shared
    @State private var connectivityManager = WatchConnectivityManager.shared
    @State private var isLoading = true
    @State private var brief: ScoreEngine.DailyBrief?
    @State private var insight: HealthInsight?
    @State private var showLocationSetup = false
    @State private var showGymPrompt = false
    @State private var breathe = false

    // 圆环动画状态
    @State private var animatedScore: Int = 0
    @State private var ringProgress: CGFloat = 0
    @State private var ringAnimated = false

    @Query(sort: \WorkoutRecord.date, order: .reverse) private var recentWorkouts: [WorkoutRecord]
    @Query private var savedLocations: [SavedLocation]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseTheme.spacingM) {
                    // 问候语
                    greetingSection
                        .staggered(index: 0)

                    // 状态评分大圆环
                    if let brief {
                        scoreGaugeCard(score: brief.score, headline: brief.headline)
                            .staggered(index: 1)
                    } else if isLoading {
                        loadingCard
                    } else {
                        // 空数据状态 — 温暖邀请
                        emptyStateCard
                            .staggered(index: 1)
                    }

                    // 今日洞察卡片
                    if let insight, !insight.insights.isEmpty {
                        insightCards(insight.insights)
                            .staggered(index: 2)
                    }

                    // 关键指标网格（全部为空时隐藏）
                    if hasAnyMetric {
                        metricsGrid
                            .staggered(index: 3)
                    }

                    // 身体时间线（有数据时显示）
                    recoveryTimelineSection
                        .staggered(index: 4)

                    // 训练建议卡片
                    if let advice = insight?.trainingAdvice {
                        trainingAdviceCard(advice: advice)
                            .staggered(index: 4)
                    } else if let plan = brief?.trainingPlan, plan.targetMuscleGroup != "rest" {
                        TrainingCard(plan: plan)
                            .staggered(index: 4)
                    }

                    // 恢复提醒
                    if let note = brief?.recoveryNote {
                        RecoveryCard(note: note)
                            .staggered(index: 5)
                    }

                    // 最近训练
                    if !recentWorkouts.isEmpty {
                        recentWorkoutsSection
                            .staggered(index: 6)
                    }

                    // 健身房设置提示
                    if !hasGymLocation {
                        gymSetupPrompt
                            .staggered(index: 7)
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.spacingM)
            }
            .background(
                ZStack {
                    PulseTheme.background
                    if let brief {
                        PulseTheme.ambientGradient(for: brief.score)
                            .scaleEffect(breathe ? 1.05 : 1.0)
                            .ignoresSafeArea()
                    }
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLocationSetup = true
                    } label: {
                        Image(systemName: "location.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
            }
            .sheet(isPresented: $showLocationSetup) {
                LocationSetupView()
            }
            .alert("到达健身房", isPresented: $showGymPrompt) {
                Button("好的") {}
            } message: {
                if let plan = brief?.trainingPlan {
                    Text("建议今天练\(localizedGroup(plan.targetMuscleGroup))，已通知手表")
                } else {
                    Text("已通知手表")
                }
            }
            .task {
                await loadData()
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
            .refreshable {
                await loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didEnterSavedRegion)) { notification in
                handleGeofenceEntry(notification)
            }
        }
    }

    // MARK: - 问候语（仅时段问候，不显示日期）

    private var greetingSection: some View {
        HStack {
            Text(greeting)
                .font(PulseTheme.titleFont)
                .foregroundStyle(PulseTheme.textPrimary)
            Spacer()
        }
        .padding(.top, PulseTheme.spacingM)
    }

    // MARK: - 状态评分大圆环 (Gauge)

    private func scoreGaugeCard(score: Int, headline: String) -> some View {
        let statusColor = PulseTheme.statusColor(for: score)

        return VStack(spacing: PulseTheme.spacingM) {
            // 大圆环
            ZStack {
                // 底部光晕
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 260, height: 260)
                    .blur(radius: 40)

                // 背景轨道
                Circle()
                    .stroke(PulseTheme.border, lineWidth: 12)
                    .frame(width: 220, height: 220)

                // 进度弧（弹簧动画）
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [statusColor.opacity(0.6), statusColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))

                // 分数 + 标签
                VStack(spacing: 2) {
                    Text("\(animatedScore)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                        .contentTransition(.numericText())

                    Text(headline)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(statusColor)
                }
            }
            .onAppear {
                guard !ringAnimated else { return }
                ringAnimated = true
                // 弹簧动画：圆环从0展开到实际值
                withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3)) {
                    ringProgress = CGFloat(score) / 100.0
                }
                // 数字计数动画
                animateScoreCounter(to: score)
            }

            // 一行洞察副标题
            if let brief {
                Text(brief.insight)
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, PulseTheme.spacingM)
            }
        }
        .padding(.vertical, PulseTheme.spacingXL)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                        .fill(PulseTheme.statusGradient(for: score))
                )
                .shadow(color: PulseTheme.cardShadow, radius: 20, y: 8)
                .shadow(color: statusColor.opacity(0.08), radius: 30, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .stroke(statusColor.opacity(0.1), lineWidth: 0.5)
        )
    }

    /// 数字从0递增到目标值的计数动画
    private func animateScoreCounter(to target: Int) {
        animatedScore = 0
        let steps = target
        guard steps > 0 else { return }
        let totalDuration: Double = 0.8
        let interval = totalDuration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + interval * Double(i)) {
                withAnimation(.easeOut(duration: 0.05)) {
                    animatedScore = i
                }
            }
        }
    }

    // MARK: - 空数据状态

    @State private var emptyPulse = false

    private var emptyStateCard: some View {
        VStack(spacing: PulseTheme.spacingM) {
            ZStack {
                // 脉冲圆环占位符
                Circle()
                    .stroke(PulseTheme.border, lineWidth: 12)
                    .frame(width: 220, height: 220)
                    .scaleEffect(emptyPulse ? 1.04 : 1.0)
                    .opacity(emptyPulse ? 0.5 : 0.8)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: emptyPulse
                    )

                Circle()
                    .fill(PulseTheme.border.opacity(0.05))
                    .frame(width: 260, height: 260)
                    .blur(radius: 30)
            }
            .onAppear {
                emptyPulse = true
            }

            Text("\u{2600}\u{FE0F} 戴上手表，开始记录你的一天")
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, PulseTheme.spacingXL)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow, radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - 今日洞察卡片（简化标题）

    private func insightCards(_ insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("今日洞察")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            ForEach(Array(insights.prefix(3).enumerated()), id: \.offset) { _, text in
                HStack(alignment: .top, spacing: PulseTheme.spacingS) {
                    Circle()
                        .fill(PulseTheme.accent.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(text)
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 关键指标网格（隐藏空值瓷砖）

    /// 是否有任何有效指标数据
    private var hasAnyMetric: Bool {
        healthManager.latestHeartRate != nil ||
        healthManager.latestHRV != nil ||
        brief?.sleepSummary != nil ||
        healthManager.todaySteps > 0 ||
        healthManager.todayActiveCalories > 0 ||
        healthManager.latestBloodOxygen != nil
    }

    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: PulseTheme.spacingS),
            GridItem(.flexible(), spacing: PulseTheme.spacingS),
        ]

        return LazyVGrid(columns: columns, spacing: PulseTheme.spacingS) {
            // 心率：仅在有数据时显示
            if let hr = healthManager.latestHeartRate {
                metricTile(
                    icon: "heart.fill",
                    label: "心率",
                    value: "\(Int(hr))",
                    unit: "bpm",
                    color: PulseTheme.statusPoor
                )
            }

            // HRV：仅在有数据时显示
            if let hrv = healthManager.latestHRV {
                metricTile(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: "\(Int(hrv))",
                    unit: "ms",
                    color: PulseTheme.accent
                )
            }

            // 睡眠：仅在有数据时显示
            if let sleep = brief?.sleepSummary {
                metricTile(
                    icon: "moon.fill",
                    label: "睡眠",
                    value: sleep,
                    unit: "",
                    color: Color(hex: "8B7EC8")
                )
            }

            // 步数：仅在大于0时显示
            if healthManager.todaySteps > 0 {
                metricTile(
                    icon: "figure.walk",
                    label: "步数",
                    value: formatSteps(healthManager.todaySteps),
                    unit: "",
                    color: PulseTheme.statusGood
                )
            }

            // 卡路里：仅在大于0时显示
            if healthManager.todayActiveCalories > 0 {
                metricTile(
                    icon: "flame.fill",
                    label: "卡路里",
                    value: "\(Int(healthManager.todayActiveCalories))",
                    unit: "kcal",
                    color: PulseTheme.statusModerate
                )
            }

            // 血氧：仅在有数据时显示
            if let spo2 = healthManager.latestBloodOxygen {
                metricTile(
                    icon: "lungs.fill",
                    label: "血氧",
                    value: "\(Int(spo2))%",
                    unit: "",
                    color: PulseTheme.statusGood
                )
            }
        }
    }

    private func metricTile(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack(spacing: PulseTheme.spacingS) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 28, height: 28)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color)
                }

                Text(label)
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(PulseTheme.metricLabelFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow.opacity(0.3), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - 训练建议卡片

    private func trainingAdviceCard(advice: TrainingAdvice) -> some View {
        let adviceColor: Color = {
            switch advice {
            case .intense:  return PulseTheme.statusPoor
            case .moderate: return PulseTheme.statusModerate
            case .light:    return PulseTheme.statusGood
            case .rest:     return PulseTheme.textTertiary
            }
        }()

        return HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(adviceColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: advice.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(adviceColor)
            }

            VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                Text("训练建议")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)

                Text(advice.label)
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
            }

            Spacer()

            // 强度指示器
            HStack(spacing: 3) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < adviceLevel(advice) ? adviceColor : PulseTheme.border)
                        .frame(width: 6, height: CGFloat(12 + i * 4))
                }
            }
        }
        .pulseCard()
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: PulseTheme.radiusL,
                bottomLeadingRadius: PulseTheme.radiusL
            )
            .fill(adviceColor.opacity(0.3))
            .frame(width: 3)
        }
    }

    private func adviceLevel(_ advice: TrainingAdvice) -> Int {
        switch advice {
        case .rest: return 0
        case .light: return 1
        case .moderate: return 2
        case .intense: return 4
        }
    }

    // MARK: - 最近训练

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("最近训练")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .padding(.leading, PulseTheme.spacingXS)

            ForEach(Array(recentWorkouts.prefix(3)), id: \.id) { workout in
                workoutRow(workout)
            }
        }
    }

    private func workoutRow(_ workout: WorkoutRecord) -> some View {
        HStack(spacing: PulseTheme.spacingM) {
            // 分类图标
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: workoutCategoryIcon(workout.category))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
            }

            // 名称 + 日期
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutCategoryName(workout.category))
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(relativeDate(workout.date))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()

            // 时长
            Text("\(workout.durationMinutes)分钟")
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow.opacity(0.2), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
        )
    }

    /// 训练分类 -> SF Symbol 图标
    private func workoutCategoryIcon(_ category: String) -> String {
        switch category {
        case "chest": return "figure.strengthtraining.traditional"
        case "back": return "figure.rowing"
        case "legs": return "figure.step.training"
        case "shoulders": return "figure.arms.open"
        case "arms": return "dumbbell.fill"
        case "cardio": return "figure.run"
        default: return "figure.mixed.cardio"
        }
    }

    /// 训练分类 -> 中文名称
    private func workoutCategoryName(_ category: String) -> String {
        switch category {
        case "chest": return "胸部"
        case "back": return "背部"
        case "legs": return "腿部"
        case "shoulders": return "肩部"
        case "arms": return "手臂"
        case "cardio": return "有氧"
        default: return category
        }
    }

    /// 相对日期：今天、昨天、N天前
    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        switch days {
        case 0: return "今天"
        case 1: return "昨天"
        default: return "\(days)天前"
        }
    }

    // MARK: - 健身房设置

    private var gymSetupPrompt: some View {
        Button {
            showLocationSetup = true
        } label: {
            HStack(spacing: PulseTheme.spacingM) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PulseTheme.accent.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: "mappin.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PulseTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("设置健身房位置")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)

                    Text("到达时自动提醒训练")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .padding(PulseTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.cardBackground)
                    .shadow(color: PulseTheme.cardShadow.opacity(0.3), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .stroke(PulseTheme.accent.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 身体时间线

    @ViewBuilder
    private var recoveryTimelineSection: some View {
        let timeline = RecoveryTimelineView()
        // 仅在有事件时显示
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("身体时间线")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            timeline
        }
    }

    // MARK: - 辅助

    private var loadingCard: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
            .fill(PulseTheme.cardBackground)
            .frame(height: 200)
            .shadow(color: PulseTheme.cardShadow, radius: 16, y: 6)
            .overlay(
                ProgressView()
                    .tint(PulseTheme.accent)
            )
    }

    private var hasGymLocation: Bool {
        savedLocations.contains { $0.locationType == "gym" && $0.isActive }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "早上好"
        case 12..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<22: return "晚上好"
        default: return "夜深了"
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }

    // MARK: - 数据加载

    private func loadData() async {
        isLoading = true

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

            // 生成 AI 洞察
            insight = await MainActor.run {
                HealthAnalyzer.shared.generateInsight()
            }

            // 同步到手表
            if let brief {
                connectivityManager.sendHealthSummary(
                    score: brief.score,
                    headline: brief.headline,
                    insight: brief.insight,
                    heartRate: Int(healthManager.latestHeartRate ?? 0),
                    steps: healthManager.todaySteps
                )

                // 重新触发圆环动画（刷新后）
                ringAnimated = false
            }
        } catch {
            print("Dashboard load error: \(error)")
        }

        isLoading = false
    }

    // MARK: - 地理围栏

    private func handleGeofenceEntry(_ notification: Notification) {
        guard let regionId = notification.userInfo?["regionId"] as? String else { return }

        guard let location = savedLocations.first(where: {
            $0.id.uuidString == regionId && $0.locationType == "gym"
        }) else { return }

        let group = brief?.trainingPlan?.targetMuscleGroup ?? "chest"
        let reason = brief?.trainingPlan?.reason ?? "到达\(location.name)"

        connectivityManager.sendGymArrival(muscleGroup: group, reason: reason)
        showGymPrompt = true
    }

    private func localizedGroup(_ group: String) -> String {
        switch group {
        case "chest": return "胸"
        case "back": return "背"
        case "legs": return "腿"
        case "shoulders": return "肩"
        default: return group
        }
    }
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}
