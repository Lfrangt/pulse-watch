import XCTest
@testable import PulseWatch

/// Tests for SwiftData models — data integrity is critical for health apps
/// App Store rejection risk: corrupted data, crashes on nil, encoding failures
final class ModelTests: XCTestCase {

    // MARK: - ExerciseEntry & SetEntry Codable Tests

    func test_exerciseEntry_totalVolume_calculatesCorrectly() {
        let entry = ExerciseEntry(
            name: "Bench Press",
            sets: [
                SetEntry(weight: 80, reps: 10),
                SetEntry(weight: 80, reps: 8),
                SetEntry(weight: 85, reps: 6)
            ]
        )
        // 80*10 + 80*8 + 85*6 = 800 + 640 + 510 = 1950
        XCTAssertEqual(entry.totalVolume, 1950.0)
    }

    func test_exerciseEntry_emptysets_zeroVolume() {
        let entry = ExerciseEntry(name: "Bench Press", sets: [])
        XCTAssertEqual(entry.totalVolume, 0.0)
    }

    func test_exerciseEntry_codableRoundTrip() throws {
        let entry = ExerciseEntry(
            name: "Squat",
            sets: [
                SetEntry(weight: 100, reps: 5, isWarmup: false),
                SetEntry(weight: 60, reps: 10, isWarmup: true)
            ]
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ExerciseEntry.self, from: data)

        XCTAssertEqual(decoded.name, entry.name)
        XCTAssertEqual(decoded.sets.count, 2)
        XCTAssertEqual(decoded.sets[0].weight, 100)
        XCTAssertEqual(decoded.sets[1].isWarmup, true)
        XCTAssertEqual(decoded.totalVolume, entry.totalVolume)
    }

    func test_setEntry_codableRoundTrip() throws {
        let set = SetEntry(weight: 120.5, reps: 3, isWarmup: false)
        let data = try JSONEncoder().encode(set)
        let decoded = try JSONDecoder().decode(SetEntry.self, from: data)

        XCTAssertEqual(decoded.weight, 120.5)
        XCTAssertEqual(decoded.reps, 3)
        XCTAssertEqual(decoded.isWarmup, false)
    }

    // MARK: - HRZoneEntry Codable Tests

    func test_hrZoneEntry_codableRoundTrip() throws {
        let zones = [
            HRZoneEntry(name: "Zone 1", percentage: 0.2, colorHex: "00FF00"),
            HRZoneEntry(name: "Zone 2", percentage: 0.3, colorHex: "FFFF00"),
            HRZoneEntry(name: "Zone 3", percentage: 0.35, colorHex: "FF8800"),
            HRZoneEntry(name: "Zone 4", percentage: 0.1, colorHex: "FF0000"),
            HRZoneEntry(name: "Zone 5", percentage: 0.05, colorHex: "FF00FF"),
        ]
        let data = try JSONEncoder().encode(zones)
        let decoded = try JSONDecoder().decode([HRZoneEntry].self, from: data)

        XCTAssertEqual(decoded.count, 5)
        XCTAssertEqual(decoded[0].name, "Zone 1")
        XCTAssertEqual(decoded[2].percentage, 0.35, accuracy: 0.001)
    }

    // MARK: - WorkoutActivityHelper Tests

    func test_workoutActivityHelper_knownTypes_returnCorrectNames() {
        XCTAssertEqual(WorkoutActivityHelper.name(for: 37), String(localized: "Running"))
        XCTAssertEqual(WorkoutActivityHelper.name(for: 58), String(localized: "Strength Training"))
        XCTAssertEqual(WorkoutActivityHelper.name(for: 52), String(localized: "Walking"))
        XCTAssertEqual(WorkoutActivityHelper.name(for: 63), String(localized: "HIIT"))
    }

    func test_workoutActivityHelper_unknownType_returnsExercise() {
        XCTAssertEqual(WorkoutActivityHelper.name(for: 9999), String(localized: "Exercise"))
    }

