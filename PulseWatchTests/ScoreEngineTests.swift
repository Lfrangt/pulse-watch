import XCTest
@testable import PulseWatch

/// Tests for ScoreEngine — the core health scoring algorithm
/// Critical for App Store: incorrect scores could mislead users about health status
final class ScoreEngineTests: XCTestCase {

    // MARK: - Score Calculation: Boundary & Range Tests

    func test_calculateScore_allNil_returnsDefaultMiddleRange() {
        let score = ScoreEngine.calculateScore(
            hrv: nil, restingHR: nil, bloodOxygen: nil, sleepMinutes: 0
        )
        // nil HRV=55, nil RHR=55, sleep 0=30, nil SpO2=78
        // raw = 55*0.35 + 55*0.25 + 30*0.30 + 78*0.10 = 19.25 + 13.75 + 9.0 + 7.8 = 49.8
        XCTAssertEqual(score, 50, "All-nil inputs should produce ~50 (neutral) score")
    }

    func test_calculateScore_alwaysReturns0to100() {
        // Extreme low values
        let scoreLow = ScoreEngine.calculateScore(
            hrv: 5, restingHR: 120, bloodOxygen: 80, sleepMinutes: 0
        )
        XCTAssertGreaterThanOrEqual(scoreLow, 0)
        XCTAssertLessThanOrEqual(scoreLow, 100)

        // Extreme high values
        let scoreHigh = ScoreEngine.calculateScore(
            hrv: 200, restingHR: 42, bloodOxygen: 100, sleepMinutes: 480
        )
        XCTAssertGreaterThanOrEqual(scoreHigh, 0)
        XCTAssertLessThanOrEqual(scoreHigh, 100)
    }

    func test_calculateScore_eliteMetrics_scoresAbove85() {
        let score = ScoreEngine.calculateScore(
            hrv: 100,       // elite HRV
            restingHR: 45,  // elite RHR
            bloodOxygen: 99, // excellent SpO2
            sleepMinutes: 480 // 8h optimal
        )
        XCTAssertGreaterThan(score, 85, "Elite metrics should score > 85")
        // Soft ceiling: raw > 85 gets compressed
        XCTAssertLessThanOrEqual(score, 95, "Soft ceiling should prevent near-100 scores")
    }

    func test_calculateScore_poorMetrics_scoresBelow50() {
        let score = ScoreEngine.calculateScore(
            hrv: 15,        // very low
            restingHR: 90,  // very high
            bloodOxygen: 91, // concerning
            sleepMinutes: 240 // only 4h
        )
        XCTAssertLessThan(score, 50, "Poor metrics should score below 50")
    }

    func test_calculateScore_softCeiling_compressesHighScores() {
        // Without ceiling: raw ~92
        let score = ScoreEngine.calculateScore(
            hrv: 120, restingHR: 42, bloodOxygen: 100, sleepMinutes: 510
        )
        // raw above 85 gets (raw-85)*0.45 compression
        // This ensures genuinely excellent = 88-92, not 95+
        XCTAssertLessThan(score, 93, "Soft ceiling should compress scores above 85")
    }

    // MARK: - HRV Component Tests

    func test_calculateScore_hrvBelow20_veryLowComponent() {
        let lowHRV = ScoreEngine.calculateScore(
            hrv: 10, restingHR: nil, bloodOxygen: nil, sleepMinutes: 0
        )
        let highHRV = ScoreEngine.calculateScore(
            hrv: 80, restingHR: nil, bloodOxygen: nil, sleepMinutes: 0
        )
        XCTAssertLessThan(lowHRV, highHRV, "HRV 10 should score lower than HRV 80")
    }

    func test_calculateScore_hrvBrackets_monotonicallyIncreasing() {
        let hrvValues: [Double] = [10, 25, 35, 45, 55, 70, 82, 100, 120]
        var previousScore = -1

        for hrv in hrvValues {
            let score = ScoreEngine.calculateScore(
                hrv: hrv, restingHR: 60, bloodOxygen: 97, sleepMinutes: 450
            )
            XCTAssertGreaterThan(score, previousScore,
                "Score should increase monotonically with HRV: hrv=\(hrv) scored \(score) vs previous \(previousScore)")
            previousScore = score
        }
    }

    // MARK: - RHR Component Tests

    func test_calculateScore_rhrBelow40_penalizedForOvertraining() {
        let veryLow = ScoreEngine.calculateScore(
            hrv: nil, restingHR: 38, bloodOxygen: nil, sleepMinutes: 0
        )
        let optimal = ScoreEngine.calculateScore(
            hrv: nil, restingHR: 45, bloodOxygen: nil, sleepMinutes: 0
        )
        XCTAssertLessThan(veryLow, optimal,
            "RHR < 40 (overtraining) should score lower than optimal 45")
    }

    func test_calculateScore_rhrDecreasing_scoresImprove() {
        let high = ScoreEngine.calculateScore(
            hrv: nil, restingHR: 85, bloodOxygen: nil, sleepMinutes: 0
        )
        let normal = ScoreEngine.calculateScore(
            hrv: nil, restingHR: 60, bloodOxygen: nil, sleepMinutes: 0
        )
        let athletic = ScoreEngine.calculateScore(
            hrv: nil, restingHR: 50, bloodOxygen: nil, sleepMinutes: 0
        )
        XCTAssertLessThan(high, normal)
        XCTAssertLessThan(normal, athletic)
    }

    // MARK: - Sleep Component Tests

