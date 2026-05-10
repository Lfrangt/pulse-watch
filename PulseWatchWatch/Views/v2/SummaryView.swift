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
                    .padding(.top, DS.Spacing.m)

                hero
                    .padding(.top, DS.Spacing.s)

                // 2x2 metric grid in hairline rule
                metricsGrid
                    .padding(.top, DS.Spacing.card)
                    .overlay(alignment: .top) {
                        Rectangle().fill(DS.Color.line).frame(height: DS.Stroke.hairline)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(DS.Color.line).frame(height: DS.Stroke.hairline)
                    }
                    .padding(.bottom, DS.Spacing.m)

                Spacer(minLength: 12)

                // Trends CTA (inverted full-width)
                NavigationLink {
                    WatchHomeView()
                } label: {
                    Text("View Trends")
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
                .padding(.top, DS.Spacing.xs)
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .containerBackground(DS.Color.bg, for: .navigation)
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
            .font(DS.Typography.monoS.weight(.semibold))
            .tracking(2.0)
            .textCase(.uppercase)
            .foregroundStyle(DS.Color.inkDim)
    }

    private var hero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(score)")
                .font(DS.Typography.watchScore)
                .monospacedDigit()
                .kerning(-1.2)
                .foregroundStyle(DS.Color.ink)
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 2) {
                Text("Readiness")
                    .font(DS.Typography.monoS.weight(.semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(DS.Color.inkDim)
                Text(headline)
                    .font(DS.Typography.caption.weight(.medium))
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
                        .font(DS.Typography.watchLabel.weight(.semibold))
                        .tracking(1.0)
                        .foregroundStyle(DS.Color.inkDim)
                    Text(value)
                        .font(DS.Typography.bodyL.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(DS.Color.ink)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, DS.Spacing.s)
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
