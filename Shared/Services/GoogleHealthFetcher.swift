//
//  GoogleHealthFetcher.swift
//  Pulse
//
//  v1.0 Phase 6b — Google Fit REST API data fetching layer.
//
//  iOS-only: mirrors the GoogleHealthAuth.swift os(iOS) guard.
//  All network calls use URLSession — no third-party dependencies.
//

import Foundation
import os

#if os(iOS)

// MARK: - GoogleHealthSnapshot

/// A point-in-time snapshot of health metrics fetched from the Google Fit REST API.
struct GoogleHealthSnapshot {
    let fetchedAt: Date
    let heartRate: Double?        // bpm average
    let restingHeartRate: Double? // min bpm today (proxy for resting)
    let sleepMinutes: Int?        // total sleep segment duration (min)
    let bloodOxygen: Double?      // SpO2 average %
    let steps: Int?               // step count sum
    let activeCalories: Double?   // kcal expended

    /// Bridge to the HealthDataService LatestVitals shape used across the app.
    var asLatestVitals: LatestVitals {
        LatestVitals(
            heartRate: heartRate,
            hrv: nil,                    // Google Fit does not expose HRV via REST
            restingHeartRate: restingHeartRate,
            bloodOxygen: bloodOxygen,
            steps: steps,
            activeCalories: activeCalories,
            lastUpdated: fetchedAt
        )
    }
}

// MARK: - GoogleHealthFetchError

enum GoogleHealthFetchError: LocalizedError {
    case notConnected
    case httpError(Int, String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return String(localized: "Google Health not connected")
        case .httpError(let code, let body):
            return String(format: String(localized: "Google Fit API error %d: %@"), code, body)
        case .decodingFailed(let detail):
            return String(format: String(localized: "Google Fit response decoding failed: %@"), detail)
        }
    }
}

// MARK: - GoogleHealthFetcher

/// Fetches today's health aggregates from the Google Fit REST API.
/// Uses `GoogleHealthAuth.shared.currentAccessToken()` for bearer auth.
final class GoogleHealthFetcher {

