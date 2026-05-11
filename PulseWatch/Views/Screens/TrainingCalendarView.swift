import SwiftUI
import SwiftData

/// 智能训练日历 — 按月查看训练记录，直观展示肌群分布
struct TrainingCalendarView: View {

    // MARK: - 数据查询

    @Query(sort: \WorkoutRecord.date, order: .forward)
    private var allWorkouts: [WorkoutRecord]

    @Query(sort: \WorkoutHistoryEntry.startDate, order: .forward)
    private var allHKWorkouts: [WorkoutHistoryEntry]

    @Query(sort: \DailySummary.date, order: .forward)
    private var allSummaries: [DailySummary]

    // MARK: - 状态

    @State private var currentMonth: Date = .now
    @State private var selectedDate: Date?
    @State private var animateDetail = false

    // MARK: - 常量

    private let calendar = Calendar.current
    private let weekdayHeaders: [String] = {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        // Rotate from Sunday-first to Monday-first
        return Array(symbols[1...]) + [symbols[0]]
    }()

    // MARK: - 训练分类颜色

    /// 根据训练类别返回对应颜色
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "chest", "shoulders":
            return PulseTheme.trendBlue   // Push — 蓝色
        case "back":
            return DS.Color.good   // Pull — 绿色
        case "legs":
            return DS.Color.warn   // 腿 — 琥珀色
        case "arms":
            return DS.Color.warn   // 手臂 — 金色
        case "cardio":
            return PulseTheme.activityAccent   // 有氧 — 红色
        default:
            return DS.Color.inkDim
        }
    }

    /// 训练类别中文名
    private func categoryLabel(for category: String) -> String {
        switch category.lowercased() {
        case "chest":      return String(localized: "Chest")
        case "back":       return String(localized: "Back")
        case "legs":       return String(localized: "Legs")
        case "shoulders":  return String(localized: "Shoulders")
        case "arms":       return String(localized: "Arms")
        case "cardio":     return String(localized: "Cardio")
        default:           return category
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.Spacing.m) {
                    // 月份导航
                    monthNavigationBar
                        .staggered(index: 0)

                    // 日历网格
                    calendarGrid
                        .staggered(index: 1)

                    // 选中日期详情
                    if let selectedDate, hasAnyWorkout(selectedDate) {
                        selectedDayDetailCombined(date: selectedDate)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                            .staggered(index: 2)
                    }

                    if allWorkouts.isEmpty && allHKWorkouts.isEmpty {
                        EmptyStateView(
                            icon: "calendar",
                            title: String(localized: "No Training Events"),
                            message: String(localized: "Start a workout to see your training calendar.")
                        )
                        .staggered(index: 3)
                    } else {
                        // 月度统计
                        monthlyStatsCard
                            .staggered(index: 3)

                        // 分类图例
                        categoryLegend
                            .staggered(index: 4)
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, DS.Spacing.m)
                .padding(.top, DS.Spacing.s)
            }
            .background(DS.Color.bg)
            .navigationTitle(String(localized: "Training Calendar"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - 月份导航

    private var monthNavigationBar: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(DS.Color.accent)
                    .frame(width: DS.Spacing.xxl, height: DS.Spacing.xxl)
                    .background(DS.Color.accent.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            Text(monthYearString)
                .font(DS.Typography.bodyL.weight(.semibold))
                .foregroundStyle(DS.Color.ink)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(DS.Color.accent)
                    .frame(width: DS.Spacing.xxl, height: DS.Spacing.xxl)
                    .background(DS.Color.accent.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, DS.Spacing.s)
    }

    /// 当前月份的标题字符串，例如 "2026年3月"
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy MMM"
        return formatter.string(from: currentMonth)
    }

    // MARK: - 日历网格

    private var calendarGrid: some View {
        VStack(spacing: DS.Spacing.s) {
            // 星期头部
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(DS.Typography.bodyS.weight(.medium))
                        .foregroundStyle(DS.Color.inkDim)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, DS.Spacing.xs)

            // 日期网格
            let gridData = calendarGridData
            let rows = gridData.chunked(into: 7)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.id) { item in
                        dayCellView(item: item)
                            .frame(maxWidth: .infinity)
                    }
                    // 补齐最后一行不足7天的情况
                    if row.count < 7 {
                        ForEach(0..<(7 - row.count), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Color.bgElev)
                
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Color.line.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - 日期单元格

    @ViewBuilder
    private func dayCellView(item: CalendarDayItem) -> some View {
        if item.day == 0 {
            // 空白占位
            Color.clear
                .frame(minHeight: 48)
        } else {
            let dayDate = dateForDay(item.day)
            let workouts = workoutsForDate(dayDate)
            let hasWorkout = hasAnyWorkout(dayDate)
            let isSelected = selectedDate.map { calendar.isDate(dayDate, inSameDayAs: $0) } ?? false
            let isToday = calendar.isDateInToday(dayDate)
            let workoutColor = hasWorkout ? primaryCategoryColor(dayDate) : Color.clear

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if isSelected {
                        selectedDate = nil
                    } else {
                        selectedDate = dayDate
                    }
                }
            } label: {
                VStack(spacing: 3) {
                    ZStack {
                        // 背景色
                        if hasWorkout {
                            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                                .fill(workoutColor.opacity(0.2))
                        }

                        // 选中高亮
                        if isSelected {
                            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                                .stroke(DS.Color.accent, lineWidth: 1.5)
                        }

                        // 今天标记
                        if isToday && !isSelected {
                            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                                .stroke(DS.Color.inkDim.opacity(0.5), lineWidth: 1)
                        }

                        Text("\(item.day)")
                            .font(DS.Typography.bodyS)
                            .foregroundStyle(isSelected ? DS.Color.accent :
                                                isToday ? DS.Color.ink :
                                                hasWorkout ? DS.Color.ink :
                                                DS.Color.inkMid)
                    }
                    .frame(width: DS.Spacing.xl + DS.Spacing.xs / 2, height: DS.Spacing.xl + DS.Spacing.xs / 2)

                    // 训练指示点
                    Circle()
                        .fill(hasWorkout ? workoutColor : Color.clear)
                        .frame(width: DS.Stroke.chartHeavy * 4, height: DS.Stroke.chartHeavy * 4)
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 48)
        }
    }

    // MARK: - 选中日期详情（合并手动 + HK）

    @ViewBuilder
    private func selectedDayDetailCombined(date: Date) -> some View {
        let manualWorkouts = workoutsForDate(date) ?? []
        let hkWorkouts = hkWorkoutsForDate(date)

        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                Text(dayDetailTitle(date))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)
                Spacer()
                if let summary = summaryForDate(date), let score = summary.dailyScore {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill").font(DS.Typography.caption).foregroundStyle(PulseTheme.statusColor(for: score))
                        Text(String(localized: "Recovery \(score)")).font(PulseTheme.captionFont).foregroundStyle(PulseTheme.statusColor(for: score))
                    }
                    .padding(.horizontal, DS.Spacing.s).padding(.vertical, DS.Spacing.m)
                    .background(Capsule().fill(PulseTheme.statusColor(for: score).opacity(0.15)))
                }
            }

            // HK 训练（Apple Watch 同步）
            ForEach(Array(hkWorkouts.enumerated()), id: \.offset) { _, hk in
                HStack(spacing: DS.Spacing.s) {
                    Circle().fill(WorkoutActivityHelper.pulseColor(for: hk.activityType)).frame(width: DS.Spacing.s, height: DS.Spacing.s)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(hk.activityName)
                                .font(DS.Typography.body.weight(.medium))
                                .foregroundStyle(DS.Color.ink)
                            Text("· Apple Watch")
                                .font(DS.Typography.caption).foregroundStyle(DS.Color.inkDim)
                        }
                        HStack(spacing: 8) {
                            Label("\(hk.durationMinutes) \(String(localized: "min"))", systemImage: "clock")
                            if let cal = hk.totalCalories, cal > 0 {
                                Label("\(Int(cal)) kcal", systemImage: "flame.fill")
                            }
                        }
                        .font(DS.Typography.caption).foregroundStyle(DS.Color.inkMid)
                    }
                }
            }

            // 手动记录
            if !manualWorkouts.isEmpty {
                if !hkWorkouts.isEmpty { Divider().background(DS.Color.line) }
                selectedDayDetail(date: date, workouts: manualWorkouts)
                    .background(Color.clear)
            }
        }
        .pulseCard()
    }

    @ViewBuilder
    private func selectedDayDetail(date: Date, workouts: [WorkoutRecord]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            // 日期标题
            HStack {
                Text(dayDetailTitle(date))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)

                Spacer()

                // 恢复评分（如果有）
                if let summary = summaryForDate(date), let score = summary.dailyScore {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "heart.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(PulseTheme.statusColor(for: score))
                        Text("Recovery \(score)")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.statusColor(for: score))
                    }
                    .padding(.horizontal, DS.Spacing.s)
                    .padding(.vertical, DS.Spacing.m)
                    .background(
                        Capsule()
                            .fill(PulseTheme.statusColor(for: score).opacity(0.15))
                    )
                }
            }

            // 每个训练记录
            ForEach(workouts, id: \.id) { workout in
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    // 训练类型 + 时长
                    HStack(spacing: DS.Spacing.s) {
                        Circle()
                            .fill(categoryColor(for: workout.category))
                            .frame(width: DS.Spacing.s, height: DS.Spacing.s)

                        Text(categoryLabel(for: workout.category))
                            .font(DS.Typography.body.weight(.medium))
                            .foregroundStyle(DS.Color.ink)

                        Text("\(workout.durationMinutes) min")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(DS.Color.inkMid)

                        Spacer()

                        // 卡路里
                        if let cal = workout.caloriesBurned, cal > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Color.warn)
                                Text("\(Int(cal)) kcal")
                                    .font(PulseTheme.captionFont)
                                    .foregroundStyle(DS.Color.inkMid)
                            }
                        }
                    }

                    // 动作列表
                    if !workout.exercises.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            ForEach(workout.exercises) { exercise in
                                exerciseRow(exercise)
                            }
                        }
                        .padding(.leading, DS.Spacing.m)
                    }

                    // 备注
                    if let notes = workout.notes, !notes.isEmpty {
                        Text(notes)
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(DS.Color.inkDim)
                            .padding(.leading, DS.Spacing.m)
                    }
                }

                // 多条训练之间的分隔线
                if workout.id != workouts.last?.id {
                    Divider()
                        .background(DS.Color.line)
                }
            }
        }
        .pulseCard()
    }

    /// 单个动作行
    private func exerciseRow(_ exercise: ExerciseEntry) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Text(exercise.name)
                .font(DS.Typography.bodyS)
                .foregroundStyle(DS.Color.inkMid)

            Spacer()

            // 统计组数和代表性重量
            let workingSets = exercise.sets.filter { !$0.isWarmup }
            if !workingSets.isEmpty {
                let maxWeight = workingSets.map(\.weight).max() ?? 0
                let totalSets = workingSets.count
                let repRange = workingSets.map(\.reps)
                let repText = repRange.count == 1 ? "\(repRange[0])" :
                    "\(repRange.min() ?? 0)-\(repRange.max() ?? 0)"

                Text("\(totalSets) sets x \(repText) reps")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)

                if maxWeight > 0 {
                    Text("\(Int(maxWeight)) kg")
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Color.accent)
                }
            }
        }
    }

    /// 日期详情标题，例如 "3月14日 周六"
    private func dayDetailTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM d, EEEE"
        return formatter.string(from: date)
    }

    // MARK: - 月度统计

    private var monthlyStatsCard: some View {
        let workouts = workoutsForCurrentMonth
        let hkWorkouts = hkWorkoutsForCurrentMonth

        let manualDays = Set(workouts.map { calendar.startOfDay(for: $0.date) })
        let hkDays = Set(hkWorkouts.map { calendar.startOfDay(for: $0.startDate) })
        let trainingDays = manualDays.union(hkDays).count
        let totalMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }
            + hkWorkouts.reduce(0) { $0 + $1.durationMinutes }

        // 最常练的部位
        let categoryCounts = Dictionary(grouping: workouts, by: \.category)
            .mapValues(\.count)
        let topCategory = categoryCounts.max(by: { $0.value < $1.value })

        return VStack(spacing: DS.Spacing.m) {
            // 标题
            HStack {
                Text(String(localized: "Monthly Overview"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)
                Spacer()
            }

            HStack(spacing: 0) {
                // 训练天数
                statItem(
                    value: "\(trainingDays)",
                    label: String(localized: "Training Days"),
                    icon: "calendar",
                    color: DS.Color.accent
                )

                // 分隔线
                Rectangle()
                    .fill(DS.Color.line)
                    .frame(width: 0.5, height: 40)

                // 最常练部位
                statItem(
                    value: topCategory.map { categoryLabel(for: $0.key) } ?? "—",
                    label: String(localized: "Top Muscle"),
                    icon: "figure.strengthtraining.traditional",
                    color: topCategory.map { categoryColor(for: $0.key) } ?? DS.Color.inkDim
                )

                // 分隔线
                Rectangle()
                    .fill(DS.Color.line)
                    .frame(width: 0.5, height: 40)

                // 总训练时长
                statItem(
                    value: totalMinutes >= 60 ? "\(totalMinutes / 60)h\(totalMinutes % 60)m" : "\(totalMinutes)m",
                    label: String(localized: "Total Duration"),
                    icon: "clock.fill",
                    color: DS.Color.warn
                )
            }
        }
        .pulseCard()
    }

    /// 统计项
    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: DS.Spacing.s) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(color)

            Text(value)
                .font(DS.Typography.bodyL.weight(.semibold))
                .foregroundStyle(DS.Color.ink)

            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkDim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 分类图例

    private var categoryLegend: some View {
        let legends: [(String, String, Color)] = [
            (String(localized: "Push (Chest/Shoulders)"), "chest",   PulseTheme.trendBlue),
            (String(localized: "Pull (Back)"),   "back",    DS.Color.good),
            (String(localized: "Legs"),        "legs",    DS.Color.warn),
            (String(localized: "Arms"),      "arms",    DS.Color.warn),
            (String(localized: "Cardio"),      "cardio",  PulseTheme.activityAccent),
        ]

        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                Text(String(localized: "Legend"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkDim)
                Spacer()
            }

            // 用两行展示图例，更紧凑
            HStack(spacing: DS.Spacing.m) {
                ForEach(legends, id: \.0) { legend in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(legend.2)
                            .frame(width: DS.Spacing.s, height: DS.Spacing.s)
                        Text(legend.0)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.inkMid)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
    }

    // MARK: - 日历数据模型

    struct CalendarDayItem: Identifiable {
        let id: String
        let day: Int  // 0 表示空白占位
    }

    /// 计算当前月份的日历网格数据
    private var calendarGridData: [CalendarDayItem] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }

        // 计算第一天是星期几（周一=1 … 周日=7）
        var firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        // 系统默认：周日=1，周一=2 … 周六=7
        // 转换为：周一=0，周二=1 … 周日=6
        firstWeekday = (firstWeekday + 5) % 7

        var items: [CalendarDayItem] = []

        // 前置空白
        for i in 0..<firstWeekday {
            items.append(CalendarDayItem(id: "empty-\(i)", day: 0))
        }

        // 实际日期
        for day in range {
            items.append(CalendarDayItem(id: "day-\(day)", day: day))
        }

        return items
    }

    // MARK: - 数据查询辅助

    /// 根据日号构建完整日期
    private func dateForDay(_ day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        return calendar.date(from: components) ?? currentMonth
    }

    /// 获取指定日期的所有训练记录（手动 + HealthKit）
    private func workoutsForDate(_ date: Date) -> [WorkoutRecord]? {
        let dayStart = calendar.startOfDay(for: date)
        let results = allWorkouts.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
        return results.isEmpty ? nil : results
    }

    /// 指定日期的 HealthKit 训练
    private func hkWorkoutsForDate(_ date: Date) -> [WorkoutHistoryEntry] {
        allHKWorkouts.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    /// 任意来源是否有训练
    private func hasAnyWorkout(_ date: Date) -> Bool {
        workoutsForDate(date) != nil || !hkWorkoutsForDate(date).isEmpty
    }

    /// 主要训练颜色（优先手动记录，其次 HK）
    private func primaryCategoryColor(_ date: Date) -> Color {
        if let w = workoutsForDate(date)?.first { return categoryColor(for: w.category) }
        if let hk = hkWorkoutsForDate(date).first { return WorkoutActivityHelper.pulseColor(for: hk.activityType) }
        return .clear
    }

    /// 获取指定日期的健康摘要
    private func summaryForDate(_ date: Date) -> DailySummary? {
        let dateStr = DailySummary.dateFormatter.string(from: date)
        return allSummaries.first { $0.dateString == dateStr }
    }

    /// 当前月份的所有手动训练记录
    private var workoutsForCurrentMonth: [WorkoutRecord] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let lastDay = calendar.date(byAdding: .day, value: range.count, to: firstDay)
        else { return [] }
        return allWorkouts.filter { $0.date >= firstDay && $0.date < lastDay }
    }

    /// 当前月份的 HealthKit 训练（Apple Watch 同步）
    private var hkWorkoutsForCurrentMonth: [WorkoutHistoryEntry] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let lastDay = calendar.date(byAdding: .day, value: range.count, to: firstDay)
        else { return [] }
        return allHKWorkouts.filter { $0.startDate >= firstDay && $0.startDate < lastDay }
    }
}

// MARK: - Array 分块扩展

private extension Array {
    /// 将数组分割成指定大小的子数组
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Preview

#Preview {
    TrainingCalendarView()
        .modelContainer(for: [WorkoutRecord.self, DailySummary.self], inMemory: true)
        .preferredColorScheme(.dark)
}
