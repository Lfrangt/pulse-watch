import SwiftUI
import Charts
import SwiftData

struct BloodOxygenDetailView: View {
    @State private var healthManager = HealthKitManager.shared
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]

    private var spo2: Double { healthManager.latestBloodOxygen ?? 0 }
    private var statusLabel: String {
        switch spo2 {
        case 98...100: return String(localized: "Excellent")
        case 96..<98:  return String(localized: "Normal")
        case 93..<96:  return String(localized: "Low")
        default:       return spo2 > 0 ? String(localized: "Attention") : "--"
        }
    }
    private var statusColor: Color {
        switch spo2 {
        case 96...100: return PulseTheme.accentTeal
        case 93..<96:  return PulseTheme.statusWarning
        default:       return spo2 > 0 ? PulseTheme.activityCoral : PulseTheme.textTertiary
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {
                heroCard
                weeklyChart
                rangeCard
                infoCard
                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)
        }
        .background(PulseTheme.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Blood Oxygen"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(spo2 > 0 ? "\(Int(spo2))" : "--")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(y: -8)
            }
            Text(statusLabel)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(statusColor.opacity(0.13)))
            Text(String(localized: "Normal range: 95% – 100%"))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24).padding(.horizontal, PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(LinearGradient(colors: [statusColor.opacity(0.15), statusColor.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous).stroke(statusColor.opacity(0.2), lineWidth: 0.5))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Blood Oxygen"))
        .accessibilityValue(spo2 > 0 ? "\(Int(spo2))%, \(statusLabel)" : String(localized: "No data"))
    }

    private var weeklyChart: some View {
        let data = summaries.prefix(14).reversed().compactMap { s -> (date: Date, spo2: Double)? in
            // No SpO2 field in DailySummary — skip or use placeholder
            return nil
        }
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(String(localized: "14-Day Trend"), icon: "lungs.fill")
            // SpO2 daily storage not yet implemented — show live reading context
            VStack(spacing: 8) {
                HStack {
                    Text(String(localized: "Current Reading"))
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text(spo2 > 0 ? "\(Int(spo2))%" : "--")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                }
                Text(String(localized: "Blood oxygen is measured in real-time by Apple Watch. Continuous history will be supported in a future update."))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.35))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PulseTheme.spacingM).background(glassCard)
    }

    private var rangeCard: some View {
        let ranges: [(String, String, Color)] = [
            ("98% – 100%", String(localized: "Excellent — red blood cells fully oxygenated"), PulseTheme.accentTeal),
            ("95% – 97%",  String(localized: "Normal range — no concern"), .white.opacity(0.6)),
            ("93% – 94%",  String(localized: "Low — try deep breathing and rest"), PulseTheme.statusWarning),
            ("< 93%",      String(localized: "Abnormal — consider medical attention"), PulseTheme.activityCoral),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(String(localized: "SpO2 Reference Ranges"), icon: "chart.bar.fill")
            ForEach(ranges, id: \.0) { range in
                HStack(spacing: 12) {
                    Capsule().fill(range.2).frame(width: 4, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(range.0).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        Text(range.1).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(PulseTheme.spacingM).background(glassCard)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(String(localized: "About Blood Oxygen"), icon: "info.circle")
            tipRow(String(localized: "SpO2 measures how well your blood carries oxygen. Normal resting levels should be above 95%."))
            tipRow(String(localized: "Intense exercise, high altitude, or sleep apnea can cause temporary drops."))
            tipRow(String(localized: "Apple Watch blood oxygen readings are for wellness purposes only, not medical diagnosis."))
        }
        .padding(PulseTheme.spacingM).background(glassCard)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(statusColor)
            Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).tracking(0.5).foregroundStyle(PulseTheme.textTertiary)
        }
    }
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(statusColor.opacity(0.5)).frame(width: 5, height: 5).padding(.top, 5)
            Text(text).font(.system(size: 13)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var glassCard: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}
