import SwiftUI
import os

/// Watch summary view — Clinical Result-style breakdown of today's data.
/// Layout per WatchApp.jsx WatchResult: eyebrow + title, hairline-bordered
/// 2x2 metric grid, full-width primary CTA at the bottom.
struct SummaryView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "SummaryView")

    @State private var healthManager = HealthKitManager.shared
    @State private var connectivity = WatchConnectivityManager.shared

    @State private var score: Int = 0
    @State private var headline: String = String(localized: "Loading...")
    @State private var heartRate: Int = 0
    @State private var hrv: Double = 0
    @State private var sleepMinutes: Int = 0
    @State private var steps: Int = 0
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Eyebrow + hero score
                eyebrowHeader
                    .padding(.top, 2)

                hero
                    .padding(.top, 8)

                // 2x2 metric grid in hairline rule
                metricsGrid
                    .padding(.top, 14)
                    .overlay(alignment: .top) {
                        Rectangle().fill(PulseTheme.border).frame(height: PulseTheme.hairline)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(PulseTheme.border).frame(height: PulseTheme.hairline)
                    }
                    .padding(.bottom, 12)

                Spacer(minLength: 12)

                // Trends CTA (inverted full-width)
                NavigationLink {
                    WatchHomeView()
                } label: {
                    Text("View Trends")
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
                .padding(.top, 6)
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(PulseTheme.background, for: .navigation)
        .navigationTitle("Summary")
        .onAppear {
            loadData()
            withAnimation(.easeOut(duration: 0.35)) {
                appeared = true
            }
        }
    }

    // MARK: - Eyebrow + hero

    private var eyebrowHeader: some View {
        Text("Today")
            .font(.system(size: 9, weight: .semibold))
            .tracking(2.0)
            .textCase(.uppercase)
            .foregroundStyle(PulseTheme.textTertiary)
    }

    private var hero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(score)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .kerning(-1.2)
                .foregroundStyle(PulseTheme.textPrimary)
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 2) {
                Text("Readiness")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(PulseTheme.textTertiary)
                Text(headline)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            Spacer()
        }
    }

    // MARK: - Metrics grid (2x2)

    private var metricsGrid: some View {
        let items: [(String, String)] = [
            ("HR",    heartRate > 0 ? "\(heartRate)" : "--"),
            ("HRV",   hrv > 0 ? "\(Int(hrv))" : "--"),
            ("SLEEP", sleepMinutes > 0 ? formatSleep(sleepMinutes) : "--"),
            ("STEPS", formatSteps(steps)),
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
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Data load

    private func loadData() {
        if let wcScore = connectivity.receivedScore {
            score = wcScore
            headline = connectivity.receivedHeadline ?? PulseTheme.statusLabel(for: wcScore)
            heartRate = connectivity.receivedHeartRate ?? 0
            steps = connectivity.receivedSteps ?? 0
        }

        Task {
            do {
                try await healthManager.requestAuthorization()
                await healthManager.refreshAll()

                let localScore = healthManager.calculateDailyScore()
                if connectivity.receivedScore == nil {
                    score = localScore
                    headline = PulseTheme.statusLabel(for: localScore)
                }

                heartRate = Int(healthManager.latestHeartRate ?? 0)
                hrv = healthManager.latestHRV ?? 0
                sleepMinutes = healthManager.lastNightSleepMinutes
                steps = healthManager.todaySteps

                HapticManager.scoreRefreshed()

                if (connectivity.receivedScore ?? localScore) < 30 {
                    HapticManager.alertTriggered()
                }
            } catch {
                logger.error("SummaryView HealthKit error: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        PulseTheme.statusColor(for: score)
    }

    private func formatSleep(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return "\(h)h\(m)m"
    }

    private func formatSteps(_ steps: Int) -> String {
        guard steps > 0 else { return "--" }
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }
}

#Preview {
    NavigationStack {
        SummaryView()
    }
}
