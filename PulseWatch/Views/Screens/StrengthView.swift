import SwiftUI
import SwiftData
import Charts

/// 力量三大项记录 + 实力评估页面
struct StrengthView: View {

    @Query(sort: \StrengthRecord.date, order: .reverse) private var allRecords: [StrengthRecord]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("pulse.user.weightKg") private var bodyweight: Double = 0

    @State private var showAddSheet = false
    @State private var selectedLift: StrengthService.LiftType = .squat
    @State private var showAchievements = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var celebrationAchievement: AchievementService.Achievement?
    @State private var showCelebration = false
    @State private var pbTimelineRange: PBRange = .all

    enum PBRange: String, CaseIterable { case week = "7D", month = "30D", quarter = "90D", all = "All" }

    private var assessment: StrengthService.StrengthAssessment? {
        StrengthService.shared.assess(records: allRecords, bodyweightKg: bodyweight)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {
                // 综合力量评分
                if let a = assessment {
                    overallScoreCard(a)
                } else if bodyweight <= 0 {
                    needProfileCard
                }

                // 三项评估
                if let a = assessment {
                    ForEach(a.lifts, id: \.liftType) { lift in
                        liftCard(lift)
                    }
                }

                // PB 成长时间线（合并三线）
                if allRecords.count >= 2 {
                    pbTimelineCard
                }

                // 趋势图（单项）
                ForEach(StrengthService.LiftType.allCases) { type in
                    let records = allRecords.filter { $0.liftType == type.rawValue }
                    if records.count >= 2 {
                        trendChart(type: type, records: records)
                    }
                }

                // 成就系统
                achievementsCard

                // 历史记录
                if !allRecords.isEmpty {
                    historySection
                }

                // 分享按钮
                if !allRecords.isEmpty {
                    shareProgressButton
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingS)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "Strength"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(PulseTheme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddStrengthRecordView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareSheet(items: [img])
            }
        }
        .overlay {
            if showCelebration, let ach = celebrationAchievement {
                celebrationOverlay(ach)
            }
        }
        .onAppear {
            let result = AchievementService.shared.checkAll(records: allRecords, bodyweightKg: bodyweight)
            if let first = result.newlyUnlocked.first {
                celebrationAchievement = first
                withAnimation { showCelebration = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showCelebration = false }
                }
            }
        }
    }

    // MARK: - 综合评分

    private func overallScoreCard(_ a: StrengthService.StrengthAssessment) -> some View {
        VStack(spacing: PulseTheme.spacingM) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Strength Score")
                        .font(PulseTheme.headlineFont)
                        .foregroundStyle(PulseTheme.textPrimary)
                    Text(a.totalLevel.label)
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(Color(hex: a.totalLevel.color))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(PulseTheme.border, lineWidth: 6)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(a.totalScore) / 100)
                        .stroke(Color(hex: a.totalLevel.color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    Text("\(a.totalScore)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                }
            }

            // Total 1RM
            if a.total1RM > 0 {
                HStack {
                    Text("Total")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                    Spacer()
                    Text(String(format: "%.0f kg", a.total1RM))
                        .font(PulseTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(PulseTheme.textPrimary)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 单项评估卡片

    private func liftCard(_ lift: StrengthService.LiftAssessment) -> some View {
        let color = Color(hex: lift.liftType.color)

        return HStack(spacing: PulseTheme.spacingM) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: lift.liftType.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(lift.liftType.label)
                    .font(PulseTheme.bodyFont.weight(.medium))
                    .foregroundStyle(PulseTheme.textPrimary)

                HStack(spacing: 8) {
                    Text(String(format: String(localized: "Best: %.0f kg"), lift.best1RM))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                    Text(String(format: "%.1fx BW", lift.bodyweightRatio))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PulseTheme.textTertiary)
                }

                if let next = lift.nextLevelKg, next > 0 {
                    Text(String(format: String(localized: "+%.0f kg to %@"), next, nextLevel(lift.level).label))
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            Spacer()

            // Level badge
            Text(lift.level.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: lift.level.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: lift.level.color).opacity(0.15)))
        }
        .pulseCard()
    }

    private func nextLevel(_ current: StrengthService.StrengthLevel) -> StrengthService.StrengthLevel {
        switch current {
        case .beginner: return .intermediate
        case .intermediate: return .advanced
        case .advanced: return .elite
        case .elite: return .elite
        }
    }

    // MARK: - 趋势图

    private func trendChart(type: StrengthService.LiftType, records: [StrengthRecord]) -> some View {
        let sorted = records.sorted { $0.date < $1.date }
        let color = Color(hex: type.color)

        return VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack {
                Image(systemName: type.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                Text(type.label)
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
                if let best = sorted.max(by: { $0.estimated1RM < $1.estimated1RM }) {
                    Text(String(format: "PR: %.0f kg", best.estimated1RM))
                        .font(PulseTheme.captionFont.weight(.semibold))
                        .foregroundStyle(color)
                }
            }

            Chart(sorted, id: \.id) { record in
                LineMark(
                    x: .value("Date", record.date),
                    y: .value("Weight", record.estimated1RM)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("Date", record.date),
                    y: .value("Weight", record.estimated1RM)
                )
                .foregroundStyle(
                    LinearGradient(colors: [color.opacity(0.15), color.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", record.date),
                    y: .value("Weight", record.estimated1RM)
                )
                .foregroundStyle(color)
                .symbolSize(24)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(PulseTheme.border)
                    AxisValueLabel()
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            .frame(height: 160)
        }
        .pulseCard()
    }

    // MARK: - 填写 Profile 提示

    private var needProfileCard: some View {
        HStack(spacing: PulseTheme.spacingM) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 20))
                .foregroundStyle(PulseTheme.textTertiary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Set your body weight in Settings → Profile")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                Text("Needed for strength level assessment")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .pulseCard()
    }

    // MARK: - 历史记录

    private var historySection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            Text("Recent Records")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            ForEach(allRecords.prefix(15)) { record in
                let type = StrengthService.LiftType(rawValue: record.liftType) ?? .squat
                HStack(spacing: PulseTheme.spacingS) {
                    Circle()
                        .fill(Color(hex: type.color))
                        .frame(width: 8, height: 8)
                    Text(type.label)
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .frame(width: 90, alignment: .leading)
                    Text(String(format: "%.0f kg × %d × %d", record.weightKg, record.sets, record.reps))
                        .font(PulseTheme.captionFont.weight(.medium))
                        .foregroundStyle(PulseTheme.textSecondary)
                    Spacer()
                    Text(record.date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.textTertiary)
                    if record.isPersonalRecord {
                        Text("PR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PulseTheme.statusModerate)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(PulseTheme.statusModerate.opacity(0.15)))
                    }
                }
            }
        }
        .pulseCard()
    }

    // MARK: - PB 成长时间线（三线合一）

    private var pbTimelineCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13))
                    .foregroundStyle(PulseTheme.accent)
                Text("PB Timeline")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
                Picker("", selection: $pbTimelineRange) {
                    ForEach(PBRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            let filteredRecords = filterByRange(allRecords)

            Chart {
                ForEach(StrengthService.LiftType.allCases) { type in
                    let recs = filteredRecords.filter { $0.liftType == type.rawValue }
                        .sorted { $0.date < $1.date }
                    let color = Color(hex: type.color)

                    ForEach(recs, id: \.id) { r in
                        LineMark(
                            x: .value("Date", r.date),
                            y: .value("1RM", r.estimated1RM),
                            series: .value("Lift", type.label)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        if r.isPersonalRecord {
                            PointMark(x: .value("Date", r.date), y: .value("1RM", r.estimated1RM))
                                .foregroundStyle(PulseTheme.statusModerate)
                                .symbolSize(40)
                                .annotation(position: .top, spacing: 4) {
                                    Text("⭐")
                                        .font(.system(size: 10))
                                }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                        .foregroundStyle(PulseTheme.border.opacity(0.4))
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 9))
                        .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
                }
            }
            .chartForegroundStyleScale([
                StrengthService.LiftType.squat.label: PulseTheme.statusGood,
                StrengthService.LiftType.bench.label: PulseTheme.activityAccent,
                StrengthService.LiftType.deadlift.label: Color(hex: "5C7BC7"),
            ])
            .chartLegend(.visible)
            .frame(height: 200)
        }
        .pulseCard()
    }

    private func filterByRange(_ records: [StrengthRecord]) -> [StrengthRecord] {
        let days: Int? = {
            switch pbTimelineRange {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .all: return nil
            }
        }()
        guard let days else { return records }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        return records.filter { $0.date >= cutoff }
    }

    // MARK: - 成就系统

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(PulseTheme.statusModerate)
                Text("Achievements")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
                let unlocked = AchievementService.shared.allAchievements().filter { $0.1 }.count
                Text("\(unlocked)/\(AchievementService.Achievement.allCases.count)")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                ForEach(AchievementService.shared.allAchievements(), id: \.0) { ach, unlocked, date in
                    VStack(spacing: 6) {
                        Text(ach.medal)
                            .font(.system(size: 28))
                            .opacity(unlocked ? 1 : 0.3)
                            .grayscale(unlocked ? 0 : 1)
                        Text(ach.title)
                            .font(.system(size: 10, weight: unlocked ? .semibold : .regular))
                            .foregroundStyle(unlocked ? PulseTheme.textPrimary : PulseTheme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let date {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.system(size: 8))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(unlocked ? PulseTheme.statusModerate.opacity(0.08) : PulseTheme.surface)
                    )
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 庆祝动画

    private func celebrationOverlay(_ achievement: AchievementService.Achievement) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: PulseTheme.spacingL) {
                Text(achievement.medal)
                    .font(.system(size: 80))
                    .scaleEffect(showCelebration ? 1 : 0.3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCelebration)

                Text("Achievement Unlocked!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PulseTheme.statusModerate)

                Text(achievement.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(achievement.description)
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
            }
        }
        .onTapGesture {
            withAnimation { showCelebration = false }
        }
        .transition(.opacity)
    }

    // MARK: - 分享进步

    private var shareProgressButton: some View {
        Button {
            generateShareImage()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                Text("Share Progress")
                    .font(PulseTheme.bodyFont.weight(.medium))
            }
            .foregroundStyle(PulseTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func generateShareImage() {
        let a = assessment
        let card = ShareStrengthCard(
            squat: a?.lifts.first(where: { $0.liftType == .squat })?.best1RM ?? 0,
            bench: a?.lifts.first(where: { $0.liftType == .bench })?.best1RM ?? 0,
            deadlift: a?.lifts.first(where: { $0.liftType == .deadlift })?.best1RM ?? 0,
            total: a?.total1RM ?? 0,
            level: a?.totalLevel.label ?? ""
        )
        let renderer = ImageRenderer(content: card.frame(width: 390, height: 520))
        renderer.scale = 3
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

// MARK: - 分享卡片

private struct ShareStrengthCard: View {
    let squat: Double
    let bench: Double
    let deadlift: Double
    let total: Double
    let level: String

    var body: some View {
        VStack(spacing: 24) {
            Text("My Strength Progress")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 20) {
                liftStat("SQ", squat, PulseTheme.statusGood)
                liftStat("BP", bench, PulseTheme.activityAccent)
                liftStat("DL", deadlift, Color(hex: "5C7BC7"))
            }

            VStack(spacing: 4) {
                Text("Total")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                Text(String(format: "%.0f kg", total))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if !level.isEmpty {
                    Text(level)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PulseTheme.statusModerate)
                }
            }

            Text("Tracked with Pulse Watch")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: "1A1715"), Color(hex: "0D0C0B")],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func liftStat(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
            Text(String(format: "%.0f", value))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("kg")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - 添加记录 Sheet

struct AddStrengthRecordView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var liftType: StrengthService.LiftType = .squat
    @State private var weight: String = ""
    @State private var sets: Int = 3
    @State private var reps: Int = 8
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PulseTheme.spacingL) {
                    // Lift type
                    VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                        Text("Lift")
                            .font(PulseTheme.headlineFont)
                            .foregroundStyle(PulseTheme.textPrimary)

                        HStack(spacing: 8) {
                            ForEach(StrengthService.LiftType.allCases) { type in
                                let selected = liftType == type
                                Button { liftType = type } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(selected ? Color(hex: type.color) : PulseTheme.textTertiary)
                                        Text(type.label)
                                            .font(.system(size: 10, weight: selected ? .semibold : .regular))
                                            .foregroundStyle(selected ? PulseTheme.textPrimary : PulseTheme.textTertiary)
                                            .lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color(hex: type.color).opacity(0.12) : PulseTheme.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color(hex: type.color).opacity(0.5) : .clear, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .pulseCard()

                    // Weight
                    VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                        Text("Weight (kg)")
                            .font(PulseTheme.headlineFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        TextField("e.g. 100", text: $weight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                            .padding(PulseTheme.spacingM)
                            .background(RoundedRectangle(cornerRadius: PulseTheme.radiusS).fill(PulseTheme.surface))
                    }
                    .pulseCard()

                    // Sets × Reps
                    HStack(spacing: PulseTheme.spacingM) {
                        VStack {
                            Text("Sets").font(PulseTheme.captionFont).foregroundStyle(PulseTheme.textTertiary)
                            Stepper("\(sets)", value: $sets, in: 1...20)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(PulseTheme.textPrimary)
                        }
                        VStack {
                            Text("Reps").font(PulseTheme.captionFont).foregroundStyle(PulseTheme.textTertiary)
                            Stepper("\(reps)", value: $reps, in: 1...30)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(PulseTheme.textPrimary)
                        }
                    }
                    .pulseCard()

                    // Date
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .tint(PulseTheme.accent).colorScheme(.dark)
                        .pulseCard()

                    // Save
                    Button { save() } label: {
                        Text("Save Record")
                            .font(PulseTheme.bodyFont.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: PulseTheme.radiusM).fill(PulseTheme.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(weight.isEmpty)
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingM)
            }
            .background(PulseTheme.background)
            .navigationTitle(String(localized: "Add Lift"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }

    private func save() {
        guard let w = Double(weight), w > 0 else { return }

        // Check if PR
        let typeRaw = liftType.rawValue
        let existing = (try? modelContext.fetch(FetchDescriptor<StrengthRecord>(
            predicate: #Predicate<StrengthRecord> { $0.liftType == typeRaw }
        ))) ?? []
        let currentBest = existing.max(by: { $0.estimated1RM < $1.estimated1RM })?.estimated1RM ?? 0

        let record = StrengthRecord(liftType: liftType.rawValue, weightKg: w, sets: sets, reps: reps, date: date)
        if record.estimated1RM > currentBest {
            record.isPersonalRecord = true
        }

        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}
