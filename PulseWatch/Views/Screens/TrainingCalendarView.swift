import SwiftUI
import SwiftData

/// 智能训练日历 — 按月查看训练记录，直观展示肌群分布
struct TrainingCalendarView: View {

    // MARK: - 数据查询

    @Query(sort: \WorkoutRecord.date, order: .forward)
    private var allWorkouts: [WorkoutRecord]

    @Query(sort: \DailySummary.date, order: .forward)
    private var allSummaries: [DailySummary]

    // MARK: - 状态

    @State private var currentMonth: Date = .now
    @State private var selectedDate: Date?
    @State private var animateDetail = false

    // MARK: - 常量

    private let calendar = Calendar.current
    private let weekdayHeaders = ["一", "二", "三", "四", "五", "六", "日"]

    // MARK: - 训练分类颜色

    /// 根据训练类别返回对应颜色
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "chest", "shoulders":
            return Color(hex: "5B8DEF")   // Push — 蓝色
        case "back":
            return Color(hex: "7FB069")   // Pull — 绿色
        case "legs":
            return Color(hex: "D4A056")   // 腿 — 琥珀色
        case "arms":
            return Color(hex: "C9A96E")   // 手臂 — 金色
        case "cardio":
            return Color(hex: "C75C5C")   // 有氧 — 红色
        default:
            return PulseTheme.textTertiary
        }
    }

    /// 训练类别中文名
    private func categoryLabel(for category: String) -> String {
        switch category.lowercased() {
        case "chest":      return "胸部"
        case "back":       return "背部"
        case "legs":       return "腿部"
        case "shoulders":  return "肩部"
        case "arms":       return "手臂"
        case "cardio":     return "有氧"
        default:           return category
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseTheme.spacingM) {
                    // 月份导航
                    monthNavigationBar
                        .staggered(index: 0)

                    // 日历网格
                    calendarGrid
                        .staggered(index: 1)

                    // 选中日期详情
                    if let selectedDate, let workouts = workoutsForDate(selectedDate), !workouts.isEmpty {
                        selectedDayDetail(date: selectedDate, workouts: workouts)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                            .staggered(index: 2)
                    }

                    // 月度统计
                    monthlyStatsCard
                        .staggered(index: 3)

                    // 分类图例
                    categoryLegend
                        .staggered(index: 4)

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingS)
            }
            .background(PulseTheme.background)
            .navigationTitle("训练日历")
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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(PulseTheme.accent.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            Text(monthYearString)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(PulseTheme.accent.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, PulseTheme.spacingS)
    }

    /// 当前月份的标题字符串，例如 "2026年3月"
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: currentMonth)
    }

    // MARK: - 日历网格

    private var calendarGrid: some View {
        VStack(spacing: PulseTheme.spacingS) {
            // 星期头部
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, PulseTheme.spacingXS)

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
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .shadow(color: PulseTheme.cardShadow, radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
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
            let hasWorkout = workouts != nil && !workouts!.isEmpty
            let isSelected = selectedDate != nil && calendar.isDate(dayDate, inSameDayAs: selectedDate!)
            let isToday = calendar.isDateInToday(dayDate)
            let workoutColor = hasWorkout ? categoryColor(for: workouts!.first!.category) : Color.clear

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
                            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                                .fill(workoutColor.opacity(0.2))
                        }

                        // 选中高亮
                        if isSelected {
                            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                                .stroke(PulseTheme.accent, lineWidth: 1.5)
                        }

                        // 今天标记
                        if isToday && !isSelected {
                            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                                .stroke(PulseTheme.textTertiary.opacity(0.5), lineWidth: 1)
                        }

                        Text("\(item.day)")
                            .font(.system(size: 14, weight: isToday ? .bold : .regular, design: .rounded))
                            .foregroundStyle(isSelected ? PulseTheme.accent :
                                                isToday ? PulseTheme.textPrimary :
                                                hasWorkout ? PulseTheme.textPrimary :
                                                PulseTheme.textSecondary)
                    }
                    .frame(width: 34, height: 34)

                    // 训练指示点
                    Circle()
                        .fill(hasWorkout ? workoutColor : Color.clear)
                        .frame(width: 5, height: 5)
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 48)
        }
    }

    // MARK: - 选中日期详情

    @ViewBuilder
    private func selectedDayDetail(date: Date, workouts: [WorkoutRecord]) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // 日期标题
            HStack {
                Text(dayDetailTitle(date))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                Spacer()

                // 恢复评分（如果有）
                if let summary = summaryForDate(date), let score = summary.dailyScore {
                    HStack(spacing: PulseTheme.spacingXS) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.statusColor(for: score))
                        Text("恢复 \(score)")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.statusColor(for: score))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(PulseTheme.statusColor(for: score).opacity(0.15))
                    )
                }
            }

            // 每个训练记录
            ForEach(workouts, id: \.id) { workout in
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    // 训练类型 + 时长
                    HStack(spacing: PulseTheme.spacingS) {
                        Circle()
                            .fill(categoryColor(for: workout.category))
                            .frame(width: 8, height: 8)

                        Text(categoryLabel(for: workout.category))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)

                        Text("\(workout.durationMinutes) 分钟")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textSecondary)

                        Spacer()

                        // 卡路里
                        if let cal = workout.caloriesBurned, cal > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PulseTheme.statusModerate)
                                Text("\(Int(cal)) kcal")
                                    .font(PulseTheme.captionFont)
                                    .foregroundStyle(PulseTheme.textSecondary)
                            }
                        }
                    }

                    // 动作列表
                    if !workout.exercises.isEmpty {
                        VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                            ForEach(workout.exercises) { exercise in
                                exerciseRow(exercise)
                            }
                        }
                        .padding(.leading, PulseTheme.spacingM)
                    }

                    // 备注
                    if let notes = workout.notes, !notes.isEmpty {
                        Text(notes)
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                            .padding(.leading, PulseTheme.spacingM)
                    }
                }

                // 多条训练之间的分隔线
                if workout.id != workouts.last?.id {
                    Divider()
                        .background(PulseTheme.border)
                }
            }
        }
        .pulseCard()
    }

    /// 单个动作行
    private func exerciseRow(_ exercise: ExerciseEntry) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            Text(exercise.name)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)

            Spacer()

            // 统计组数和代表性重量
            let workingSets = exercise.sets.filter { !$0.isWarmup }
            if !workingSets.isEmpty {
                let maxWeight = workingSets.map(\.weight).max() ?? 0
                let totalSets = workingSets.count
                let repRange = workingSets.map(\.reps)
                let repText = repRange.count == 1 ? "\(repRange[0])" :
                    "\(repRange.min() ?? 0)-\(repRange.max() ?? 0)"

                Text("\(totalSets) 组 x \(repText) 次")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)

                if maxWeight > 0 {
                    Text("\(Int(maxWeight)) kg")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.accent)
                }
            }
        }
    }

    /// 日期详情标题，例如 "3月14日 周六"
    private func dayDetailTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    // MARK: - 月度统计

    private var monthlyStatsCard: some View {
        let workouts = workoutsForCurrentMonth

        let trainingDays = Set(workouts.map { calendar.startOfDay(for: $0.date) }).count
        let totalMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }

        // 最常练的部位
        let categoryCounts = Dictionary(grouping: workouts, by: \.category)
            .mapValues(\.count)
        let topCategory = categoryCounts.max(by: { $0.value < $1.value })

        return VStack(spacing: PulseTheme.spacingM) {
            // 标题
            HStack {
                Text("本月概览")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 0) {
                // 训练天数
                statItem(
                    value: "\(trainingDays)",
                    label: "训练天数",
                    icon: "calendar",
                    color: PulseTheme.accent
                )

                // 分隔线
                Rectangle()
                    .fill(PulseTheme.border)
                    .frame(width: 0.5, height: 40)

                // 最常练部位
                statItem(
                    value: topCategory != nil ? categoryLabel(for: topCategory!.key) : "—",
                    label: "最常练的部位",
                    icon: "figure.strengthtraining.traditional",
                    color: topCategory != nil ? categoryColor(for: topCategory!.key) : PulseTheme.textTertiary
                )

                // 分隔线
                Rectangle()
                    .fill(PulseTheme.border)
                    .frame(width: 0.5, height: 40)

                // 总训练时长
                statItem(
                    value: totalMinutes >= 60 ? "\(totalMinutes / 60)h\(totalMinutes % 60)m" : "\(totalMinutes)m",
                    label: "总训练时长",
                    icon: "clock.fill",
                    color: PulseTheme.statusModerate
                )
            }
        }
        .pulseCard()
    }

    /// 统计项
    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: PulseTheme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 分类图例

    private var categoryLegend: some View {
        let legends: [(String, String, Color)] = [
            ("推 (胸/肩)", "chest",   Color(hex: "5B8DEF")),
            ("拉 (背)",   "back",    Color(hex: "7FB069")),
            ("腿",        "legs",    Color(hex: "D4A056")),
            ("手臂",      "arms",    Color(hex: "C9A96E")),
            ("有氧",      "cardio",  Color(hex: "C75C5C")),
        ]

        return VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            HStack {
                Text("分类图例")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
                Spacer()
            }

            // 用两行展示图例，更紧凑
            HStack(spacing: PulseTheme.spacingM) {
                ForEach(legends, id: \.0) { legend in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(legend.2)
                            .frame(width: 8, height: 8)
                        Text(legend.0)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(PulseTheme.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, PulseTheme.spacingXS)
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

    /// 获取指定日期的所有训练记录
    private func workoutsForDate(_ date: Date) -> [WorkoutRecord]? {
        let dayStart = calendar.startOfDay(for: date)
        let results = allWorkouts.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
        return results.isEmpty ? nil : results
    }

    /// 获取指定日期的健康摘要
    private func summaryForDate(_ date: Date) -> DailySummary? {
        let dateStr = DailySummary.dateFormatter.string(from: date)
        return allSummaries.first { $0.dateString == dateStr }
    }

    /// 当前月份的所有训练记录
    private var workoutsForCurrentMonth: [WorkoutRecord] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let lastDay = calendar.date(byAdding: .day, value: range.count, to: firstDay)
        else { return [] }

        return allWorkouts.filter { $0.date >= firstDay && $0.date < lastDay }
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
