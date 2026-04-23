import SwiftUI
import Charts
import os

/// Activity deep-dive — steps, calories, exercise minutes, move goals
struct ActivityDetailView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "ActivityDetailView")

    @State private var healthManager = HealthKitManager.shared
    @State private var chartAppeared = false
    @State private var weekSteps: [(date: Date, steps: Int)] = []
    @State private var selectedStepDate: Date?

    private var steps: Int { healthManager.todaySteps }
    private var calories: Double { healthManager.todayActiveCalories }
    private var exerciseMinutes: Double { healthManager.todayExerciseMinutes }

    private var stepsGoal: Int { 10_000 }
    private var caloriesGoal: Double { 500 }
    private var exerciseGoal: Double { 30 }

    private var stepsProgress: CGFloat { min(CGFloat(steps) / CGFloat(stepsGoal), 1.0) }
    private var caloriesProgress: CGFloat { min(CGFloat(calories) / CGFloat(caloriesGoal), 1.0) }
    private var exerciseProgress: CGFloat { min(CGFloat(exerciseMinutes) / CGFloat(exerciseGoal), 1.0) }

    private var activityStatus: String {
        let pct = Double(steps) / Double(stepsGoal)
        switch pct {
        case 0..<0.3: return String(localized: "Just Getting Started")
        case 0.3..<0.6: return String(localized: "Making Progress")
        case 0.6..<0.9: return String(localized: "Almost There")
        default: return String(localized: "Goal Reached 🎉")
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {

                // ── Three ring-style goals
                goalsCard
                    .staggered(index: 0)

                // ── Steps 7-day bar chart
                if !weekSteps.isEmpty {
                    stepsChartCard
                        .staggered(index: 1)
                }

                // ── Stats grid
                statsGrid
                    .staggered(index: 2)

                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "Activity"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Goals Card (three progress rings)

    private var goalsCard: some View {
        VStack(spacing: PulseTheme.spacingM) {
            HStack {
                Text(String(localized: "Today's Goals"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
                Text(activityStatus)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.accentTeal)
            }

            HStack(spacing: 0) {
                goalRing(
                    progress: stepsProgress,
                    color: PulseTheme.accentTeal,
                    icon: "figure.walk",
                    value: steps >= 1000 ? String(format: "%.1fk", Double(steps)/1000) : "\(steps)",
                    label: String(localized: "Steps"),
                    goal: "\(stepsGoal/1000)k"
                )
                goalRing(
                    progress: caloriesProgress,
                    color: PulseTheme.activityCoral,
                    icon: "flame.fill",
                    value: "\(Int(calories))",
                    label: String(localized: "kcal"),
                    goal: "\(Int(caloriesGoal))"
                )
                goalRing(
                    progress: exerciseProgress,
                    color: PulseTheme.sleepAccent,
                    icon: "heart.fill",
                    value: "\(Int(exerciseMinutes))",
                    label: String(localized: "min"),
                    goal: "\(Int(exerciseGoal))"
                )
            }
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    private func goalRing(progress: CGFloat, color: Color, icon: String, value: String, label: String, goal: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 6)
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: chartAppeared ? progress : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.3), value: chartAppeared)

                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(color)
                    Text(value)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }

            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
                Text("/ \(goal)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Steps Chart

    private var stepsChartCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "Steps · 7 Days"))
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            Chart {
                ForEach(weekSteps, id: \.date) { s in
                    BarMark(
                        x: .value("Day", s.date, unit: .day),
                        y: .value("Steps", chartAppeared ? s.steps : 0)
                    )
                    .foregroundStyle(
                        s.steps >= stepsGoal ? PulseTheme.accentTeal : Color.white.opacity(0.25)
                    )
                    .cornerRadius(4)
                }

                if let selectedStepDate {
                    RuleMark(x: .value("Selected", selectedStepDate, unit: .day))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 0.5))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { val in
                    if let date = val.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.weekday(.abbreviated))
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel {
                        if let v = val.as(Int.self) {
                            Text(v >= 1000 ? "\(v/1000)k" : "\(v)")
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                }
            }
            // Goal line
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let plotFrame = proxy.plotFrame {
                        let goalY = proxy.position(forY: Double(stepsGoal))
                        Path { path in
                            path.move(to: CGPoint(x: geo[plotFrame].minX, y: goalY ?? 0))
                            path.addLine(to: CGPoint(x: geo[plotFrame].maxX, y: goalY ?? 0))
                        }
                        .stroke(PulseTheme.accentTeal.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
            }
            // Selection gesture
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let plotFrame = geo[proxy.plotAreaFrame]
                                let x = value.location.x - plotFrame.origin.x
                                guard let date: Date = proxy.value(atX: x) else { return }
                                let cal = Calendar.current
                                if let nearest = weekSteps.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                    let newDate = cal.startOfDay(for: nearest.date)
                                    if selectedStepDate != newDate {
                                        selectedStepDate = newDate
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.25)) { selectedStepDate = nil }
                            }
                        )
                }
            }
            .overlay(alignment: .top) {
                if let sel = selectedStepDate,
                   let point = weekSteps.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
                    let dateFmt: DateFormatter = {
                        let f = DateFormatter()
                        f.locale = Locale.current
                        f.dateFormat = "EEEE, M/d"
                        return f
                    }()
                    VStack(spacing: 2) {
                        Text(NumberFormatter.localizedString(from: NSNumber(value: point.steps), number: .decimal) + " steps")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(dateFmt.string(from: point.date))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedStepDate)
                }
            }
            .frame(height: 150)
            .animation(.easeInOut(duration: 0.7), value: chartAppeared)
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            statTile(icon: "figure.walk", color: PulseTheme.accentTeal,
                     value: steps >= 1000 ? String(format: "%.1fk", Double(steps)/1000) : "\(steps)",
                     unit: "", label: String(localized: "Total Steps"))
            statTile(icon: "flame.fill", color: PulseTheme.activityCoral,
                     value: "\(Int(calories))", unit: "kcal",
                     label: String(localized: "Active Calories"))
            statTile(icon: "heart.fill", color: PulseTheme.sleepAccent,
                     value: "\(Int(exerciseMinutes))", unit: "min",
                     label: String(localized: "Exercise"))
            statTile(icon: "location.fill", color: PulseTheme.statusWarning,
                     value: String(format: "%.1f", Double(steps) * 0.00076),
                     unit: "km", label: String(localized: "Distance est."))
        }
    }

    private func statTile(icon: String, color: Color, value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                )
        )
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
            )
    }

    private func loadData() async {
        // Fetch 7-day daily steps from HealthKit (auto-deduplicated across sources)
        do {
            let hkData = try await healthManager.fetchWeeklySteps()
            if !hkData.isEmpty {
                weekSteps = hkData.map { (date: $0.date, steps: Int($0.value)) }
            }
        } catch {
            logger.error("Steps weekly fetch error: \(error)")
        }
        withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
            chartAppeared = true
        }
    }
}

#Preview {
    NavigationStack {
        ActivityDetailView()
            .preferredColorScheme(.dark)
    }
}