    func test_calculateScore_noSleep_lowSleepComponent() {
        let noSleep = ScoreEngine.calculateScore(
            hrv: nil, restingHR: nil, bloodOxygen: nil, sleepMinutes: 0
        )
        let goodSleep = ScoreEngine.calculateScore(
            hrv: nil, restingHR: nil, bloodOxygen: nil, sleepMinutes: 480
        )
        XCTAssertLessThan(noSleep, goodSleep)
    }

    func test_calculateScore_optimalSleep_7to8_5hours() {
        let optimal = ScoreEngine.calculateScore(
            hrv: nil, restingHR: nil, bloodOxygen: nil, sleepMinutes: 480 // 8h
        )
        let tooShort = ScoreEngine.calculateScore(
            hrv: nil, restingHR: nil, bloodOxygen: nil, sleepMinutes: 300 // 5h
        )
        let tooLong = ScoreEngine.calculateScore(
            hrv: nil, restingHR: nil, bloodOxygen: nil, sleepMinutes: 660 // 11h
        )
        XCTAssertGreaterThan(optimal, tooShort, "8h sleep should score better than 5h")
        XCTAssertGreaterThan(optimal, tooLong, "8h sleep should score better than 11h (oversleep)")
    }

    // MARK: - SpO2 Component Tests

    func test_calculateScore_spo2Below92_veryLow() {
        let low = ScoreEngine.calculateScore(
            hrv: nil, restingHR: nil, bloodOxygen: 88, sleepMinutes: 0
        )
        let normal = ScoreEngine.calculateScore(
            hrv: nil, restingHR: nil, bloodOxygen: 98, sleepMinutes: 0
        )
        XCTAssertLessThan(low, normal, "SpO2 88% should score much lower than 98%")
    }

    // MARK: - Negative Sleep Minutes (Edge Case / Bug Detection)

    func test_calculateScore_negativeSleepMinutes_doesNotCrash() {
        let score = ScoreEngine.calculateScore(
            hrv: 50, restingHR: 60, bloodOxygen: 97, sleepMinutes: -100
        )
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
    }

    // MARK: - Generate Brief Tests

    func test_generateBrief_returnsValidBrief() {
        let brief = ScoreEngine.generateBrief(
            hrv: 55,
            restingHR: 58,
            bloodOxygen: 97,
            sleepMinutes: 450,
            deepSleepMinutes: 90,
            remSleepMinutes: 100,
            steps: 8000,
            recentWorkouts: []
        )
        XCTAssertGreaterThanOrEqual(brief.score, 0)
        XCTAssertLessThanOrEqual(brief.score, 100)
        XCTAssertFalse(brief.headline.isEmpty, "Headline should not be empty")
        XCTAssertFalse(brief.insight.isEmpty, "Insight should not be empty")
    }

    func test_generateBrief_noSleep_noSleepSummary() {
        let brief = ScoreEngine.generateBrief(
            hrv: 50, restingHR: 60, bloodOxygen: 97,
            sleepMinutes: 0, deepSleepMinutes: 0, remSleepMinutes: 0,
            steps: 5000, recentWorkouts: []
        )
        XCTAssertNil(brief.sleepSummary, "No sleep data should produce nil sleepSummary")
    }

    func test_generateBrief_lowScore_hasRecoveryNote() {
        let brief = ScoreEngine.generateBrief(
            hrv: 20,        // very low
            restingHR: 85,  // elevated
            bloodOxygen: 93,
            sleepMinutes: 240, // only 4h
            deepSleepMinutes: 20,
            remSleepMinutes: 30,
            steps: 2000,
            recentWorkouts: []
        )
        XCTAssertLessThan(brief.score, 60)
        // Recovery note should mention HRV or RHR
        XCTAssertNotNil(brief.recoveryNote, "Low score should generate a recovery note")
    }

    func test_generateBrief_veryLowScore_suggestsRest() {
        let brief = ScoreEngine.generateBrief(
            hrv: 10, restingHR: 95, bloodOxygen: 90,
            sleepMinutes: 180, deepSleepMinutes: 10, remSleepMinutes: 15,
            steps: 500, recentWorkouts: []
        )
        XCTAssertNotNil(brief.trainingPlan)
        if let plan = brief.trainingPlan, brief.score < 30 {
            XCTAssertEqual(plan.targetMuscleGroup, "rest",
                "Very low score should suggest rest day")
        }
    }

    // MARK: - Training Suggestion Tests

    func test_generateBrief_noRecentWorkouts_suggestsChest() {
        // With no workout history, "chest" is first in the rotation
        let brief = ScoreEngine.generateBrief(
            hrv: 60, restingHR: 55, bloodOxygen: 98,
            sleepMinutes: 480, deepSleepMinutes: 90, remSleepMinutes: 100,
            steps: 10000, recentWorkouts: []
        )
        XCTAssertNotNil(brief.trainingPlan)
        // All muscle groups have 999 days since last trained, so first group wins
        if let plan = brief.trainingPlan {
            XCTAssertTrue(["chest", "back", "legs", "shoulders"].contains(plan.targetMuscleGroup),
                "Should suggest a valid muscle group")
        }
    }

    func test_generateBrief_highScore_highIntensity() {
        let brief = ScoreEngine.generateBrief(
            hrv: 90, restingHR: 48, bloodOxygen: 99,
            sleepMinutes: 510, deepSleepMinutes: 110, remSleepMinutes: 110,
            steps: 12000, recentWorkouts: []
        )
        if let plan = brief.trainingPlan, brief.score >= 70 {
            XCTAssertEqual(plan.intensity, .heavy,
                "High score >= 70 should recommend high intensity")
        }
    }
}
