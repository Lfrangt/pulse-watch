import SwiftUI

/// 社交分享卡 — 训练完成后生成可分享的成绩图片
/// 支持 Instagram Story (9:16) 和正方形 (1:1)
/// 深色暖调设计，与 Pulse Watch 主题一致
struct ShareCardView: View {

    // MARK: - Data

    let workoutName: String
    let workoutIcon: String
    let workoutColorHex: String
    let durationMinutes: Int
    let calories: Int?
    let averageHeartRate: Int?
    let maxHeartRate: Int?
    let distance: Double?           // meters
    let heartRateZones: [ShareHRZone]
    let date: Date

    var ratio: CardRatio = .story

    // MARK: - Card Ratio

    enum CardRatio: String, CaseIterable, Identifiable {
        case story = "Story"
        case square = "Square"

        var id: String { rawValue }

        var renderSize: CGSize {
            switch self {
            case .story:  return CGSize(width: 1080, height: 1920)
            case .square: return CGSize(width: 1080, height: 1080)
            }
        }

        /// Display size = render / 3 for preview
        var displaySize: CGSize {
            CGSize(width: renderSize.width / 3, height: renderSize.height / 3)
        }

        var label: String {
            switch self {
            case .story:  return "9:16"
            case .square: return "1:1"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundView
            contentStack
        }
        .frame(width: ratio.displaySize.width, height: ratio.displaySize.height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Share card for \(workoutName)"))
        .accessibilityValue("\(formatDuration(durationMinutes))\(calories.map { ", \($0) kcal" } ?? "")")
    }

    // MARK: - Background

    private var workoutColor: Color { Color(hex: workoutColorHex) }

    private var backgroundView: some View {
        ZStack {
            // Deep warm base
            LinearGradient(
                colors: [Color(hex: "0D0C0B"), Color(hex: "1A1715"), Color(hex: "0D0C0B")],
                startPoint: .top,
                endPoint: .bottom
            )

            // Workout color ambient glow — top
            RadialGradient(
                colors: [workoutColor.opacity(0.2), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 300
            )

            // Subtle bottom accent glow
            RadialGradient(
                colors: [PulseTheme.accent.opacity(0.08), Color.clear],
                center: .bottom,
                startRadius: 10,
                endRadius: 200
            )

            // Noise texture simulation — subtle grain
            Rectangle()
                .fill(PulseTheme.highlight)
        }
    }

    // MARK: - Content

    private var contentStack: some View {
        VStack(spacing: ratio == .story ? 28 : 18) {
            if ratio == .story { Spacer().frame(height: 20) }

            // Date
            dateLabel

            // Workout type header
            workoutHeader

            // Key metrics row
            metricsRow

            // Heart rate zones
            if !heartRateZones.isEmpty {
                hrZonesCard
            }

            // Heart rate summary (if available)
            if averageHeartRate != nil || maxHeartRate != nil {
                hrSummaryRow
            }

            if ratio == .story { Spacer() }

            // Watermark
            watermark

            if ratio == .story { Spacer().frame(height: 24) }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, ratio == .square ? 24 : 0)
    }

    // MARK: - Date

    private var dateLabel: some View {
        Text(formattedDate)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(PulseTheme.textTertiary)
    }

    // MARK: - Workout Header

    private var workoutHeader: some View {
        VStack(spacing: 10) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(workoutColor.opacity(0.15))
                    .frame(width: ratio == .story ? 72 : 56, height: ratio == .story ? 72 : 56)

                // Outer glow
                Circle()
                    .fill(workoutColor.opacity(0.06))
                    .frame(width: ratio == .story ? 96 : 72, height: ratio == .story ? 96 : 72)
                    .blur(radius: 12)

                Image(systemName: workoutIcon)
                    .font(.system(size: ratio == .story ? 28 : 22, weight: .medium))
                    .foregroundStyle(workoutColor)
            }

            Text(workoutName)
                .font(.system(size: ratio == .story ? 26 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
        }
    }

    // MARK: - Metrics Row

    private var metricsRow: some View {
        HStack(spacing: 0) {
            // Duration
            metricPill(
                icon: "clock.fill",
                value: formatDuration(durationMinutes),
                color: PulseTheme.accent
            )

            metricDivider

            // Calories
            if let cal = calories, cal > 0 {
                metricPill(
                    icon: "flame.fill",
                    value: "\(cal) kcal",
                    color: PulseTheme.activityAccent
                )
            }

            // Distance (if relevant)
            if let dist = distance, dist > 100 {
                metricDivider
                metricPill(
                    icon: "location.fill",
                    value: String(format: "%.1f km", dist / 1000),
                    color: PulseTheme.statusGood
                )
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PulseTheme.highlight)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PulseTheme.highlight, lineWidth: 0.5)
                )
        )
    }

