import Foundation
import Combine

/// Coordinates the gym geofence flow on iPhone:
/// arrive at gym → generate training plan → send to Watch via WatchConnectivity
/// Watch shows haptic + prompt → user taps start → workout begins
final class GymCoordinator {

    static let shared = GymCoordinator()

    private var cancellables = Set<AnyCancellable>()

    /// Last training plan sent to the Watch
    var lastSentPlan: TrainingPlan?

    // MARK: - Lifecycle

    func startListening() {
        #if os(iOS)
        // Listen for geofence entry
        NotificationCenter.default.publisher(for: .didEnterSavedRegion)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleRegionEntry(notification)
            }
            .store(in: &cancellables)

        // Listen for watch workout confirmation
        NotificationCenter.default.publisher(for: .watchWorkoutStarted)
            .receive(on: DispatchQueue.main)
            .sink { notification in
                if let category = notification.userInfo?["category"] as? String {
                    print("[GymCoordinator] Workout started from watch: \(category)")
                }
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Geofence → Training Plan → Watch

    #if os(iOS)
    private func handleRegionEntry(_ notification: Notification) {
        guard notification.userInfo?["regionId"] is String else { return }

        // Generate a training plan based on current health state
        let hm = HealthKitManager.shared
        let brief = ScoreEngine.generateBrief(
            hrv: hm.latestHRV,
            restingHR: hm.latestRestingHR,
            bloodOxygen: hm.latestBloodOxygen,
            sleepMinutes: hm.lastNightSleepMinutes,
            deepSleepMinutes: 0,
            remSleepMinutes: 0,
            steps: hm.todaySteps,
            recentWorkouts: []
        )

        if let plan = brief.trainingPlan {
            lastSentPlan = plan
            WatchConnectivityManager.shared.sendGymArrival(
                muscleGroup: plan.targetMuscleGroup,
                reason: plan.reason
            )
        }

        // Also post for local UI
        NotificationCenter.default.post(
            name: .gymGeofenceTriggered,
            object: nil,
            userInfo: notification.userInfo
        )
    }
    #endif

    // MARK: - Push Health Summary to Watch

    func syncHealthToWatch() {
        #if os(iOS)
        let hm = HealthKitManager.shared
        let score = hm.calculateDailyScore()
        let headline = PulseTheme.statusLabel(for: score)

        let brief = ScoreEngine.generateBrief(
            hrv: hm.latestHRV,
            restingHR: hm.latestRestingHR,
            bloodOxygen: hm.latestBloodOxygen,
            sleepMinutes: hm.lastNightSleepMinutes,
            deepSleepMinutes: 0,
            remSleepMinutes: 0,
            steps: hm.todaySteps,
            recentWorkouts: []
        )

        WatchConnectivityManager.shared.sendHealthSummary(
            score: score,
            headline: headline,
            insight: brief.insight,
            heartRate: Int(hm.latestHeartRate ?? 0),
            steps: hm.todaySteps
        )
        #endif
    }
}

extension Notification.Name {
    static let gymGeofenceTriggered = Notification.Name("pulse.gymGeofenceTriggered")
}
