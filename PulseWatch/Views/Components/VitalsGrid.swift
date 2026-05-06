import SwiftUI

// MARK: - VitalsGrid
// 2×2 grid of vital metrics — HRV / Resting HR / SpO₂ / Steps.
// Mirrors Today.jsx VitalsGrid: hairline 1pt dividers (vertical between L/R, horizontal between rows).
// Uses pulseCard(padding: 0) wrapper, with each cell padded 16pt internally.

struct VitalsGrid: View {
    let hrv: Double?
    let restingHR: Double?
    let spo2: Double?
    let steps: Int?

    // Optional delta strings (e.g. "+4", "−2"). nil = no delta shown.
    var hrvDelta: String? = nil
    var restingHRDelta: String? = nil
    var spo2Delta: String? = nil
    var stepsDelta: String? = nil

    // Whether each delta is "good" (positive) — drives color.
    var hrvGood: Bool = true
    var restingHRGood: Bool = true
    var spo2Good: Bool = false
    var stepsGood: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VitalCell(
                    label: String(localized: "HRV"),
                    value: formatHRV(hrv),
                    unit: "ms",
                    delta: hrvDelta,
                    good: hrvGood,
                    isMissing: hrv == nil
                )
                .frame(maxWidth: .infinity)

                VitalCell(
                    label: String(localized: "Resting HR"),
                    value: formatBPM(restingHR),
                    unit: "bpm",
                    delta: restingHRDelta,
                    good: restingHRGood,
                    isMissing: restingHR == nil
                )
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(PulseTheme.border)
                        .frame(width: PulseTheme.hairline)
                }
            }

            HStack(spacing: 0) {
                VitalCell(
                    label: String(localized: "SpO₂"),
                    value: formatSpO2(spo2),
                    unit: "%",
                    delta: spo2Delta,
                    good: spo2Good,
                    isMissing: spo2 == nil
                )
                .frame(maxWidth: .infinity)

                VitalCell(
                    label: String(localized: "Steps"),
                    value: formatSteps(steps),
                    unit: "",
                    delta: stepsDelta,
                    good: stepsGood,
                    isMissing: steps == nil
                )
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(PulseTheme.border)
                        .frame(width: PulseTheme.hairline)
                }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PulseTheme.border)
                    .frame(height: PulseTheme.hairline)
            }
        }
        .pulseCard(padding: 0)
    }

    // MARK: - Formatters

    private func formatHRV(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "\(Int(v.rounded()))"
    }

    private func formatBPM(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "\(Int(v.rounded()))"
    }

    private func formatSpO2(_ v: Double?) -> String {
        guard let v else { return "—" }
        // HK reports 0.0–1.0 fraction; if value ≤ 1, treat as fraction.
        let pct = v <= 1 ? v * 100 : v
        return "\(Int(pct.rounded()))"
    }

    private func formatSteps(_ v: Int?) -> String {
        guard let v else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

// MARK: - VitalCell

private struct VitalCell: View {
    let label: String
    let value: String
    let unit: String
    let delta: String?
    let good: Bool
    let isMissing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .pulseEyebrow()

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(PulseTheme.metricMFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .opacity(isMissing ? 0.35 : 1)

                if !unit.isEmpty {
                    Text(unit)
                        .font(PulseTheme.unitFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            if let delta, !delta.isEmpty {
                Text(delta)
                    .font(.system(size: 11, weight: .regular, design: .default).monospacedDigit())
                    .foregroundStyle(good ? PulseTheme.statusGood : PulseTheme.textTertiary)
            } else {
                // Reserve space so cells stay equal height even without delta.
                Text(" ")
                    .font(.system(size: 11))
                    .hidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

// MARK: - Preview

#Preview("Vitals — populated") {
    VitalsGrid(
        hrv: 58,
        restingHR: 52,
        spo2: 0.97,
        steps: 6420,
        hrvDelta: "+4",
        restingHRDelta: "−2",
        spo2Delta: nil,
        stepsDelta: "68%",
        hrvGood: true,
        restingHRGood: true,
        spo2Good: false,
        stepsGood: false
    )
    .padding()
    .background(PulseTheme.background)
}

#Preview("Vitals — missing") {
    VitalsGrid(
        hrv: nil,
        restingHR: nil,
        spo2: nil,
        steps: nil
    )
    .padding()
    .background(PulseTheme.background)
}
