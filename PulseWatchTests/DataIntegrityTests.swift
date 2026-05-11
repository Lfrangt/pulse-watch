import XCTest
@testable import PulseWatch

/// Data integrity tests — ensures no crashes from edge cases
/// Critical for App Store: health data can have extreme or missing values
final class DataIntegrityTests: XCTestCase {

    // MARK: - WorkoutHistoryEntry JSON Properties

    func test_workoutHistoryEntry_heartRateZones_nilData_returnsEmpty() {
        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: UUID().uuidString,
            activityType: 58,
            startDate: .now,
            endDate: .now,
            durationSeconds: 3600
        )
        XCTAssertTrue(entry.heartRateZones.isEmpty,
            "Nil heartRateZonesData should return empty array")
    }

    func test_workoutHistoryEntry_heartRateZones_setAndGet() {
        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: UUID().uuidString,
            activityType: 58,
            startDate: .now,
            endDate: .now,
            durationSeconds: 3600
        )

        let zones = [
            HRZoneEntry(name: "Zone 1", percentage: 0.15, colorHex: "00FF00"),
            HRZoneEntry(name: "Zone 2", percentage: 0.35, colorHex: "FFFF00"),
            HRZoneEntry(name: "Zone 3", percentage: 0.30, colorHex: "FF8800"),
            HRZoneEntry(name: "Zone 4", percentage: 0.15, colorHex: "FF0000"),
            HRZoneEntry(name: "Zone 5", percentage: 0.05, colorHex: "CC00FF"),
        ]
        entry.heartRateZones = zones

        let retrieved = entry.heartRateZones
        XCTAssertEqual(retrieved.count, 5)
        XCTAssertEqual(retrieved[0].name, "Zone 1")
        XCTAssertEqual(retrieved[4].percentage, 0.05, accuracy: 0.001)
    }

    func test_workoutHistoryEntry_muscleGroupTags_nilData_returnsEmpty() {
        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: UUID().uuidString,
            activityType: 58,
            startDate: .now,
            endDate: .now,
            durationSeconds: 3600
        )
        XCTAssertTrue(entry.muscleGroupTags.isEmpty)
    }

    func test_workoutHistoryEntry_muscleGroupTags_setAndGet() {
        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: UUID().uuidString,
            activityType: 58,
            startDate: .now,
            endDate: .now,
            durationSeconds: 3600
        )

        entry.muscleGroupTags = [.chest, .arms]
        let tags = entry.muscleGroupTags
        XCTAssertEqual(tags.count, 2)
        XCTAssertTrue(tags.contains(.chest))
        XCTAssertTrue(tags.contains(.arms))
    }

    func test_workoutHistoryEntry_muscleGroupTags_invalidJSON_returnsEmpty() {
        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: UUID().uuidString,
            activityType: 58,
            startDate: .now,
            endDate: .now,
            durationSeconds: 3600
        )
        entry.muscleGroupTagsRaw = "not json"
        XCTAssertTrue(entry.muscleGroupTags.isEmpty,
            "Invalid JSON should return empty, not crash")
    }

    func test_workoutHistoryEntry_muscleGroupTags_unknownValues_filtered() {
        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: UUID().uuidString,
            activityType: 58,
            startDate: .now,
            endDate: .now,
            durationSeconds: 3600
        )
        // Set raw JSON with an unknown muscle group
        entry.muscleGroupTagsRaw = "[\"chest\",\"unknown_group\",\"legs\"]"
        let tags = entry.muscleGroupTags
        XCTAssertEqual(tags.count, 2, "Unknown muscle groups should be filtered out via compactMap")
        XCTAssertTrue(tags.contains(.chest))
        XCTAssertTrue(tags.contains(.legs))
    }

    func test_workoutHistoryEntry_durationMinutes() {
        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: UUID().uuidString,
            activityType: 37,
            startDate: .now,
            endDate: .now,
            durationSeconds: 5400 // 90 min
        )
        XCTAssertEqual(entry.durationMinutes, 90)
    }

    func test_workoutHistoryEntry_durationMinutes_truncatesSeconds() {
        let entry = WorkoutHistoryEntry(
            hkWorkoutUUID: UUID().uuidString,
            activityType: 37,
            startDate: .now,
            endDate: .now,
            durationSeconds: 3661 // 61.01 min
        )
        XCTAssertEqual(entry.durationMinutes, 61, "Should truncate, not round")
    }

    // MARK: - HealthRecord Tests

    func test_healthRecord_metricTypeRoundTrip() {
        for metricType in HealthMetricType.allCases {
            let record = HealthRecord(
                metricType: metricType,
                value: 42.0,
                timestamp: .now,
                source: "TestSource"
            )
            XCTAssertEqual(record.metric, metricType,
                "\(metricType.rawValue) should round-trip via metricType string")
        }
    }

    func test_healthRecord_unknownMetricType_returnsNil() {
        let record = HealthRecord(
            metricType: .heartRate,
            value: 72,
            timestamp: .now
        )
        record.metricType = "unknown_metric_type"
        XCTAssertNil(record.metric,
            "Unknown metric type string should return nil, not crash")
    }

    // MARK: - HeartRateAlertEvent Tests

    func test_heartRateAlertEvent_initialization() {
        let event = HeartRateAlertEvent(
            heartRate: 145,
            alertType: "high",
            threshold: 120
        )
        XCTAssertEqual(event.heartRate, 145)
        XCTAssertEqual(event.alertType, "high")
        XCTAssertEqual(event.threshold, 120)
    }

    // MARK: - Score Engine Stress Tests

    func test_scoreEngine_massiveValues_doesNotCrash() {
        let extremeValues: [(Double?, Double?, Double?, Int)] = [
            (Double.infinity, nil, nil, 0),
            (nil, Double.infinity, nil, 0),
            (nil, nil, Double.infinity, 0),
            (-1000, -1000, -1000, -999),
            (0, 0, 0, 0),
            (999999, 999999, 999999, 999999),
        ]

        for (hrv, rhr, spo2, sleep) in extremeValues {
            let score = ScoreEngine.calculateScore(
                hrv: hrv, restingHR: rhr, bloodOxygen: spo2, sleepMinutes: sleep
            )
            XCTAssertGreaterThanOrEqual(score, 0, "Score should be >= 0 for inputs (\(String(describing: hrv)),\(String(describing: rhr)),\(String(describing: spo2)),\(sleep))")
            XCTAssertLessThanOrEqual(score, 100, "Score should be <= 100 for inputs (\(String(describing: hrv)),\(String(describing: rhr)),\(String(describing: spo2)),\(sleep))")
        }
    }

    // MARK: - HealthAnomaly Message Tests

    func test_healthAnomaly_allCasesHaveMessages() {
        let anomalies: [HealthAnomaly] = [
            .hrvDrop(current: 25, baseline: 50),
            .elevatedRestingHR(current: 80, baseline: 60),
            .poorSleepStreak(nights: 3)
        ]
        for anomaly in anomalies {
            XCTAssertFalse(anomaly.message.isEmpty,
                "HealthAnomaly should have non-empty message")
        }
    }
}