    static let shared = GoogleHealthFetcher()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "GoogleHealthFetcher")
    private let aggregateURL = URL(string: "https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate")!

    private init() {}

    // MARK: - Public

    /// Fetches today's (midnight → now) health snapshot from Google Fit.
    /// Throws `GoogleHealthFetchError.notConnected` if the user has not authorised.
    func fetchTodaySnapshot() async throws -> GoogleHealthSnapshot {
        let accessToken: String
        do {
            accessToken = try await GoogleHealthAuth.shared.currentAccessToken()
        } catch {
            throw GoogleHealthFetchError.notConnected
        }

        let (startMillis, endMillis) = todayMillisRange()
        let body = buildRequestBody(startMillis: startMillis, endMillis: endMillis)

        var request = URLRequest(url: aggregateURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GoogleHealthFetchError.httpError(0, "invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            logger.error("Google Fit aggregate request failed: HTTP \(http.statusCode): \(bodyText)")
            throw GoogleHealthFetchError.httpError(http.statusCode, bodyText)
        }

        return try parseSnapshot(from: data)
    }

    // MARK: - Request builder

    private func buildRequestBody(startMillis: Int64, endMillis: Int64) -> [String: Any] {
        [
            "aggregateBy": [
                ["dataTypeName": "com.google.heart_rate.bpm"],
                ["dataTypeName": "com.google.heart_rate.summary"],
                ["dataTypeName": "com.google.step_count.delta"],
                ["dataTypeName": "com.google.calories.expended"],
                ["dataTypeName": "com.google.sleep.segment"],
                ["dataTypeName": "com.google.oxygen_saturation"],
            ],
            "bucketByTime": ["durationMillis": 86_400_000],
            "startTimeMillis": startMillis,
            "endTimeMillis": endMillis,
        ]
    }

    // MARK: - Time helpers

    private func todayMillisRange() -> (Int64, Int64) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now)
        let startMillis = Int64(midnight.timeIntervalSince1970 * 1000)
        let endMillis   = Int64(now.timeIntervalSince1970 * 1000)
        return (startMillis, endMillis)
    }

    // MARK: - Response parser

    /// Google Fit aggregate response shape:
    /// { "bucket": [ { "dataset": [ { "dataSourceId": "...", "point": [ { "value": [...] } ] } ] } ] }
    private func parseSnapshot(from data: Data) throws -> GoogleHealthSnapshot {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let buckets = json["bucket"] as? [[String: Any]]
        else {
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
            throw GoogleHealthFetchError.decodingFailed("unexpected root structure: \(preview)")
        }

        // Collect all datasets across all buckets (today = single bucket, but be defensive)
        var allDatasets: [[String: Any]] = []
        for bucket in buckets {
            if let datasets = bucket["dataset"] as? [[String: Any]] {
                allDatasets.append(contentsOf: datasets)
            }
        }

        var heartRateValues: [Double] = []
        var heartRateMinValues: [Double] = []  // from heart_rate.summary min field
        var stepSum: Int = 0
        var caloriesSum: Double = 0
        var sleepMinutes: Int = 0
        var oxygenValues: [Double] = []

        for dataset in allDatasets {
            guard
                let dataSourceId = dataset["dataSourceId"] as? String,
                let points = dataset["point"] as? [[String: Any]]
            else { continue }

            for point in points {
                guard let values = point["value"] as? [[String: Any]] else { continue }

                if dataSourceId.contains("heart_rate.bpm") {
                    // fpVal = average bpm
                    if let fpVal = values.first?["fpVal"] as? Double {
                        heartRateValues.append(fpVal)
                    }
                } else if dataSourceId.contains("heart_rate.summary") {
                    // heart_rate.summary: [average, max, min] — index 2 = min
                    if values.count >= 3, let minVal = values[2]["fpVal"] as? Double {
                        heartRateMinValues.append(minVal)
                    }
                } else if dataSourceId.contains("step_count.delta") {
                    if let intVal = values.first?["intVal"] as? Int {
                        stepSum += intVal
                    }
                } else if dataSourceId.contains("calories.expended") {
                    if let fpVal = values.first?["fpVal"] as? Double {
                        caloriesSum += fpVal
                    }
                } else if dataSourceId.contains("sleep.segment") {
                    // Each point spans startTimeNanos → endTimeNanos — convert to minutes
                    if let startNanos = point["startTimeNanos"] as? String,
                       let endNanos = point["endTimeNanos"] as? String,
                       let start = Double(startNanos),
                       let end = Double(endNanos) {
                        let durationSeconds = (end - start) / 1_000_000_000
                        sleepMinutes += Int(durationSeconds / 60)
                    }
                } else if dataSourceId.contains("oxygen_saturation") {
                    if let fpVal = values.first?["fpVal"] as? Double {
                        oxygenValues.append(fpVal)
                    }
                }
            }
        }

        let avgHeartRate: Double? = heartRateValues.isEmpty
            ? nil
            : heartRateValues.reduce(0, +) / Double(heartRateValues.count)

        let minHeartRate: Double? = heartRateMinValues.isEmpty
            ? nil
            : heartRateMinValues.min()

        let avgOxygen: Double? = oxygenValues.isEmpty
            ? nil
            : oxygenValues.reduce(0, +) / Double(oxygenValues.count)

        return GoogleHealthSnapshot(
            fetchedAt: Date(),
            heartRate: avgHeartRate,
            restingHeartRate: minHeartRate,
            sleepMinutes: sleepMinutes > 0 ? sleepMinutes : nil,
            bloodOxygen: avgOxygen,
            steps: stepSum > 0 ? stepSum : nil,
            activeCalories: caloriesSum > 0 ? caloriesSum : nil
        )
    }
}

// MARK: - GoogleHealthService

/// @Observable wrapper around GoogleHealthFetcher — mirrors HealthDataService pattern.
/// Call `GoogleHealthService.shared.refresh()` to update `snapshot`.
@MainActor
@Observable
final class GoogleHealthService {

    static let shared = GoogleHealthService()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "GoogleHealthService")

    /// Latest fetched snapshot. nil when disconnected or before first fetch.
    var snapshot: GoogleHealthSnapshot?

    /// True when Google Health OAuth is authorised.
    var isAvailable: Bool {
        GoogleHealthAuth.shared.connectionState == .connected
    }

    private(set) var isRefreshing = false

    private init() {}

    /// Fetches a fresh snapshot and updates `snapshot`.
    /// Silently swallows `.notConnected` — other errors are logged but not rethrown.
    func refresh() async {
        guard isAvailable else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            snapshot = try await GoogleHealthFetcher.shared.fetchTodaySnapshot()
            logger.info("Google Health snapshot refreshed at \(Date())")
        } catch GoogleHealthFetchError.notConnected {
            // OAuth lapsed — not an error worth logging as error
            logger.debug("Google Health refresh skipped: not connected")
        } catch {
            logger.error("Google Health refresh failed: \(error.localizedDescription)")
        }
    }
}

#endif
