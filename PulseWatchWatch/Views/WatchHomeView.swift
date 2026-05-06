import SwiftUI
import HealthKit
import os

/// Watch face — Clinical Glance.
/// Layout per WatchApp.jsx WatchGlance: date/time eyebrow strip,
/// big readiness metric, hairline-divided bottom triplet (HR / Steps / Sync).
struct WatchHomeView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "WatchHomeView")

    @State private var connectivity = WatchConnectivityManager.shared
    @State private var healthManager = HealthKitManager.shared

    // Local fallback values
    @State private var localScore: Int = 0
    @State private var localHeadline: String = String(localized: "Loading...")
    @State private var localInsight: String = ""
    @State private var localHeartRate: Int = 0
    @State private var localSteps: String = "--"
    @State private var localHRV: Int = 0

    @State private var appeared = false
    @State private var showGymArrival = false
    @State private var showWorkout = false
    @State private var workoutInitialType: WorkoutSessionManager.WorkoutType = .strength

    private var score: Int { connectivity.receivedScore ?? localScore }
    private var headline: String { connectivity.receivedHeadline ?? localHeadline }
    private var insight: String { connectivity.receivedInsight ?? localInsight }
    private var heartRate: Int { connectivity.receivedHeartRate ?? localHeartRate }

    private var stepsDisplay: String {
        if let s = connectivity.receivedSteps {
            return s >= 1000 ? String(format: "%.1fk", Double(s) / 1000) : "\(s)"
        }
        return localSteps
    }

    private var hrvDisplay: String {
        localHRV > 0 ? "\(localHRV)" : "--"
    }

    private var deltaText: String? {
        // "+6 vs avg" style line under the hero number — only show if we have a sync date.
        guard connectivity.lastSyncDate != nil else { return nil }
        return PulseTheme.statusLabel(for: score)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Top mono strip: DAY DD ······ HH:MM
                topStrip
                    .padding(.top, 4)

                // Hero: READINESS eyebrow + big metric + status caption
                hero
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Spacer(minLength: 14)

                // Hairline divider + 3-col bottom triplet
                bottomTriplet
                    .padding(.top, 10)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(PulseTheme.border)
                            .frame(height: PulseTheme.hairline)
                    }

                // Quick action row (Plan / Train) — same hairline-row aesthetic
                actionRow
                    .padding(.top, 10)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(PulseTheme.background, for: .navigation)
        .sheet(isPresented: $showGymArrival) {
            GymArrivalView(
                trainingPlan: buildPendingPlan(),
                onStartWorkout: {
                    HapticManager.workoutStarted()
                    connectivity.sendWorkoutStarted(
                        category: connectivity.pendingTrainingGroup ?? "general"
                    )
                    connectivity.dismissGymArrival()
                    showGymArrival = false
                    workoutInitialType = .strength
                    showWorkout = true
                },
                onDismiss: {
                    HapticManager.tap()
                    connectivity.dismissGymArrival()
                    showGymArrival = false
                }
            )
        }
        .fullScreenCover(isPresented: $showWorkout) {
            WorkoutTrackingView(
                initialType: workoutInitialType,
                onClose: { showWorkout = false }
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                appeared = true
            }
            loadLocalData()
        }
        .onChange(of: connectivity.gymArrivalPending) { _, pending in
            if pending {
                showGymArrival = true
            }
        }
        .onChange(of: connectivity.receivedScore) { _, newScore in
            if let newScore {
                HapticManager.scoreRefreshed()
                if newScore < 30 {
                    HapticManager.alertTriggered()
                }
            }
        }
    }

    // MARK: - Top strip (DATE / TIME)

    private var topStrip: some View {
        HStack {
            Text(weekdayDay())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.textTertiary)
                .tracking(0.5)
            Spacer()
            Text(timeShort())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(PulseTheme.textTertiary)
        }
    }

    // MARK: - Hero (eyebrow + big metric + caption)

    private var hero: some View {
        VStack(spacing: 4) {
            // Eyebrow — 9pt for watch, ALL CAPS, fg-3
            Text("Readiness")
                .font(.system(size: 9, weight: .semibold))
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(PulseTheme.textTertiary)

            // Big metric — 44pt, bold rounded, tabular-nums, status color
            Text("\(score)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .kerning(-1.2)
                .foregroundStyle(PulseTheme.textPrimary)
                .contentTransition(.numericText())

            // Status mini-caption (mono)
            if let delta = deltaText {
                Text(delta)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(statusColor)
            } else {
                Text(headline)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(statusColor)
            }
        }
    }

    // MARK: - Bottom triplet (HRV · HR · STEPS)

    private var bottomTriplet: some View {
        HStack(spacing: 0) {
            metricCell(label: "HRV", value: hrvDisplay)
            metricCell(label: "HR",  value: heartRate > 0 ? "\(heartRate)" : "--")
            metricCell(label: "STEPS", value: stepsDisplay)
        }
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(PulseTheme.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PulseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action row (Plan / Train)

    private var actionRow: some View {
        HStack(spacing: 6) {
            NavigationLink {
                TrainingPlanView()
            } label: {
                actionPill(label: "Plan", systemImage: "calendar")
            }
            .buttonStyle(.plain)

            Button {
                workoutInitialType = .strength
                showWorkout = true
            } label: {
                actionPill(label: "Train", systemImage: "play.fill", inverted: true)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionPill(label: String, systemImage: String, inverted: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(inverted ? PulseTheme.background : PulseTheme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(inverted ? PulseTheme.textPrimary : PulseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(inverted ? Color.clear : PulseTheme.border, lineWidth: PulseTheme.hairline)
        )
    }

    // MARK: - Helpers

    private var statusColor: Color {
        PulseTheme.statusColor(for: score)
    }

    private func weekdayDay() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f.string(from: Date()).uppercased()
    }

    private func timeShort() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    private func loadLocalData() {
        Task {
            do {
                try await healthManager.requestAuthorization()
                await healthManager.refreshAll()

                let score = healthManager.calculateDailyScore()
                localScore = score
                localHeadline = PulseTheme.statusLabel(for: score)
                localInsight = score >= 70 ? String(localized: "Ready to train") : String(localized: "Take it easy")
                localHeartRate = Int(healthManager.latestHeartRate ?? 0)
                localHRV = Int(healthManager.latestHRV ?? 0)

                let steps = healthManager.todaySteps
                localSteps = steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)"

                HapticManager.scoreRefreshed()

                if score < 30 {
                    HapticManager.alertTriggered()
                }
            } catch {
                logger.error("Watch HealthKit error: \(error)")
            }
        }
    }

    private func buildPendingPlan() -> TrainingPlan? {
        guard let group = connectivity.pendingTrainingGroup else { return nil }
        return TrainingPlan(
            targetMuscleGroup: group,
            daysSinceLastTrained: 0,
            suggestedExercises: [],
            intensity: .moderate,
            reason: connectivity.pendingTrainingReason ?? ""
        )
    }
}

#Preview {
    WatchHomeView()
}
