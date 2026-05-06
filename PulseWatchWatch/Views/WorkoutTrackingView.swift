import SwiftUI
import HealthKit

/// Active workout + post-workout summary — Clinical Live + Result screens.
/// Layout per WatchApp.jsx WatchLive: eyebrow type · set, big HR metric,
/// 5-tick zone bar, hairline divider, ELAPSED / KCAL bottom row.
/// Per WatchApp.jsx WatchResult: SESSION COMPLETE eyebrow, title,
/// 2x2 hairline-divided metric grid, full-width Done button.
struct WorkoutTrackingView: View {

    @State private var manager = WorkoutSessionManager.shared
    @State private var appeared = false

    var initialType: WorkoutSessionManager.WorkoutType = .strength
    var onClose: () -> Void = {}

    var body: some View {
        Group {
            switch manager.state {
            case .idle:
                pickerScreen
            case .running, .paused:
                liveScreen
            case .ended:
                summaryScreen
            }
        }
        .containerBackground(PulseTheme.background, for: .navigation)
        .onAppear {
            if manager.state == .idle {
                manager.startWorkout(type: initialType)
            }
            withAnimation(.easeOut(duration: 0.35)) {
                appeared = true
            }
        }
    }

    // MARK: - Picker (only shown if state stays idle)

    private var pickerScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(PulseTheme.textTertiary)
                    .padding(.bottom, 4)

                ForEach(WorkoutSessionManager.WorkoutType.allCases, id: \.label) { type in
                    Button {
                        manager.startWorkout(type: type)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: type.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(PulseTheme.textSecondary)
                                .frame(width: 18)
                            Text(type.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PulseTheme.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(PulseTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PulseTheme.border, lineWidth: PulseTheme.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Live

    private var liveScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Eyebrow row: TYPE · SET / TIMER
                liveTopStrip
                    .padding(.top, 2)

                // Hero HR + zone label
                liveHero
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                // 5-tick zone bar
                zoneTicks
                    .padding(.top, 10)
                    .padding(.horizontal, 2)

                Spacer(minLength: 14)

                // Hairline + ELAPSED / KCAL
                liveBottomStats
                    .padding(.top, 10)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(PulseTheme.border)
                            .frame(height: PulseTheme.hairline)
                    }

                // Controls (pause / stop)
                controlButtons
                    .padding(.top, 10)
            }
            .padding(.horizontal, 4)
        }
    }

    private var liveTopStrip: some View {
        HStack {
            Text(currentTypeLabel)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(PulseTheme.textTertiary)
            Spacer()
            Text(stateLabel)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(PulseTheme.textTertiary)
        }
    }

    private var liveHero: some View {
        VStack(spacing: 2) {
            Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .kerning(-1.4)
                .foregroundStyle(PulseTheme.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.25), value: Int(manager.heartRate))

            Text("BPM · \(manager.currentZone.label.uppercased())")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.0)
                .foregroundStyle(PulseTheme.textTertiary)
        }
    }

    private var zoneTicks: some View {
        HStack(spacing: 3) {
            ForEach(WorkoutSessionManager.HeartRateZone.allCases, id: \.rawValue) { zone in
                let isActive = zone == manager.currentZone
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isActive ? PulseTheme.textPrimary : PulseTheme.border)
                    .frame(height: 4)
            }
        }
    }

    private var liveBottomStats: some View {
        HStack(alignment: .firstTextBaseline) {
            statBlock(label: "ELAPSED", value: manager.formattedDuration, alignment: .leading)
            Spacer()
            statBlock(label: "KCAL", value: manager.formattedCalories, alignment: .trailing)
        }
    }

    private func statBlock(label: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(PulseTheme.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PulseTheme.textPrimary)
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 10) {
            Button {
                manager.togglePause()
            } label: {
                Image(systemName: manager.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PulseTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PulseTheme.border, lineWidth: PulseTheme.hairline)
                    )
            }
            .buttonStyle(.plain)

            Button {
                manager.endWorkout()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PulseTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PulseTheme.textPrimary)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Summary (Result)

    private var summaryScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Eyebrow + title
                Text("Session complete")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(PulseTheme.textTertiary)
                    .padding(.top, 2)

                Text(currentTypeLabel)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .padding(.top, 4)

                // 2x2 grid hemmed by hairline rules top + bottom
                summaryGrid
                    .padding(.top, 12)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(PulseTheme.border)
                            .frame(height: PulseTheme.hairline)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(PulseTheme.border)
                            .frame(height: PulseTheme.hairline)
                    }
                    .padding(.bottom, 12)

                // Zone distribution
                zoneDistribution
                    .padding(.top, 4)

                Spacer(minLength: 14)

                // Done button — full-width inverted
                Button {
                    manager.reset()
                    onClose()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PulseTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(PulseTheme.textPrimary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
            .padding(.horizontal, 4)
        }
    }

    private var summaryGrid: some View {
        let items: [(String, String)] = [
            ("TIME",   manager.formattedDuration),
            ("KCAL",   manager.formattedCalories),
            ("AVG HR", "\(Int(manager.averageHeartRate))"),
            ("MAX",    "\(Int(manager.maxHeartRateRecorded))"),
        ]

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 10
        ) {
            ForEach(items, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(PulseTheme.textTertiary)
                    Text(value)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(PulseTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
    }

    private var zoneDistribution: some View {
        let totalSeconds = max(manager.elapsedSeconds, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Zone time")
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(PulseTheme.textTertiary)

            ForEach(WorkoutSessionManager.HeartRateZone.allCases, id: \.rawValue) { zone in
                let seconds = manager.zoneSeconds[zone] ?? 0
                let pct = Double(seconds) / Double(totalSeconds)

                HStack(spacing: 8) {
                    Text("Z\(zone.rawValue)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(PulseTheme.textSecondary)
                        .frame(width: 16, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(PulseTheme.border)
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(PulseTheme.textPrimary)
                                .frame(width: max(geo.size.width * pct, pct > 0 ? 2 : 0), height: 3)
                        }
                    }
                    .frame(height: 3)

                    Text(formatZoneTime(seconds))
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Helpers

    private var currentTypeLabel: String {
        let type = WorkoutSessionManager.WorkoutType.allCases.first {
            $0.activityType == manager.currentWorkoutType
        } ?? .strength
        return type.label
    }

    private var stateLabel: String {
        // Mirror "SET 3/4" style position with elapsed timer.
        if manager.state == .paused { return "PAUSED" }
        return manager.formattedDuration
    }

    private func formatZoneTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
}

#Preview {
    WorkoutTrackingView()
}
