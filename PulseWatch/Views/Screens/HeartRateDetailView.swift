import SwiftUI
import Charts

/// Heart Rate deep-dive — current, resting, zones context
struct HeartRateDetailView: View {

    @State private var healthManager = HealthKitManager.shared
    @State private var chartAppeared = false

    private var current: Double { healthManager.latestHeartRate ?? 0 }
    private var resting: Double { healthManager.latestRestingHR ?? 0 }

    private var statusLabel: String {
        switch current {
        case 0..<50:  return String(localized: "Very Low")
        case 50..<60: return String(localized: "Athletic")
        case 60..<80: return String(localized: "Normal")
        case 80..<100: return String(localized: "Elevated")
        default:      return String(localized: "High")
        }
    }

    private var statusColor: Color {
        switch current {
        case 0..<50:  return PulseTheme.statusWarning
        case 50..<80: return PulseTheme.statusGood
        case 80..<100: return PulseTheme.statusWarning
        default:      return PulseTheme.statusPoor
        }
    }

    // HR zones (classic 5-zone)
    private struct Zone: Identifiable {
        let id = UUID()
        let name: String
        let range: String
        let color: Color
        let description: String
    }

    private let zones: [Zone] = [
        .init(name: "Zone 1", range: "50–60%", color: Color(hex: "4FC3F7"),
              description: String(localized: "Recovery — walking, gentle movement")),
        .init(name: "Zone 2", range: "60–70%", color: Color(hex: "81C784"),
              description: String(localized: "Base endurance — conversational pace")),
        .init(name: "Zone 3", range: "70–80%", color: Color(hex: "FFD54F"),
              description: String(localized: "Aerobic — moderate effort, slightly breathless")),
        .init(name: "Zone 4", range: "80–90%", color: Color(hex: "FF8A65"),
              description: String(localized: "Threshold — hard effort, building lactate")),
        .init(name: "Zone 5", range: "90–100%", color: Color(hex: "EF5350"),
              description: String(localized: "Max effort — short sprints only")),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {

                heroCard
                    .staggered(index: 0)

                zonesCard
                    .staggered(index: 1)

                tipsCard
                    .staggered(index: 2)

                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "Heart Rate"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 0) {
            // Current HR
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(current))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("bpm")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .offset(y: 4)
                }
                Text(String(localized: "Current · ") + statusLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(statusColor)
            }

            Spacer()

            // Resting HR
            if resting > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(resting))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("bpm")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                    Text(String(localized: "Resting HR"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    // MARK: - Zones

    private var zonesCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "Heart Rate Zones"))
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            ForEach(zones) { zone in
                HStack(spacing: 12) {
                    // Color bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(zone.color)
                        .frame(width: 4, height: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(zone.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(zone.range)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(zone.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(zone.color.opacity(0.12)))
                        }
                        Text(zone.description)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(PulseTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                if zone.id != zones.last?.id {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    // MARK: - Tips

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "Training Tips"))
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            tipRow(icon: "bed.double.fill", color: PulseTheme.sleepAccent,
                   title: String(localized: "Lower resting HR = better fitness"),
                   body: String(localized: "Elite athletes often have resting HR of 40-50 bpm. Consistent Zone 2 training reduces it over months."))
            Divider().background(Color.white.opacity(0.06))
            tipRow(icon: "chart.line.uptrend.xyaxis", color: PulseTheme.accentTeal,
                   title: String(localized: "80/20 rule"),
                   body: String(localized: "80% of training should be Zone 1-2 (easy). Only 20% hard. Most people train too hard too often."))
            Divider().background(Color.white.opacity(0.06))
            tipRow(icon: "heart.fill", color: PulseTheme.statusPoor,
                   title: String(localized: "Max HR = 220 − age (rough guide)"),
                   body: String(localized: "Use this to estimate your zone thresholds. A lab lactate test gives the most accurate result."))
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    private func tipRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(body)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
            )
    }
}

#Preview {
    NavigationStack {
        HeartRateDetailView()
            .preferredColorScheme(.dark)
    }
}
