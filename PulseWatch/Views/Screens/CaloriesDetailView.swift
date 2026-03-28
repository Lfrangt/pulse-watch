import SwiftUI
import Charts
import SwiftData

struct CaloriesDetailView: View {
    @State private var healthManager = HealthKitManager.shared
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]

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
                    .foregroundStyle(.white)
                Text("kcal")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(y: -6)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 8)
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
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.4))
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
                Chart(data, id: \.date) { item in
                    BarMark(x: .value("Date", item.date, unit: .day), y: .value("Cal", item.cal), width: .ratio(0.6))
                        .foregroundStyle(item.cal >= goal ? PulseTheme.accentTeal.opacity(0.8) : PulseTheme.activityCoral.opacity(0.6))
                        .cornerRadius(4)
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(PulseTheme.accentTeal.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.month(.defaultDigits).day()).font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.4)) } }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [4])).foregroundStyle(Color.white.opacity(0.07)); AxisValueLabel().font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.4)) } }
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
            Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
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
            .fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}
