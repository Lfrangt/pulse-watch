import SwiftUI
import SwiftData
import Charts

/// 力量三大项记录 + 实力评估页面
struct StrengthView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var selectedLiftDate: Date?
    @State private var selectedPBDate: Date?

    enum PBRange: String, CaseIterable { case week = "7D", month = "30D", quarter = "90D", all = "All" }

    private var assessment: StrengthService.StrengthAssessment? {
        StrengthService.shared.assess(records: allRecords, bodyweightKg: bodyweight)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.m) {
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
            .padding(.horizontal, DS.Spacing.m)
            .padding(.top, DS.Spacing.s)
        }
        .background(DS.Color.bg)
        .navigationTitle(String(localized: "Strength"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(DS.Typography.bodyL)
                            .foregroundStyle(DS.Color.accent)
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
        VStack(spacing: DS.Spacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Strength Score")
                        .font(PulseTheme.headlineFont)
                        .foregroundStyle(DS.Color.ink)
                    Text(a.totalLevel.label)
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(a.totalLevel.pulseColor)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(DS.Color.line, lineWidth: 6)
                        .frame(width: DS.Spacing.xl * 2, height: DS.Spacing.xl * 2)
                    Circle()
                        .trim(from: 0, to: CGFloat(a.totalScore) / 100)
                        .stroke(a.totalLevel.pulseColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: DS.Spacing.xl * 2, height: DS.Spacing.xl * 2)
                        .rotationEffect(.degrees(-90))
                    Text("\(a.totalScore)")
                        .font(DS.Typography.bodyL.weight(.bold))
                        .foregroundStyle(DS.Color.ink)
                }
            }

            // Total 1RM
            if a.total1RM > 0 {
                HStack {
                    Text("Total")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(DS.Color.inkDim)
                    Spacer()
                    Text(String(format: "%.0f kg", a.total1RM))
                        .font(PulseTheme.bodyFont.weight(.semibold))
                        .foregroundStyle(DS.Color.ink)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 单项评估卡片

    private func liftCard(_ lift: StrengthService.LiftAssessment) -> some View {
        let color = lift.liftType.pulseColor

        return HStack(spacing: DS.Spacing.m) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: DS.Spacing.xxl + DS.Spacing.xs, height: DS.Spacing.xxl + DS.Spacing.xs)
                Image(systemName: lift.liftType.icon)
                    .font(DS.Typography.bodyL)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(lift.liftType.label)
                    .font(PulseTheme.bodyFont.weight(.medium))
                    .foregroundStyle(DS.Color.ink)

                HStack(spacing: 8) {
                    Text(String(format: String(localized: "Best: %.0f kg"), lift.best1RM))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(DS.Color.inkMid)
                    Text(String(format: "%.1fx BW", lift.bodyweightRatio))
                        .font(DS.Typography.mono.weight(.medium))
                        .foregroundStyle(DS.Color.inkDim)
                }

                if let next = lift.nextLevelKg, next > 0 {
                    Text(String(format: String(localized: "+%.0f kg to %@"), next, nextLevel(lift.level).label))
                        .font(DS.Typography.mono)
                        .foregroundStyle(DS.Color.inkDim)
                }
            }

            Spacer()

            // Level badge
            Text(lift.level.label)
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(lift.level.pulseColor)
                .padding(.horizontal, DS.Spacing.s)
                .padding(.vertical, DS.Spacing.xs)
                .background(Capsule().fill(lift.level.pulseColor.opacity(0.15)))
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
        let color = type.pulseColor

        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                Image(systemName: type.icon)
                    .font(DS.Typography.caption)
                    .foregroundStyle(color)
                Text(type.label)
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)
                Spacer()
                if let best = sorted.max(by: { $0.estimated1RM < $1.estimated1RM }) {
                    Text(String(format: "PR: %.0f kg", best.estimated1RM))
                        .font(PulseTheme.captionFont.weight(.semibold))
                        .foregroundStyle(color)
                }
            }

            Chart {
                ForEach(sorted, id: \.id) { record in
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

                if let selected = selectedLiftDate {
                    RuleMark(x: .value("Selected", selected))
                        .foregroundStyle(DS.Color.inkMid)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(DS.Color.line)
                    AxisValueLabel()
                        .foregroundStyle(DS.Color.inkDim)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(DS.Color.inkDim)
                }
            }
            .frame(height: 160)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let origin = geo[proxy.plotFrame!].origin
                                    let x = drag.location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        // Snap to nearest data point
                                        let nearest = sorted.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        })
                                        let snapped = nearest?.date ?? date
                                        if snapped != selectedLiftDate {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                        selectedLiftDate = snapped
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        selectedLiftDate = nil
                                    }
                                }
                        )
                }
            }
            .overlay(alignment: .top) {
                if let selected = selectedLiftDate,
                   let record = sorted.min(by: {
                       abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected))
                   }) {
                    liftTooltip(weight: record.estimated1RM, date: record.date)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: selectedLiftDate)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - Chart Tooltips

    private func liftTooltip(weight: Double, date: Date) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f kg", weight))
                .font(DS.Typography.bodyS.weight(.semibold))
                .foregroundStyle(DS.Color.ink)
            Text(date.formatted(.dateTime.month(.abbreviated).day().locale(Locale.current)))
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkMid)
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    private func pbTooltip(date: Date, records: [StrengthRecord]) -> some View {
        // Find closest record per lift type within a 1-day window
        let threshold: TimeInterval = 86400
        let lines: [(String, Double, Color)] = StrengthService.LiftType.allCases.compactMap { type in
            let typeRecords = records.filter { $0.liftType == type.rawValue }
            guard let closest = typeRecords.min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }), abs(closest.date.timeIntervalSince(date)) < threshold else { return nil }
            return (type.label, closest.estimated1RM, type.pulseColor)
        }

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(lines, id: \.0) { label, value, color in
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: DS.Spacing.s - DS.Spacing.xs / 2, height: DS.Spacing.s - DS.Spacing.xs / 2)
                    Text("\(label): \(String(format: "%.0f", value)) kg")
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(DS.Color.ink)
                }
            }
            Text(date.formatted(.dateTime.month(.abbreviated).day().locale(Locale.current)))
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkMid)
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    // MARK: - 填写 Profile 提示

    private var needProfileCard: some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: "scalemass.fill")
                .font(DS.Typography.bodyL)
                .foregroundStyle(DS.Color.inkDim)
            VStack(alignment: .leading, spacing: 4) {
                Text("Set your body weight in Settings → Profile")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(DS.Color.inkMid)
                Text("Needed for strength level assessment")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkDim)
            }
        }
        .pulseCard()
    }

    // MARK: - 历史记录

    @State private var recordToDelete: StrengthRecord?
    @State private var showDeleteConfirmation = false

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Recent Records")
                .font(PulseTheme.headlineFont)
                .foregroundStyle(DS.Color.ink)

            ForEach(allRecords.prefix(15)) { record in
                let type = StrengthService.LiftType(rawValue: record.liftType) ?? .squat
                HStack(spacing: DS.Spacing.s) {
                    Circle()
                        .fill(type.pulseColor)
                        .frame(width: DS.Spacing.s, height: DS.Spacing.s)
                    Text(type.label)
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(DS.Color.ink)
                        .frame(width: 90, alignment: .leading)
                    Text(String(format: "%.0f kg × %d × %d", record.weightKg, record.sets, record.reps))
                        .font(PulseTheme.captionFont.weight(.medium))
                        .foregroundStyle(DS.Color.inkMid)
                    Spacer()
                    Text(record.date, format: .dateTime.month(.abbreviated).day())
                        .font(DS.Typography.mono)
                        .foregroundStyle(DS.Color.inkDim)
                    if record.isPersonalRecord {
                        Text("PR")
                            .font(DS.Typography.monoS.weight(.bold))
                            .foregroundStyle(DS.Color.warn)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.m)
                            .background(Capsule().fill(DS.Color.warn.opacity(0.15)))
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        recordToDelete = record
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .pulseCard()
        .confirmationDialog(
            "Delete this record?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let record = recordToDelete {
                    withAnimation {
                        modelContext.delete(record)
                    }
                }
                recordToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                recordToDelete = nil
            }
        }
    }

    // MARK: - PB 成长时间线（三线合一）

    private var pbTimelineCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(DS.Typography.bodyS)
                    .foregroundStyle(DS.Color.accent)
                Text("PB Timeline")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)
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
                    let color = type.pulseColor

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
                                .foregroundStyle(DS.Color.warn)
                                .symbolSize(40)
                                .annotation(position: .top, spacing: 4) {
                                    Text("⭐")
                                        .font(DS.Typography.mono)
                                }
                        }
                    }
                }

                if let selected = selectedPBDate {
                    RuleMark(x: .value("Selected", selected))
                        .foregroundStyle(DS.Color.inkMid)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4]))
                        .foregroundStyle(DS.Color.line.opacity(0.4))
                    AxisValueLabel()
                        .font(DS.Typography.mono)
                        .foregroundStyle(DS.Color.inkDim.opacity(0.7))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(DS.Typography.monoS)
                        .foregroundStyle(DS.Color.inkDim.opacity(0.7))
                }
            }
            .chartForegroundStyleScale([
                StrengthService.LiftType.squat.label: DS.Color.good,
                StrengthService.LiftType.bench.label: PulseTheme.activityAccent,
                StrengthService.LiftType.deadlift.label: PulseTheme.hrvBlue,
            ])
            .chartLegend(.visible)
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let origin = geo[proxy.plotFrame!].origin
                                    let x = drag.location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        // Snap to nearest data point across all series
                                        let nearest = filteredRecords.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        })
                                        let snapped = nearest?.date ?? date
                                        if snapped != selectedPBDate {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                        selectedPBDate = snapped
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        selectedPBDate = nil
                                    }
                                }
                        )
                }
            }
            .overlay(alignment: .top) {
                if let selected = selectedPBDate {
                    pbTooltip(date: selected, records: filteredRecords)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: selectedPBDate)
                }
            }
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
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(DS.Typography.bodyS)
                    .foregroundStyle(DS.Color.warn)
                Text("Achievements")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)
                Spacer()
                let unlocked = AchievementService.shared.allAchievements().filter { $0.1 }.count
                Text("\(unlocked)/\(AchievementService.Achievement.allCases.count)")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkDim)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                ForEach(AchievementService.shared.allAchievements(), id: \.0) { ach, unlocked, date in
                    VStack(spacing: 6) {
                        Text(ach.medal)
                            .font(DS.Typography.title1)
                            .opacity(unlocked ? 1 : 0.3)
                            .grayscale(unlocked ? 0 : 1)
                        Text(ach.title)
                            .font(DS.Typography.mono)
                            .foregroundStyle(unlocked ? DS.Color.ink : DS.Color.inkDim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let date {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(DS.Typography.monoS)
                                .foregroundStyle(DS.Color.inkDim)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(unlocked ? DS.Color.warn.opacity(0.08) : PulseTheme.surface)
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

            VStack(spacing: DS.Spacing.l) {
                Text(achievement.medal)
                    .font(DS.Typography.display2)
                    .scaleEffect(showCelebration ? 1 : 0.3)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: showCelebration)

                Text("Achievement Unlocked!")
                    .font(DS.Typography.title2.weight(.bold))
                    .foregroundStyle(DS.Color.warn)

                Text(achievement.title)
                    .font(DS.Typography.title1.weight(.bold))
                    .foregroundStyle(DS.Color.ink)

                Text(achievement.description)
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(DS.Color.inkMid)
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
                    .font(DS.Typography.bodyS)
                Text("Share Progress")
                    .font(PulseTheme.bodyFont.weight(.medium))
            }
            .foregroundStyle(DS.Color.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.card)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                    .fill(DS.Color.accent.opacity(0.1))
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
        let renderer = ImageRenderer(content: card.frame(width: DS.Spacing.xxl * 9 + DS.Spacing.l + DS.Spacing.m, height: DS.Spacing.xxl * 13))
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
                .font(DS.Typography.title2.weight(.bold))
                .foregroundStyle(DS.Color.ink)

            HStack(spacing: 20) {
                liftStat("SQ", squat, DS.Color.good)
                liftStat("BP", bench, PulseTheme.activityAccent)
                liftStat("DL", deadlift, PulseTheme.hrvBlue)
            }

            VStack(spacing: 4) {
                Text("Total")
                    .font(DS.Typography.bodyS)
                    .foregroundStyle(DS.Color.inkMid)
                Text(String(format: "%.0f kg", total))
                    .font(DS.Typography.title1)
                    .foregroundStyle(DS.Color.ink)
                if !level.isEmpty {
                    Text(level)
                        .font(DS.Typography.bodyS.weight(.medium))
                        .foregroundStyle(DS.Color.warn)
                }
            }

            Text("Tracked with Pulse Watch")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [PulseTheme.cardElevated, DS.Color.bg],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func liftStat(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(DS.Typography.bodyS.weight(.medium))
                .foregroundStyle(color)
            Text(String(format: "%.0f", value))
                .font(DS.Typography.title1.weight(.bold))
                .foregroundStyle(DS.Color.ink)
            Text("kg")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkDim)
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
                VStack(spacing: DS.Spacing.l) {
                    // Lift type
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Text("Lift")
                            .font(PulseTheme.headlineFont)
                            .foregroundStyle(DS.Color.ink)

                        HStack(spacing: 8) {
                            ForEach(StrengthService.LiftType.allCases) { type in
                                let selected = liftType == type
                                Button { liftType = type } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: type.icon)
                                            .font(DS.Typography.bodyL)
                                            .foregroundStyle(selected ? type.pulseColor : DS.Color.inkDim)
                                        Text(type.label)
                                            .font(DS.Typography.mono)
                                            .foregroundStyle(selected ? DS.Color.ink : DS.Color.inkDim)
                                            .lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.m)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(selected ? type.pulseColor.opacity(0.12) : PulseTheme.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? type.pulseColor.opacity(0.5) : .clear, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .pulseCard()

                    // Weight
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Text("Weight (kg)")
                            .font(PulseTheme.headlineFont)
                            .foregroundStyle(DS.Color.ink)
                        TextField("e.g. 100", text: $weight)
                            .keyboardType(.decimalPad)
                            .font(DS.Typography.title1.weight(.bold))
                            .foregroundStyle(DS.Color.ink)
                            .padding(DS.Spacing.m)
                            .background(RoundedRectangle(cornerRadius: DS.Radius.chip).fill(PulseTheme.surface))
                    }
                    .pulseCard()

                    // Sets × Reps
                    HStack(spacing: DS.Spacing.m) {
                        VStack {
                            Text("Sets").font(PulseTheme.captionFont).foregroundStyle(DS.Color.inkDim)
                            Stepper("\(sets)", value: $sets, in: 1...20)
                                .font(DS.Typography.bodyL.weight(.bold))
                                .foregroundStyle(DS.Color.ink)
                        }
                        VStack {
                            Text("Reps").font(PulseTheme.captionFont).foregroundStyle(DS.Color.inkDim)
                            Stepper("\(reps)", value: $reps, in: 1...30)
                                .font(DS.Typography.bodyL.weight(.bold))
                                .foregroundStyle(DS.Color.ink)
                        }
                    }
                    .pulseCard()

                    // Date
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .tint(DS.Color.accent).colorScheme(.dark)
                        .pulseCard()

                    // Save
                    Button { save() } label: {
                        Text("Save Record")
                            .font(PulseTheme.bodyFont.weight(.semibold))
                            .foregroundStyle(DS.Color.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.m)
                            .background(RoundedRectangle(cornerRadius: DS.Radius.inner).fill(DS.Color.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(weight.isEmpty)
                }
                .padding(.horizontal, DS.Spacing.m)
                .padding(.top, DS.Spacing.m)
            }
            .background(DS.Color.bg)
            .navigationTitle(String(localized: "Add Lift"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .foregroundStyle(DS.Color.inkMid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundStyle(DS.Color.accent)
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
