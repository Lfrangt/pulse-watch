import SwiftUI
import Charts
import SwiftData

struct StepsDetailView: View {
    private let healthManager = HealthKitManager.shared
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    @State private var selectedStepDate: Date?

    private var steps: Int { healthManager.todaySteps }
    private var goal: Int { 8000 }
    private var progress: Double { min(1.0, Double(steps) / Double(goal)) }

    private var statusLabel: String {
        switch steps {
        case 0..<3000: return String(localized: "Insufficient Activity")
        case 3000..<6000: return String(localized: "Low Activity")
        case 6000..<8000: return String(localized: "Near Goal")
        case 8000..<10000: return String(localized: "On Target")
        default: return String(localized: "Goal Exceeded")
        }
    }
    private var statusColor: Color {
        steps >= 8000 ? PulseTheme.accentTeal : steps >= 5000 ? PulseTheme.statusWarning : PulseTheme.activityCoral
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
        .navigationTitle(String(localized: "Steps"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(steps)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(String(localized: "steps"))
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(y: -8)
            }

            // Progress ring-style bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [statusColor.opacity(0.7), statusColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 8)

            HStack {
                Text(statusLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(statusColor.opacity(0.13)))
                Spacer()
                Text(String(localized: "Goal \(goal) steps"))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(PulseTheme.spacingM)
        .background(glassCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Steps"))
        .accessibilityValue("\(steps), \(statusLabel)")
    }

    private var weeklyChart: some View {
        let data = summaries.prefix(14).reversed().compactMap { s -> (date: Date, steps: Int)? in
            guard let st = s.totalSteps, st > 0 else { return nil }
            return (s.date, st)
        }
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(String(localized: "14-Day Step Trend"), icon: "figure.run")
            if data.isEmpty {
                emptyHint
            } else {
                Chart {
                    ForEach(data, id: \.date) { item in
                        BarMark(x: .value("Date", item.date, unit: .day), y: .value("Steps", item.steps), width: .ratio(0.6))
                            .foregroundStyle(item.steps >= goal ? PulseTheme.accentTeal.opacity(0.8) : PulseTheme.activityCoral.opacity(0.6))
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(PulseTheme.accentTeal.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    if let selectedStepDate {
                        RuleMark(x: .value("Selected", selectedStepDate, unit: .day))
                            .foregroundStyle(.white.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 0.5))
                    }
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.defaultDigits).day()).font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.4)) } }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4])).foregroundStyle(Color.white.opacity(0.07)); AxisValueLabel().font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.4)) } }
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
                       let point = data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
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
                .frame(height: 160)
            }
        }
        .padding(PulseTheme.spacingM)
        .background(glassCard)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(String(localized: "Why Steps Matter"), icon: "info.circle")
            tipRow(String(localized: "8,000 daily steps is linked to significantly lower all-cause mortality (JAMA study)."))
            tipRow(String(localized: "Walking is the simplest form of aerobic exercise and protects cardiovascular health."))
            tipRow(String(localized: "Combat prolonged sitting by walking 2–3 minutes every hour."))
        }
        .padding(PulseTheme.spacingM)
        .background(glassCard)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(PulseTheme.accentTeal)
            Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).tracking(0.5).foregroundStyle(PulseTheme.textTertiary)
        }
    }
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(PulseTheme.accentTeal.opacity(0.5)).frame(width: 5, height: 5).padding(.top, 5)
            Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var emptyHint: some View {
        EmptyStateView(
            icon: "figure.walk",
            title: String(localized: "No Step Data"),
            message: String(localized: "Wear your Apple Watch to start tracking steps")
        )
    }
    private var glassCard: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}
