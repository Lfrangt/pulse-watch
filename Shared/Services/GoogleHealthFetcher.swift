//
//  GoogleHealthFetcher.swift
//  Pulse
//
//  v1.1 Phase 6b — Google Health API v4 data fetching layer.
//  API: https://health.googleapis.com/v4 (NOT the legacy Google Fit API)
//  Docs: https://developers.google.com/health
//
//  iOS-only: mirrors the GoogleHealthAuth.swift os(iOS) guard.
//  All network calls use URLSession — no third-party dependencies.
//

import Foundation
import os

#if os(iOS)

// MARK: - GoogleHealthSnapshot

/// A point-in-time snapshot of health metrics fetched from the Google Health API v4.
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
            return String(format: String(localized: "Google Health API error %d: %@"), code, body)
        case .decodingFailed(let detail):
            return String(format: String(localized: "Google Health response decoding failed: %@"), detail)
        }
    }
}

// MARK: - GoogleHealthFetcher

/// Fetches today's health data from the Google Health API v4.
/// API base: https://health.googleapis.com/v4 — NOT the legacy Google Fit API.
/// Uses `GoogleHealthAuth.shared.currentAccessToken()` for bearer auth.
final class GoogleHealthFetcher {

    static let shared = GoogleHealthFetcher()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "GoogleHealthFetcher")

    // Google Health API v4 base URL (developers.google.com/health/reference/rest)
    private let apiBase = "https://health.googleapis.com/v4/users/me/dataTypes"

    // Data type names for Google Health API v4
    private enum DataType: String {
        case heartRate        = "heart_rate"
        case stepCount        = "step_count"
        case caloriesExpended = "active_calories"
        case sleep            = "sleep"
        case oxygenSaturation = "oxygen_saturation"
    }

    private init() {}

    // MARK: - Public

    /// Fetches today's (midnight → now) health snapshot from the Google Health API.
    /// Throws `GoogleHealthFetchError.notConnected` if the user has not authorised.
    func fetchTodaySnapshot() async throws -> GoogleHealthSnapshot {
        let accessToken: String
        do {
            accessToken = try await GoogleHealthAuth.shared.currentAccessToken()
        } catch {
            throw GoogleHealthFetchError.notConnected
        }

        let (startTime, endTime) = todayISO8601Range()

        // Fetch each data type in parallel via rollUp endpoint
        async let hrData     = fetchRollUp(.heartRate,        start: startTime, end: endTime, token: accessToken)
        async let stepsData  = fetchRollUp(.stepCount,        start: startTime, end: endTime, token: accessToken)
        async let calData    = fetchRollUp(.caloriesExpended, start: startTime, end: endTime, token: accessToken)
        async let sleepData  = fetchRollUp(.sleep,            start: startTime, end: endTime, token: accessToken)
        async let spo2Data   = fetchRollUp(.oxygenSaturation, start: startTime, end: endTime, token: accessToken)

        let (hr, steps, cal, sleep, spo2) = try await (hrData, stepsData, calData, sleepData, spo2Data)

        return GoogleHealthSnapshot(
            fetchedAt: Date(),
            heartRate: extractNumeric(hr, key: "average"),
            restingHeartRate: extractNumeric(hr, key: "minimum"),
            sleepMinutes: extractSleepMinutes(sleep),
            bloodOxygen: extractNumeric(spo2, key: "average"),
            steps: extractInt(steps, key: "sum"),
            activeCalories: extractNumeric(cal, key: "sum")
        )
    }

    // MARK: - Per-type rollUp fetch

    /// POST /v4/users/me/dataTypes/{type}/dataPoints:rollUp
    /// Returns the raw JSON dict or nil on soft errors (data not available).
    private func fetchRollUp(
        _ type: DataType,
        start: String,
        end: String,
        token: String
    ) async throws -> [String: Any]? {
        let urlString = "\(apiBase)/\(type.rawValue)/dataPoints:rollUp"
        guard let url = URL(string: urlString) else { return nil }

        let body: [String: Any] = [
            "startTime": start,
            "endTime": end,
            "period": "daily",
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GoogleHealthFetchError.httpError(0, "invalid response")
        }

        // 404 = data type not present for this user → return nil (not an error)
        if http.statusCode == 404 { return nil }

        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            logger.error("Google Health \(type.rawValue) rollUp failed: HTTP \(http.statusCode): \(bodyText)")
            throw GoogleHealthFetchError.httpError(http.statusCode, bodyText)
        }

        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    // MARK: - Time helpers

    private func todayISO8601Range() -> (String, String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now)
        return (formatter.string(from: midnight), formatter.string(from: now))
    }

    // MARK: - Response parsers

    /// Extract a numeric value from the rollUp response.
    /// Google Health API v4 rollUp response shape (expected):
    /// { "dataPoints": [ { "value": { "average": 72.4, "minimum": 58, "maximum": 110, "sum": 1234 } } ] }
    private func extractNumeric(_ json: [String: Any]?, key: String) -> Double? {
        guard let json,
              let points = json["dataPoints"] as? [[String: Any]],
              let first = points.first,
              let value = first["value"] as? [String: Any],
              let num = value[key] as? Double
        else { return nil }
        return num
    }

    private func extractInt(_ json: [String: Any]?, key: String) -> Int? {
        guard let num = extractNumeric(json, key: key) else { return nil }
        return Int(num)
    }

    /// Sleep rollUp returns duration in seconds or minutes depending on API version.
    /// Parse "durationSeconds" or fall back to "durationMinutes".
    private func extractSleepMinutes(_ json: [String: Any]?) -> Int? {
        guard let json,
              let points = json["dataPoints"] as? [[String: Any]],
              let first = points.first,
              let value = first["value"] as? [String: Any]
        else { return nil }

        if let secs = value["durationSeconds"] as? Double {
            return Int(secs / 60)
        }
        if let mins = value["durationMinutes"] as? Double {
            return Int(mins)
        }
        // Fallback: use sum in seconds if API returns aggregate in seconds
        if let sum = value["sum"] as? Double {
            return Int(sum / 60)
        }
        return nil
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
