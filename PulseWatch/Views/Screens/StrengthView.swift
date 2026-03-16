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

                // 趋势图
                ForEach(StrengthService.LiftType.allCases) { type in
                    let records = allRecords.filter { $0.liftType == type.rawValue }
                    if records.count >= 2 {
                        trendChart(type: type, records: records)
                    }
                }

                // 历史记录
                if !allRecords.isEmpty {
                    historySection
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingS)
        }
        .background(PulseTheme.background)
        .navigationTitle("Strength")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(PulseTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddStrengthRecordView()
                .preferredColorScheme(.dark)
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
                            .foregroundStyle(Color(hex: "D4A056"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color(hex: "D4A056").opacity(0.15)))
                    }
                }
            }
        }
        .pulseCard()
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
            .navigationTitle("Add Lift")
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
