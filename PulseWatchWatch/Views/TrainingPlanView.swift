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
                    .padding(.bottom, 10)

                // Recovery context strip (eyebrow + score · advice)
                contextStrip
                    .padding(.bottom, 10)

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
                .padding(.bottom, 6)

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
                    .padding(.top, 10)
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(PulseTheme.background, for: .navigation)
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
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
            Spacer()
            Text(timeShort())
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(PulseTheme.textTertiary)
        }
    }

    // MARK: - Context strip (recovery score + advice)

    private var contextStrip: some View {
        let score = recoveryScore
        return HStack(spacing: 8) {
            Text("Recovery")
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(PulseTheme.textTertiary)

            Text("\(score)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PulseTheme.textPrimary)

            Spacer()

            Text(trainingAdviceLabel)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.statusColor(for: score))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(active ? PulseTheme.background : PulseTheme.textPrimary)
                Text(sub)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(active ? PulseTheme.textSecondary.opacity(0.8) : PulseTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if active {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PulseTheme.background)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(active ? PulseTheme.textPrimary : PulseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(active ? Color.clear : PulseTheme.border, lineWidth: PulseTheme.hairline)
        )
    }

    // MARK: - Progression tip

    private var tipRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Overload")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(PulseTheme.textTertiary)
                Text("Try +2.5kg this week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PulseTheme.textPrimary)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PulseTheme.statusGood)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PulseTheme.border, lineWidth: PulseTheme.hairline)
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
