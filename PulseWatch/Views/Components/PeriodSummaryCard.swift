import SwiftUI

// MARK: - PeriodSummaryCard
// Mirrors Trends.jsx PeriodSummary exactly: 3-column grid in a single pulseCard(padding: 0)
// with vertical hairline dividers between cells, each cell centered.
//
// Each cell shows:
//   • label eyebrow (10pt, +0.22em tracking, ALL CAPS)
//   • value 24pt rounded semibold tabular
//   • delta 11pt tabular — green when good, textTertiary when "negative-but-good"

struct PeriodSummaryCell {
    let label: String
    /// Pre-formatted display value (e.g. "72", "54", "7.3h", "—").
    let value: String
    /// Pre-formatted delta string (e.g. "+3", "−0.2", "—"). Empty/dash skips coloring.
    let delta: String
    /// True if the delta represents an improvement (or the bigger-is-better axis).
    let isGoodDelta: Bool
}

struct PeriodSummaryCard: View {
    let cells: [PeriodSummaryCell]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { idx, cell in
                cellView(cell)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        if idx > 0 {
                            Rectangle()
                                .fill(PulseTheme.divider)
                                .frame(width: PulseTheme.hairline)
                        }
                    }
            }
        }
        .pulseCard(padding: 0)
    }

    private func cellView(_ cell: PeriodSummaryCell) -> some View {
        VStack(spacing: 8) {
            Text(cell.label)
                .pulseEyebrow()

            Text(cell.value)
                .font(.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(PulseTheme.textPrimary)

            Text(cell.delta.isEmpty ? " " : cell.delta)
                .font(.system(size: 11, weight: .regular).monospacedDigit())
                .foregroundStyle(deltaColor(for: cell))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
    }

    private func deltaColor(for cell: PeriodSummaryCell) -> Color {
        guard !cell.delta.isEmpty, cell.delta != "—" else { return PulseTheme.textTertiary }
        return cell.isGoodDelta ? PulseTheme.statusGood : PulseTheme.textTertiary
    }
}

// MARK: - Preview

#Preview("Standard 3-up") {
    PeriodSummaryCard(cells: [
        PeriodSummaryCell(label: "Avg score", value: "72", delta: "+3", isGoodDelta: true),
        PeriodSummaryCell(label: "Avg HRV", value: "54", delta: "+6", isGoodDelta: true),
        PeriodSummaryCell(label: "Avg sleep", value: "7.3h", delta: "−0.2", isGoodDelta: false)
    ])
    .padding()
    .background(PulseTheme.background)
}

#Preview("Empty") {
    PeriodSummaryCard(cells: [
        PeriodSummaryCell(label: "Avg score", value: "—", delta: "", isGoodDelta: true),
        PeriodSummaryCell(label: "Avg HRV", value: "—", delta: "", isGoodDelta: true),
        PeriodSummaryCell(label: "Avg sleep", value: "—", delta: "", isGoodDelta: true)
    ])
    .padding()
    .background(PulseTheme.background)
}