    private func metricPill(icon: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(PulseTheme.highlight)
            .frame(width: 0.5, height: 32)
    }

    // MARK: - Heart Rate Zones

    private var hrZonesCard: some View {
        VStack(alignment: .leading, spacing: ratio == .story ? 10 : 7) {
            Text(String(localized: "Heart Rate Zones"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
                .padding(.bottom, 2)

            ForEach(heartRateZones) { zone in
                HStack(spacing: 8) {
                    Text(zone.name)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: zone.colorHex))
                        .frame(width: 52, alignment: .leading)

                    // Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(hex: zone.colorHex).opacity(0.12))

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: zone.colorHex).opacity(0.7), Color(hex: zone.colorHex)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * zone.percentage))
                        }
                    }
                    .frame(height: ratio == .story ? 10 : 8)

                    Text("\(Int(zone.percentage * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PulseTheme.highlight)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PulseTheme.highlight, lineWidth: 0.5)
                )
        )
    }

    // MARK: - HR Summary

    private var hrSummaryRow: some View {
        HStack(spacing: 20) {
            if let avg = averageHeartRate {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PulseTheme.activityAccent.opacity(0.8))
                    Text(String(localized: "Avg") + " \(avg) bpm")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }

            if let max = maxHeartRate {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PulseTheme.activityAccent)
                    Text(String(localized: "Max") + " \(max) bpm")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Watermark

    private var watermark: some View {
        HStack(spacing: 8) {
            // Pulse Watch icon
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(PulseTheme.accent.opacity(0.6))

            Text("Tracked with Pulse Watch")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy · HH:mm"
        return fmt.string(from: date)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h\(m)min" : "\(h)h"
        }
        return "\(minutes) min"
    }

    // MARK: - Render to Image

    @MainActor
    func renderImage(for targetRatio: CardRatio) -> UIImage? {
        var card = self
        card.ratio = targetRatio
        let size = targetRatio.displaySize

        let renderer = ImageRenderer(
            content: card
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3.0   // @3x → full 1080px output
        return renderer.uiImage
    }
}

// MARK: - ShareHRZone

struct ShareHRZone: Identifiable {
    var id: String { name }
    let name: String
    let percentage: Double      // 0.0 ~ 1.0
    let colorHex: String
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("Story") {
    ShareCardView(
        workoutName: "Push Day",
        workoutIcon: "dumbbell.fill",
        workoutColorHex: "D4A056",
        durationMinutes: 48,
        calories: 320,
        averageHeartRate: 142,
        maxHeartRate: 175,
        distance: nil,
        heartRateZones: [
            ShareHRZone(name: "Warm-up", percentage: 0.10, colorHex: "7FB069"),
            ShareHRZone(name: "Fat Burn", percentage: 0.15, colorHex: "A8C256"),
            ShareHRZone(name: "Cardio", percentage: 0.40, colorHex: "D4A056"),
            ShareHRZone(name: "Anaerobic", percentage: 0.25, colorHex: "D47456"),
            ShareHRZone(name: "Peak", percentage: 0.10, colorHex: "C75C5C"),
        ],
        date: .now
    )
    .preferredColorScheme(.dark)
}

#Preview("Square") {
    ShareCardView(
        workoutName: "Running",
        workoutIcon: "figure.run",
        workoutColorHex: "C75C5C",
        durationMinutes: 35,
        calories: 410,
        averageHeartRate: 158,
        maxHeartRate: 185,
        distance: 5230,
        heartRateZones: [
            ShareHRZone(name: "Warm-up", percentage: 0.05, colorHex: "7FB069"),
            ShareHRZone(name: "Fat Burn", percentage: 0.10, colorHex: "A8C256"),
            ShareHRZone(name: "Cardio", percentage: 0.45, colorHex: "D4A056"),
            ShareHRZone(name: "Anaerobic", percentage: 0.30, colorHex: "D47456"),
            ShareHRZone(name: "Peak", percentage: 0.10, colorHex: "C75C5C"),
        ],
        date: .now,
        ratio: .square
    )
    .preferredColorScheme(.dark)
}
