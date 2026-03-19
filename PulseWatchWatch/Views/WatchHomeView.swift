import SwiftUI
import HealthKit

/// Watch face — glance and go. Minimal, warm, alive.
struct WatchHomeView: View {

    @State private var connectivity = WatchConnectivityManager.shared
    @State private var healthManager = HealthKitManager.shared

    // Local fallback values
    @State private var localScore: Int = 0
    @State private var localHeadline: String = String(localized: "Loading...")
    @State private var localInsight: String = ""
    @State private var localHeartRate: Int = 0
    @State private var localSteps: String = "--"

    @State private var appeared = false
    @State private var ringProgress: CGFloat = 0
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

    var body: some View {
            ScrollView {
                VStack(spacing: 10) {
                    // Score ring — the hero
                    scoreRing
                        .padding(.top, 4)

                    // Insight text
                    if !insight.isEmpty {
                        Text(insight)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color(hex: "9A938C"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .opacity(appeared ? 1 : 0)
                    }

                    // Quick metrics
                    HStack(spacing: 14) {
                        WatchMetric(
                            icon: "heart.fill",
                            value: heartRate > 0 ? "\(heartRate)" : "--",
                            color: PulseTheme.activityAccent
                        )
                        WatchMetric(
                            icon: "figure.walk",
                            value: stepsDisplay,
                            color: PulseTheme.statusGood
                        )
                    }
                    .padding(.top, 4)
                    .opacity(appeared ? 1 : 0)

                    // 训练入口
                    HStack(spacing: 10) {
                        NavigationLink {
                            TrainingPlanView()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PulseTheme.accent)
                                Text("Plan")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(PulseTheme.textSecondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(PulseTheme.cardBackground)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            workoutInitialType = .strength
                            showWorkout = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PulseTheme.accent)
                                Text("Train")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(PulseTheme.textSecondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(PulseTheme.cardBackground)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                    .opacity(appeared ? 1 : 0)

                    // Last sync indicator
                    if let syncDate = connectivity.lastSyncDate {
                        Text(syncLabel(syncDate))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color(hex: "3A3530"))
                            .padding(.top, 4)
                    }
                }
            }
            .containerBackground(
                LinearGradient(
                    colors: [Color(hex: "0D0C0B"), Color(hex: "111010")],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                for: .navigation
            )
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
                        // 到达健身房 → 自动打开训练界面
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
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                appeared = true
                ringProgress = CGFloat(score) / 100.0
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
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    ringProgress = CGFloat(newScore) / 100.0
                }
                // 触觉反馈：同步完成
                HapticManager.scoreRefreshed()
                // 异常告警
                if newScore < 30 {
                    HapticManager.alertTriggered()
                }
            }
        }
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(statusColor.opacity(0.08))
                .frame(width: 110, height: 110)
                .blur(radius: 15)

            // Track
            Circle()
                .stroke(Color(hex: "2A2623"), lineWidth: 5)
                .frame(width: 105, height: 105)

            // Progress
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    statusColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 105, height: 105)
                .rotationEffect(.degrees(-90))

            // Score text
            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "F5F0EB"))
                    .contentTransition(.numericText())

                Text(headline)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(statusColor)
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        PulseTheme.statusColor(for: score)
    }

    private func syncLabel(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return String(localized: "Just synced") }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }

    private func loadLocalData() {
        // Try to load data directly on Watch via HealthKit
        Task {
            do {
                try await healthManager.requestAuthorization()
                await healthManager.refreshAll()

                let score = healthManager.calculateDailyScore()
                localScore = score
                localHeadline = PulseTheme.statusLabel(for: score)
                localInsight = score >= 70 ? String(localized: "Ready to train") : String(localized: "Take it easy")
                localHeartRate = Int(healthManager.latestHeartRate ?? 0)

                let steps = healthManager.todaySteps
                localSteps = steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)"

                // Update ring if no WC data
                if connectivity.receivedScore == nil {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                        ringProgress = CGFloat(score) / 100.0
                    }
                }

                // 触觉反馈：数据刷新完成
                HapticManager.scoreRefreshed()

                // 异常告警：评分过低
                if score < 30 {
                    HapticManager.alertTriggered()
                }
            } catch {
                print("Watch HealthKit error: \(error)")
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

// MARK: - Watch Metric Pill

struct WatchMetric: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "F5F0EB"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(hex: "1A1816"))
        )
    }
}

#Preview {
    WatchHomeView()
}
