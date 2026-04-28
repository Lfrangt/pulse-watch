import SwiftUI

// MARK: - SleepBandCard
// Last Night sleep summary — mirrors Today.jsx SleepCard (the simpler version).
// Top row: "Last Night" eyebrow + bed/wake time mono.
// Big duration with `h`/`m` separator chars in textTertiary.
// Status chip ("Regular" / "Short" / "Long") with rounded outline.
// Horizontal sleep stage band (4 segments: Awake / Core / REM / Deep, grayscale).
// Below: 4-column legend with swatches.

struct SleepBandCard: View {
    let totalMinutes: Int
    let deepMinutes: Int
    let remMinutes: Int
    let coreMinutes: Int
    let awakeMinutes: Int
    let bedTime: Date?
    let wakeTime: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: eyebrow + time range
            HStack {
                Text("Last Night")
                    .pulseEyebrow()
                Spacer()
                Text(timeRangeText)
                    .font(PulseTheme.monoFont)
                    .foregroundStyle(PulseTheme.textSecondary)
            }

            // Big duration + status chip
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                durationView
                Spacer()
                statusChip
            }
            .padding(.top, 10)

            // Sleep stage band
            stageBand
                .padding(.top, 16)

            // Legend
            legendRow
                .padding(.top, 10)
        }
        .pulseCard()
    }

    // MARK: - Duration display ("7h 34m" with h/m in textTertiary)

    private var durationView: some View {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        return HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text("\(hours)")
                .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(PulseTheme.textPrimary)
            Text("h")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
            Text(" \(minutes)")
                .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(PulseTheme.textPrimary)
            Text("m")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
        }
    }

    // MARK: - Status chip

    private var statusChip: some View {
        let label: String
        let hours = Double(totalMinutes) / 60.0

        if hours < 7 {
            label = "Short"
        } else if hours > 9 {
            label = "Long"
        } else {
            label = "Regular"
        }

        return Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(PulseTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusXS, style: .continuous)
                    .stroke(PulseTheme.border, lineWidth: PulseTheme.hairline)
            )
    }

    // MARK: - Stage band — single rounded rectangle composed of weighted segments

    private var stageBand: some View {
        // Order matches Today.jsx legend reading: Awake / Core / REM / Deep
        // We render in chronological-ish order Awake -> Core -> REM -> Deep.
        // Use weighted GeometryReader-free flexed HStack via maxWidth proportions.
        let segments: [(weight: Double, color: Color)] = [
            (Double(max(awakeMinutes, 0)), PulseTheme.textQuaternary),
            (Double(max(coreMinutes, 0)),  PulseTheme.textTertiary),
            (Double(max(remMinutes, 0)),   PulseTheme.textSecondary),
            (Double(max(deepMinutes, 0)),  PulseTheme.textPrimary)
        ]
        let total = max(segments.reduce(0) { $0 + $1.weight }, 1)

        return GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    Rectangle()
                        .fill(seg.color)
                        .frame(width: geo.size.width * (seg.weight / total))
                }
            }
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    // MARK: - Legend (4 columns)

    private var legendRow: some View {
        HStack(alignment: .top, spacing: 0) {
            LegendItem(swatch: PulseTheme.textQuaternary, label: "Awake", value: durationLabel(awakeMinutes))
                .frame(maxWidth: .infinity, alignment: .leading)
            LegendItem(swatch: PulseTheme.textTertiary, label: "Core", value: durationLabel(coreMinutes))
                .frame(maxWidth: .infinity, alignment: .leading)
            LegendItem(swatch: PulseTheme.textSecondary, label: "REM", value: durationLabel(remMinutes))
                .frame(maxWidth: .infinity, alignment: .leading)
            LegendItem(swatch: PulseTheme.textPrimary, label: "Deep", value: durationLabel(deepMinutes))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private var timeRangeText: String {
        guard let bedTime, let wakeTime else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: bedTime)) — \(f.string(from: wakeTime))"
    }

    private func durationLabel(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// MARK: - LegendItem

private struct LegendItem: View {
    let swatch: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(swatch)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            Text(value)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(PulseTheme.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview("Sleep — regular night") {
    let cal = Calendar.current
    let bed = cal.date(bySettingHour: 23, minute: 14, second: 0, of: Date())!
    let wake = cal.date(byAdding: .hour, value: 7, to: bed)!.addingTimeInterval(34 * 60)

    return SleepBandCard(
        totalMinutes: 7 * 60 + 34,
        deepMinutes: 82,
        remMinutes: 98,
        coreMinutes: 262,
        awakeMinutes: 12,
        bedTime: bed,
        wakeTime: wake
    )
    .padding()
    .background(PulseTheme.background)
}

#Preview("Sleep — short night") {
    SleepBandCard(
        totalMinutes: 5 * 60 + 20,
        deepMinutes: 50,
        remMinutes: 60,
        coreMinutes: 200,
        awakeMinutes: 10,
        bedTime: Date(),
        wakeTime: Date().addingTimeInterval(5 * 3600)
    )
    .padding()
    .background(PulseTheme.background)
}
