import SwiftUI
import Charts

struct HealthAgeDetailView: View {
    let result: HealthAgeService.HealthAgeResult

    private let accentColor: Color
    private let diff: Double
    private let isYounger: Bool

    init(result: HealthAgeService.HealthAgeResult) {
        self.result = result
        self.diff = result.difference
        self.isYounger = result.difference < -0.5
        self.accentColor = result.difference < -0.5 ? PulseTheme.accentTeal : PulseTheme.activityCoral
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {

                // MARK: - Hero Card
                heroCard

                // MARK: - Metrics breakdown
                metricsSection

                // MARK: - What affects health age
                whatAffectsCard

                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)
        }
        .background(PulseTheme.background.ignoresSafeArea())
        .navigationTitle("Health Age")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 20) {
            // Big age number
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(result.healthAge.rounded()))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("yrs")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .offset(y: -8)
            }

            // Delta badge
            if abs(diff) > 0.5 {
                HStack(spacing: 6) {
                    Image(systemName: isYounger ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 16))
                    Text(String(format: "%d years %@ than actual age",
                                Int(abs(diff).rounded()),
                                isYounger ? "younger" : "older"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(accentColor.opacity(0.13)))
            }

            // Actual age row
            HStack(spacing: 4) {
                Text("Actual age:")
                    .foregroundStyle(.white.opacity(0.4))
                Text("\(result.chronologicalAge) yrs")
                    .foregroundStyle(.white.opacity(0.7))
                Text("·")
                    .foregroundStyle(.white.opacity(0.2))
                Text("Based on \(result.daysOfData) days of data")
                    .foregroundStyle(.white.opacity(0.4))
            }
            .font(.system(size: 13, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.15), accentColor.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                        .stroke(accentColor.opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metric Details")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(PulseTheme.textTertiary)

            VStack(spacing: 8) {
                ForEach(result.metrics, id: \.metric) { metric in
                    metricRow(metric)
                }
            }
        }
    }

    private func metricRow(_ m: HealthAgeService.MetricScore) -> some View {
        let isGood = m.ageImpact < -0.3
        let isBad  = m.ageImpact > 0.3
        let rowColor: Color = isGood ? PulseTheme.accentTeal : (isBad ? PulseTheme.activityCoral : PulseTheme.textSecondary)
        let impactText = abs(m.ageImpact) < 0.3 ? "No impact" :
            (m.ageImpact < 0 ? String(format: "%.1f yrs younger", abs(m.ageImpact))
                             : String(format: "%.1f yrs older", m.ageImpact))

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle().fill(rowColor.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: m.metric.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(rowColor)
                }

                // Label + advice
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(localizedMetricLabel(m.metric))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(formatValue(m))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(rowColor)
                    }
                    Text(m.advice)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }
            .padding(14)

            // Impact bar
            HStack(spacing: 8) {
                Spacer().frame(width: 48)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06)).frame(height: 3)
                        Capsule()
                            .fill(rowColor.opacity(0.7))
                            .frame(width: geo.size.width * min(CGFloat(abs(m.ageImpact)) / 3.0, 1.0), height: 3)
                    }
                }
                .frame(height: 3)
                Text(impactText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(rowColor.opacity(0.8))
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - What affects

    private var whatAffectsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What Affects Health Age?")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(PulseTheme.textTertiary)

            VStack(alignment: .leading, spacing: 10) {
                tipRow(icon: "heart.fill", color: PulseTheme.activityCoral,
                       text: "Lower resting HR and higher HRV indicate better cardiovascular health")
                tipRow(icon: "moon.fill", color: PulseTheme.sleepViolet,
                       text: "7-9 hours of sleep per night supports cell repair and metabolism")
                tipRow(icon: "figure.run", color: PulseTheme.accentTeal,
                       text: "8,000+ daily steps significantly reduces all-cause mortality")
                tipRow(icon: "info.circle", color: .white.opacity(0.4),
                       text: "Based on population averages — for reference only, not medical diagnosis")
            }
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private func tipRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private func localizedMetricLabel(_ metric: HealthAgeService.MetricScore.Metric) -> String {
        switch metric {
        case .restingHR:     return "Resting Heart Rate"
        case .hrv:           return "Heart Rate Variability"
        case .sleep:         return "Sleep Duration"
        case .steps:         return "Daily Steps"
        case .activeMinutes: return "Active Minutes"
        }
    }

    private func formatValue(_ m: HealthAgeService.MetricScore) -> String {
        switch m.metric {
        case .restingHR:     return String(format: "%.0f bpm", m.value)
        case .hrv:           return String(format: "%.0f ms", m.value)
        case .sleep:         return String(format: "%.1fh", m.value)
        case .steps:         return String(format: "%.0f steps", m.value)
        case .activeMinutes: return String(format: "%.0f min", m.value)
        }
    }
}



#Preview {
    NavigationStack {
        HealthAgeDetailView(result: HealthAgeService.demoResult)
    }
    .preferredColorScheme(.dark)
}