    func test_workoutActivityHelper_icon_returnsSFSymbol() {
        let icon = WorkoutActivityHelper.icon(for: 37)
        XCTAssertEqual(icon, "figure.run")

        let unknownIcon = WorkoutActivityHelper.icon(for: 9999)
        XCTAssertEqual(unknownIcon, "figure.mixed.cardio")
    }

    func test_workoutActivityHelper_colorHex_isValidHex() {
        let knownTypes = [37, 13, 46, 52, 24, 50, 20, 58, 63, 14, 35, 44, 4, 43, 47, 48, 2, 72]

        for type in knownTypes {
            let hex = WorkoutActivityHelper.colorHex(for: type)
            XCTAssertEqual(hex.count, 6, "Color hex for type \(type) should be 6 chars")
            XCTAssertTrue(hex.allSatisfy { $0.isHexDigit },
                "Color hex '\(hex)' for type \(type) should be valid hex")
        }
    }

    // MARK: - HealthMetricType Tests

    func test_healthMetricType_allCasesHaveDisplayNames() {
        for metric in HealthMetricType.allCases {
            XCTAssertFalse(metric.displayName.isEmpty,
                "Metric \(metric.rawValue) should have a display name")
        }
    }

    func test_healthMetricType_allCasesHaveUnits() {
        for metric in HealthMetricType.allCases {
            XCTAssertFalse(metric.unit.isEmpty,
                "Metric \(metric.rawValue) should have a unit")
        }
    }

    func test_healthMetricType_rawValueRoundTrip() {
        for metric in HealthMetricType.allCases {
            let raw = metric.rawValue
            let decoded = HealthMetricType(rawValue: raw)
            XCTAssertEqual(decoded, metric, "Round-trip failed for \(metric)")
        }
    }

    // MARK: - MuscleGroup Tests

    func test_muscleGroup_allCasesHaveLabels() {
        for group in MuscleGroup.allCases {
            XCTAssertFalse(group.label.isEmpty,
                "\(group.rawValue) should have a label")
        }
    }

    func test_muscleGroup_allCasesHaveEmojis() {
        for group in MuscleGroup.allCases {
            XCTAssertFalse(group.emoji.isEmpty,
                "\(group.rawValue) should have an emoji")
        }
    }

    func test_muscleGroup_codableRoundTrip() throws {
        for group in MuscleGroup.allCases {
            let data = try JSONEncoder().encode(group)
            let decoded = try JSONDecoder().decode(MuscleGroup.self, from: data)
            XCTAssertEqual(decoded, group)
        }
    }

    func test_muscleGroup_rawValueRoundTrip() {
        for group in MuscleGroup.allCases {
            let raw = group.rawValue
            let decoded = MuscleGroup(rawValue: raw)
            XCTAssertEqual(decoded, group)
        }
    }

    // MARK: - GoalMetricType Tests

    func test_goalMetricType_allHaveLabelsAndUnits() {
        for goal in GoalMetricType.allCases {
            XCTAssertFalse(goal.label.isEmpty, "\(goal.rawValue) missing label")
            XCTAssertFalse(goal.unit.isEmpty, "\(goal.rawValue) missing unit")
            XCTAssertFalse(goal.icon.isEmpty, "\(goal.rawValue) missing icon")
        }
    }

    func test_goalMetricType_defaultTargets_withinRange() {
        for goal in GoalMetricType.allCases {
            XCTAssertTrue(goal.range.contains(goal.defaultTarget),
                "\(goal.rawValue) defaultTarget \(goal.defaultTarget) not in range \(goal.range)")
        }
    }

    func test_goalMetricType_stepIsPositive() {
        for goal in GoalMetricType.allCases {
            XCTAssertGreaterThan(goal.step, 0,
                "\(goal.rawValue) step must be positive")
        }
    }

