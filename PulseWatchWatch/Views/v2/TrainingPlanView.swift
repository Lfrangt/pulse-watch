import SwiftUI

/// Training plan / workout-start picker — Clinical Start screen.
/// Layout per WatchApp.jsx WatchStart: title row + scrollable list of options,
/// recommended row inverted (white bg, black ink) with chevron.
struct TrainingPlanView: View {

    @State private var healthManager = HealthKitManager.shared
    @State private var connectivity = WatchConnectivityManager.shared
    @State private var showWorkout = false
    @State private var selectedType: WorkoutSessionManager.WorkoutType = .strength

    /// Push / Pull / Legs rotations (recommendation pool).
    private let rotations: [(group: String, label: String, sub: String)] = [
        ("push", String(localized: "Push · Chest"), String(localized: "Bench · Press · Pushdown")),
        ("pull", String(localized: "Pull · Back"),  String(localized: "Deadlift · Row · Curl")),
        ("legs", String(localized: "Legs"),         String(localized: "Squat · Leg Press · Calf")),
    ]

    /// Cardio options.
    private let cardio: [(label: String, sub: String, type: WorkoutSessionManager.WorkoutType)] = [
        (String(localized: "Outdoor Run"), String(localized: "HR zone 3"), .running),
        (String(localized: "Cycling"),     String(localized: "Indoor"),    .cycling),
        (String(localized: "HIIT"),        String(localized: "Intervals"), .hiit),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Header — title + time mono
                header
                    .padding(.bottom, DS.Spacing.s)

                // Recovery context strip (eyebrow + score · advice)
                contextStrip
                    .padding(.bottom, DS.Spacing.s)

                // Strength rotation list
                listSection {
                    ForEach(rotations, id: \.group) { rotation in
                        let isActive = rotation.group == recommendedRotation.group
                        Button {
                            selectedType = .strength
                            showWorkout = true
                        } label: {
                            optionRow(
                                title: rotation.label,
                                sub: rotation.sub,
                                active: isActive
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, DS.Spacing.xs)

                // Cardio
                listSection {
                    ForEach(cardio, id: \.label) { item in
                        Button {
                            selectedType = item.type
                            showWorkout = true
                        } label: {
                            optionRow(
                                title: item.label,
                                sub: item.sub,
                                active: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Progressive overload tip — minimal hairline card
                tipRow
                    .padding(.top, DS.Spacing.s)
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .containerBackground(DS.Color.bg, for: .navigation)
        .navigationTitle("Workout")
        .sheet(isPresented: $showWorkout) {
            WorkoutTrackingView(
                initialType: selectedType,
                onClose: { showWorkout = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Workout")
                .font(DS.Typography.bodyS.weight(.semibold))
                .foregroundStyle(DS.Color.ink)
            Spacer()
            Text(timeShort())
                .font(DS.Typography.mono)
                .foregroundStyle(DS.Color.inkDim)
        }
    }

    // MARK: - Context strip (recovery score + advice)

    private var contextStrip: some View {
        let score = recoveryScore
        return HStack(spacing: 8) {
            Text("Recovery")
                .font(DS.Typography.watchLabel.weight(.semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(DS.Color.inkDim)

            Text("\(score)")
                .font(DS.Typography.bodyS.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DS.Color.ink)

            Spacer()

            Text(trainingAdviceLabel)
                .font(DS.Typography.mono.weight(.medium))
                .foregroundStyle(PulseTheme.statusColor(for: score))
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.xs)
    }

    // MARK: - Section wrapper (vertical 6pt stack — list per JSX)

    private func listSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6) {
            content()
        }
    }

    // MARK: - Option row (active = inverted)

    private func optionRow(title: String, sub: String, active: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(active ? DS.Color.bg : DS.Color.ink)
                Text(sub)
                    .font(DS.Typography.monoS)
                    .foregroundStyle(active ? DS.Color.inkMid.opacity(0.8) : DS.Color.inkDim)
                    .lineLimit(1)
            }
            Spacer()
            if active {
                Image(systemName: "arrow.right")
                    .font(DS.Typography.mono.weight(.medium))
                    .foregroundStyle(DS.Color.bg)
            }
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(active ? DS.Color.ink : DS.Color.bgElev)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(active ? Color.clear : DS.Color.line, lineWidth: DS.Stroke.hairline)
        )
    }

    // MARK: - Progression tip

    private var tipRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Overload")
                    .font(DS.Typography.watchLabel.weight(.semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.inkDim)
                Text("Try +2.5kg this week")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Color.ink)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(DS.Typography.caption.weight(.medium))
                .foregroundStyle(DS.Color.good)
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
        )
    }

    // MARK: - Computed

    private var recoveryScore: Int {
        connectivity.receivedScore ?? healthManager.calculateDailyScore()
    }

    private var trainingAdviceLabel: String {
        let score = recoveryScore
        switch score {
        case 80...:   return String(localized: "High intensity")
        case 60..<80: return String(localized: "Moderate")
        case 40..<60: return String(localized: "Light")
        default:      return String(localized: "Rest")
        }
    }

    private var recommendedRotation: (group: String, label: String, sub: String) {
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let index = (dayOfWeek - 1) % 3
        return rotations[index]
    }

    private func timeShort() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }
}

#Preview {
    NavigationStack {
        TrainingPlanView()
    }
}
