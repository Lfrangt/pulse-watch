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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .containerBackground(DS.Color.bg, for: .navigation)
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
                    .font(DS.Typography.watchLabel.weight(.semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.inkDim)
                    .padding(.bottom, DS.Spacing.xs)

                ForEach(WorkoutSessionManager.WorkoutType.allCases, id: \.label) { type in
                    Button {
                        manager.startWorkout(type: type)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: type.icon)
                                .font(DS.Typography.bodyS.weight(.medium))
                                .foregroundStyle(DS.Color.inkMid)
                                .frame(width: 18)
                            Text(type.label)
                                .font(DS.Typography.caption.weight(.medium))
                                .foregroundStyle(DS.Color.ink)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(DS.Typography.mono.weight(.medium))
                                .foregroundStyle(DS.Color.inkDim)
                        }
                        .padding(.horizontal, DS.Spacing.m)
                        .padding(.vertical, DS.Spacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DS.Color.bgElev)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
    }

    // MARK: - Live

    private var liveScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Eyebrow row: TYPE · SET / TIMER
                liveTopStrip
                    .padding(.top, DS.Spacing.m)

                // Hero HR + zone label
                liveHero
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.Spacing.xs)

                // 5-tick zone bar
                zoneTicks
                    .padding(.top, DS.Spacing.s)
                    .padding(.horizontal, DS.Spacing.m)

                Spacer(minLength: 14)

                // Hairline + ELAPSED / KCAL
                liveBottomStats
                    .padding(.top, DS.Spacing.s)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(DS.Color.line)
                            .frame(height: DS.Stroke.hairline)
                    }

                // Controls (pause / stop)
                controlButtons
                    .padding(.top, DS.Spacing.s)
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
    }

    private var liveTopStrip: some View {
        HStack {
            Text(currentTypeLabel)
                .font(DS.Typography.monoS.weight(.semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(DS.Color.inkDim)
            Spacer()
            Text(stateLabel)
                .font(DS.Typography.monoS)
                .foregroundStyle(DS.Color.inkDim)
        }
    }

    private var liveHero: some View {
        VStack(spacing: 2) {
            Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                .font(DS.Typography.watchScore)
                .monospacedDigit()
                .kerning(-1.4)
                .foregroundStyle(DS.Color.ink)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: Int(manager.heartRate))

            Text("BPM · \(manager.currentZone.label.uppercased())")
                .font(DS.Typography.monoS.weight(.medium))
                .tracking(1.0)
                .foregroundStyle(DS.Color.inkDim)
        }
    }

    private var zoneTicks: some View {
        HStack(spacing: 3) {
            ForEach(WorkoutSessionManager.HeartRateZone.allCases, id: \.rawValue) { zone in
                let isActive = zone == manager.currentZone
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isActive ? DS.Color.ink : DS.Color.line)
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
                .font(DS.Typography.watchLabel.weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(DS.Color.inkDim)
            Text(value)
                .font(DS.Typography.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DS.Color.ink)
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 10) {
            Button {
                manager.togglePause()
            } label: {
                Image(systemName: manager.state == .paused ? "play.fill" : "pause.fill")
                    .font(DS.Typography.bodyS.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DS.Color.bgElev)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
                    )
            }
            .buttonStyle(.plain)

            Button {
                manager.endWorkout()
            } label: {
                Image(systemName: "stop.fill")
                    .font(DS.Typography.bodyS.weight(.semibold))
                    .foregroundStyle(DS.Color.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DS.Color.ink)
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
                    .font(DS.Typography.monoS.weight(.semibold))
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.inkDim)
                    .padding(.top, DS.Spacing.m)

                Text(currentTypeLabel)
                    .font(DS.Typography.bodyL.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)
                    .padding(.top, DS.Spacing.xs)

                // 2x2 grid hemmed by hairline rules top + bottom
                summaryGrid
                    .padding(.top, DS.Spacing.m)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(DS.Color.line)
                            .frame(height: DS.Stroke.hairline)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(DS.Color.line)
                            .frame(height: DS.Stroke.hairline)
                    }
                    .padding(.bottom, DS.Spacing.m)

                // Zone distribution
                zoneDistribution
                    .padding(.top, DS.Spacing.xs)

                Spacer(minLength: 14)

                // Done button — full-width inverted
                Button {
                    manager.reset()
                    onClose()
                } label: {
                    Text("Done")
                        .font(DS.Typography.bodyS.weight(.semibold))
                        .foregroundStyle(DS.Color.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(DS.Color.ink)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, DS.Spacing.card)
            }
            .padding(.horizontal, DS.Spacing.xs)
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
                        .font(DS.Typography.watchLabel.weight(.semibold))
                        .tracking(1.0)
                        .foregroundStyle(DS.Color.inkDim)
                    Text(value)
                        .font(DS.Typography.bodyL.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(DS.Color.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, DS.Spacing.s)
    }

    private var zoneDistribution: some View {
        let totalSeconds = max(manager.elapsedSeconds, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Zone time")
                .font(DS.Typography.watchLabel.weight(.semibold))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(DS.Color.inkDim)

            ForEach(WorkoutSessionManager.HeartRateZone.allCases, id: \.rawValue) { zone in
                let seconds = manager.zoneSeconds[zone] ?? 0
                let pct = Double(seconds) / Double(totalSeconds)

                HStack(spacing: 8) {
                    Text("Z\(zone.rawValue)")
                        .font(DS.Typography.monoS.weight(.medium))
                        .foregroundStyle(DS.Color.inkMid)
                        .frame(width: 16, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DS.Color.line)
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DS.Color.ink)
                                .frame(width: max(geo.size.width * pct, pct > 0 ? 2 : 0), height: 3)
                        }
                    }
                    .frame(height: 3)

                    Text(formatZoneTime(seconds))
                        .font(DS.Typography.monoS)
                        .foregroundStyle(DS.Color.inkDim)
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