    func test_goalMetricType_workoutCount_isWeekly() {
        XCTAssertEqual(GoalMetricType.workoutCount.defaultPeriod, "weekly")
        XCTAssertEqual(GoalMetricType.steps.defaultPeriod, "daily")
        XCTAssertEqual(GoalMetricType.sleepHours.defaultPeriod, "daily")
        XCTAssertEqual(GoalMetricType.dailyScore.defaultPeriod, "daily")
    }

    // MARK: - ChallengeType Tests

    func test_challengeType_allHaveValidDefaults() {
        for challenge in ChallengeType.allCases {
            XCTAssertGreaterThan(challenge.defaultTarget, 0)
            XCTAssertEqual(challenge.defaultDuration, 30)
            XCTAssertFalse(challenge.label.isEmpty)
            XCTAssertFalse(challenge.icon.isEmpty)
        }
    }

    // MARK: - TrainingPlan.Intensity Codable Tests

    func test_trainingPlanIntensity_codableRoundTrip() throws {
        let intensities: [TrainingPlan.Intensity] = [.light, .moderate, .heavy]
        for intensity in intensities {
            let data = try JSONEncoder().encode(intensity)
            let decoded = try JSONDecoder().decode(TrainingPlan.Intensity.self, from: data)
            XCTAssertEqual(decoded, intensity)
        }
    }

    // MARK: - StrengthRecord 1RM Estimation

    func test_estimated1RM_singleRep_returnsWeight() {
        let record = StrengthRecord(
            liftType: "squat", weightKg: 150, sets: 1, reps: 1, date: .now
        )
        XCTAssertEqual(record.estimated1RM, 150.0,
            "1 rep at 150kg should estimate 1RM = 150")
    }

    func test_estimated1RM_multipleReps_usesEpleyFormula() {
        let record = StrengthRecord(
            liftType: "bench", weightKg: 100, sets: 3, reps: 10, date: .now
        )
        // Epley: 100 * (1 + 10/30) = 100 * 1.333 = 133.33
        XCTAssertEqual(record.estimated1RM, 100 * (1 + 10.0/30.0), accuracy: 0.01)
    }

    func test_estimated1RM_zeroReps_returnsWeight() {
        let record = StrengthRecord(
            liftType: "deadlift", weightKg: 200, sets: 1, reps: 0, date: .now
        )
        XCTAssertEqual(record.estimated1RM, 200.0,
            "0 reps should return raw weight (guard clause)")
    }

    // MARK: - DailySummary.totalCalories

    func test_dailySummary_totalCalories_activeAndResting() {
        let summary = DailySummary(date: .now)
        summary.activeCalories = 500
        summary.restingCalories = 1800
        XCTAssertEqual(summary.totalCalories, 2300)
    }

    func test_dailySummary_totalCalories_onlyResting() {
        let summary = DailySummary(date: .now)
        summary.activeCalories = nil
        summary.restingCalories = 1800
        XCTAssertEqual(summary.totalCalories, 1800)
    }

    func test_dailySummary_totalCalories_onlyActive() {
        let summary = DailySummary(date: .now)
        summary.activeCalories = 500
        summary.restingCalories = nil
        XCTAssertEqual(summary.totalCalories, 500)
    }

    func test_dailySummary_totalCalories_bothNil() {
        let summary = DailySummary(date: .now)
        summary.activeCalories = nil
        summary.restingCalories = nil
        XCTAssertNil(summary.totalCalories)
    }

    // MARK: - DailySummary dateString Format

    func test_dailySummary_dateString_format() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 3, day: 15)
        let date = calendar.date(from: components)!

        let summary = DailySummary(date: date)
        XCTAssertEqual(summary.dateString, "2026-03-15")
    }

    func test_dailySummary_dateFormatter_consistent() {
        let now = Date()
        let formatted1 = DailySummary.dateFormatter.string(from: now)
        let formatted2 = DailySummary.dateFormatter.string(from: now)
        XCTAssertEqual(formatted1, formatted2, "Shared formatter should be consistent")
    }
}
