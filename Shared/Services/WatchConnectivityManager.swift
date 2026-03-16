import Foundation
import WatchConnectivity
#if os(watchOS)
import WidgetKit
#endif

/// Syncs health data and gym events between iPhone and Apple Watch
@Observable
final class WatchConnectivityManager: NSObject {

    static let shared = WatchConnectivityManager()

    // MARK: - Received State (consumed by Watch UI)

    var receivedScore: Int?
    var receivedHeadline: String?
    var receivedInsight: String?
    var receivedHeartRate: Int?
    var receivedSteps: Int?

    /// Gym geofence triggered — Watch should show arrival prompt
    var gymArrivalPending = false
    var pendingTrainingGroup: String?
    var pendingTrainingReason: String?

    /// Timestamp of last sync
    var lastSyncDate: Date?

    private var session: WCSession?

    // MARK: - Lifecycle

    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - iPhone → Watch: Health Summary

    func sendHealthSummary(
        score: Int,
        headline: String,
        insight: String,
        heartRate: Int,
        steps: Int
    ) {
        guard let session, session.activationState == .activated else { return }

        let context: [String: Any] = [
            "score": score,
            "headline": headline,
            "insight": insight,
            "heartRate": heartRate,
            "steps": steps,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Application context persists — Watch reads on launch
        try? session.updateApplicationContext(context)

        #if os(iOS)
        // Also update complication if supported
        if session.isComplicationEnabled {
            session.transferCurrentComplicationUserInfo(context)
        }
        #endif
    }

    // MARK: - iPhone → Watch: Gym Arrival

    func sendGymArrival(muscleGroup: String, reason: String) {
        guard let session, session.activationState == .activated else { return }

        let payload: [String: Any] = [
            "type": "gymArrival",
            "group": muscleGroup,
            "reason": reason,
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            // Real-time delivery if Watch is active
            session.sendMessage(payload, replyHandler: nil) { error in
                print("WC sendMessage error: \(error.localizedDescription)")
                // Fall back to queued transfer
                session.transferUserInfo(payload)
            }
        } else {
            // Queue for delivery when Watch wakes
            session.transferUserInfo(payload)
        }
    }

    // MARK: - Watch → iPhone: Workout Events

    func sendWorkoutStarted(category: String) {
        guard let session, session.activationState == .activated else { return }

        let payload: [String: Any] = [
            "type": "workoutStarted",
            "category": category,
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    /// Notify iPhone that a workout has ended so it can sync HealthKit + push to OpenClaw
    func sendWorkoutCompleted(
        category: String,
        durationSeconds: Int,
        activeCalories: Double,
        averageHeartRate: Double,
        maxHeartRate: Double
    ) {
        guard let session, session.activationState == .activated else { return }

        let payload: [String: Any] = [
            "type": "workoutCompleted",
            "category": category,
            "durationSeconds": durationSeconds,
            "activeCalories": activeCalories,
            "averageHeartRate": averageHeartRate,
            "maxHeartRate": maxHeartRate,
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("WC sendWorkoutCompleted error: \(error.localizedDescription)")
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    // MARK: - Dismiss Gym Arrival

    func dismissGymArrival() {
        gymArrivalPending = false
        pendingTrainingGroup = nil
        pendingTrainingReason = nil
    }

    // MARK: - Process Incoming Data

    private func processContext(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let score = data["score"] as? Int { self.receivedScore = score }
            if let headline = data["headline"] as? String { self.receivedHeadline = headline }
            if let insight = data["insight"] as? String { self.receivedInsight = insight }
            if let hr = data["heartRate"] as? Int { self.receivedHeartRate = hr }
            if let steps = data["steps"] as? Int { self.receivedSteps = steps }
            if let ts = data["timestamp"] as? TimeInterval {
                self.lastSyncDate = Date(timeIntervalSince1970: ts)
            }

            // Persist to shared UserDefaults for complication
            #if os(watchOS)
            self.updateComplicationData()
            #endif
        }
    }

    #if os(watchOS)
    private func updateComplicationData() {
        let defaults = UserDefaults(suiteName: "group.com.abundra.pulse.shared")
        if let score = receivedScore {
            defaults?.set(score, forKey: "pulse.score")
        }
        if let headline = receivedHeadline {
            defaults?.set(headline, forKey: "pulse.headline")
        }
        // Reload complication timeline
        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif

    private func processMessage(_ data: [String: Any]) {
        guard let type = data["type"] as? String else {
            // Might be a context update
            processContext(data)
            return
        }

        switch type {
        case "gymArrival":
            DispatchQueue.main.async { [weak self] in
                self?.gymArrivalPending = true
                self?.pendingTrainingGroup = data["group"] as? String
                self?.pendingTrainingReason = data["reason"] as? String
            }
        case "workoutStarted":
            NotificationCenter.default.post(
                name: .watchWorkoutStarted,
                object: nil,
                userInfo: data
            )
        case "workoutCompleted":
            // Trigger iPhone-side sync: HealthKit workout history + OpenClaw push
            NotificationCenter.default.post(
                name: .watchWorkoutCompleted,
                object: nil,
                userInfo: data
            )
        default:
            break
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            print("WC activation error: \(error.localizedDescription)")
            return
        }

        // Load any pending application context
        if !session.receivedApplicationContext.isEmpty {
            processContext(session.receivedApplicationContext)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for Watch switching
        session.activate()
    }
    #endif

    // Application context — persistent key-value sync
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        processContext(applicationContext)
    }

    // Real-time messages
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        processMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        processMessage(message)
        replyHandler(["status": "ok"])
    }

    // Queued user info transfers
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        processMessage(userInfo)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchWorkoutStarted = Notification.Name("pulse.watchWorkoutStarted")
    static let watchWorkoutCompleted = Notification.Name("pulse.watchWorkoutCompleted")
}
