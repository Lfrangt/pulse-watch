import SwiftUI
import Charts
import SwiftData

struct CaloriesDetailView: View {
    private let healthManager = HealthKitManager.shared
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    @State private var selectedCalDate: Date?

    private var active: Double { healthManager.todayActiveCalories }
    private var goal: Double { 400 }
    private var progress: Double { min(1.0, active / goal) }
    private var statusColor: Color { active >= goal ? PulseTheme.accentTeal : active >= 250 ? PulseTheme.statusWarning : PulseTheme.activityCoral }
    private var statusLabel: String {
        switch active {
        case 0..<150: return String(localized: "Low Activity")
        case 150..<300: return String(localized: "Light Activity")
        case 300..<400: return String(localized: "Near Goal")
        default: return String(localized: "Goal Reached")
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {
                heroCard
                weeklyChart
                infoCard
                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)
        }
        .background(PulseTheme.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Calories"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(active))")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text("kcal")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
                    .offset(y: -6)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PulseTheme.highlight).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [statusColor.opacity(0.7), statusColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8).padding(.horizontal, 8)
            HStack {
                Text(statusLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(statusColor.opacity(0.13)))
                Spacer()
                Text(String(localized: "Goal \(Int(goal)) kcal"))
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .padding(PulseTheme.spacingM).background(glassCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Active Calories"))
        .accessibilityValue("\(Int(active)) kcal, \(statusLabel)")
    }

    private var weeklyChart: some View {
        let data = summaries.prefix(14).reversed().compactMap { s -> (date: Date, cal: Double)? in
            guard let c = s.activeCalories, c > 0 else { return nil }
            return (s.date, c)
        }
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(String(localized: "14-Day Calorie Trend"), icon: "flame.fill")
            if data.isEmpty { emptyHint } else {
                Chart {
                    ForEach(data, id: \.date) { item in
                        BarMark(x: .value("Date", item.date, unit: .day), y: .value("Cal", item.cal), width: .ratio(0.6))
                            .foregroundStyle(item.cal >= goal ? PulseTheme.accentTeal.opacity(0.8) : PulseTheme.activityCoral.opacity(0.6))
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(PulseTheme.accentTeal.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    if let selectedCalDate {
                        RuleMark(x: .value("Selected", selectedCalDate, unit: .day))
                            .foregroundStyle(PulseTheme.textTertiary)
                            .lineStyle(StrokeStyle(lineWidth: 0.5))
                    }
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.defaultDigits).day()).font(.system(size: 9)).foregroundStyle(PulseTheme.highlight) } }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4])).foregroundStyle(PulseTheme.highlight); AxisValueLabel().font(.system(size: 9)).foregroundStyle(PulseTheme.highlight) } }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let plotFrame = geo[proxy.plotAreaFrame]
                                    let x = value.location.x - plotFrame.origin.x
                                    guard let date: Date = proxy.value(atX: x) else { return }
                                    let cal = Calendar.current
                                    if let nearest = data.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                        let newDate = cal.startOfDay(for: nearest.date)
                                        if selectedCalDate != newDate {
                                            selectedCalDate = newDate
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.25)) { selectedCalDate = nil }
                                }
                            )
                    }
                }
                .overlay(alignment: .top) {
                    if let sel = selectedCalDate,
                       let point = data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
                        let dateFmt: DateFormatter = {
                            let f = DateFormatter()
                            f.locale = Locale.current
                            f.dateFormat = "EEEE, M/d"
                            return f
                        }()
                        VStack(spacing: 2) {
                            Text("\(Int(point.cal)) kcal")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text(dateFmt.string(from: point.date))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(PulseTheme.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedCalDate)
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(PulseTheme.spacingM).background(glassCard)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(String(localized: "About Active Calories"), icon: "info.circle")
            tipRow(String(localized: "Active calories are burned through exercise and daily movement, excluding basal metabolism."))
            tipRow(String(localized: "Burning 300–500 kcal daily supports weight management and cardiovascular health."))
            tipRow(String(localized: "Strength training raises resting metabolic rate, aiding long-term calorie management."))
        }
        .padding(PulseTheme.spacingM).background(glassCard)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(PulseTheme.activityCoral)
            Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).tracking(0.5).foregroundStyle(PulseTheme.textTertiary)
        }
    }
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(PulseTheme.activityCoral.opacity(0.5)).frame(width: 5, height: 5).padding(.top, 5)
            Text(text).font(.system(size: 13)).foregroundStyle(PulseTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var emptyHint: some View {
        EmptyStateView(
            icon: "flame",
            title: String(localized: "No Calorie Data"),
            message: String(localized: "Wear your Apple Watch to start tracking calories")
        )
    }
    private var glassCard: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
            .fill(PulseTheme.highlight)
            .overlay(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous).stroke(PulseTheme.highlight, lineWidth: 0.5))
    }
}
