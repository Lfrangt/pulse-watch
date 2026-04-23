import XCTest
@testable import PulseWatch

/// Tests for TrainingChallenge model — progress tracking and date math
/// App Store risk: incorrect progress display, expired challenge bugs
final class TrainingChallengeTests: XCTestCase {

    // MARK: - Initialization

    func test_init_setsCorrectDefaults() {
        let challenge = TrainingChallenge(
            name: "30-Day Push-up",
            challengeType: "pushup",
            targetPerDay: 100,
            durationDays: 30
        )

        XCTAssertEqual(challenge.name, "30-Day Push-up")
        XCTAssertEqual(challenge.challengeType, "pushup")
        XCTAssertEqual(challenge.targetPerDay, 100)
        XCTAssertEqual(challenge.durationDays, 30)
        XCTAssertTrue(challenge.isActive)
        XCTAssertEqual(challenge.completedCount, 0)
    }

    // MARK: - Completed Days JSON Round-Trip

    func test_completedDays_initiallyEmpty() {
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1, durationDays: 7
        )
        XCTAssertTrue(challenge.completedDays.isEmpty)
    }

    func test_completedDays_setAndGet_roundTrips() {
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1, durationDays: 7
        )
        challenge.completedDays = Set(["2026-03-01", "2026-03-02", "2026-03-03"])
        XCTAssertEqual(challenge.completedDays.count, 3)
        XCTAssertTrue(challenge.completedDays.contains("2026-03-01"))
    }

    func test_markCompleted_addsDayCorrectly() {
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1, durationDays: 7
        )

        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        challenge.markCompleted(date: date)

        XCTAssertTrue(challenge.isCompleted(date: date))
        XCTAssertEqual(challenge.completedCount, 1)
    }

    func test_markCompleted_idempotent() {
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1, durationDays: 7
        )

        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        challenge.markCompleted(date: date)
        challenge.markCompleted(date: date) // duplicate

        XCTAssertEqual(challenge.completedCount, 1, "Marking same day twice should not double-count")
    }

    // MARK: - Progress Calculation

    func test_progressPercent_zero_whenNoneCompleted() {
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1, durationDays: 30
        )
        XCTAssertEqual(challenge.progressPercent, 0.0)
    }

    func test_progressPercent_correctWhenPartiallyCompleted() {
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1, durationDays: 10
        )
        challenge.completedDays = Set(["2026-03-01", "2026-03-02", "2026-03-03"])
        XCTAssertEqual(challenge.progressPercent, 0.3, accuracy: 0.001)
    }

    func test_progressPercent_zeroDurationDays_doesNotCrash() {
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1, durationDays: 0
        )
        XCTAssertEqual(challenge.progressPercent, 0.0,
            "Zero duration should return 0 progress, not crash")
    }

    // MARK: - End Date & Expiration

    func test_endDate_30dayChallenge() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1,
            durationDays: 30, startDate: startDate
        )

        let expectedEnd = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 30))!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: challenge.endDate),
            Calendar.current.startOfDay(for: expectedEnd)
        )
    }

    func test_isExpired_pastChallenge() {
        let oldDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let challenge = TrainingChallenge(
            name: "Old", challengeType: "custom", targetPerDay: 1,
            durationDays: 7, startDate: oldDate
        )
        XCTAssertTrue(challenge.isExpired, "Challenge from 2025 should be expired")
    }

    func test_daysRemaining_expiredChallenge_returnsZero() {
        let oldDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let challenge = TrainingChallenge(
            name: "Old", challengeType: "custom", targetPerDay: 1,
            durationDays: 7, startDate: oldDate
        )
        XCTAssertEqual(challenge.daysRemaining, 0, "Expired challenge should have 0 days remaining")
    }

    // MARK: - Corrupted JSON Resilience

    func test_completedDays_corruptedJSON_returnsEmpty() {
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1, durationDays: 7
        )
        challenge.completedDaysRaw = "this is not valid json"
        XCTAssertTrue(challenge.completedDays.isEmpty,
            "Corrupted JSON should safely return empty set, not crash")
    }

    func test_completedDays_nilRaw_returnsEmpty() {
        let challenge = TrainingChallenge(
            name: "Test", challengeType: "custom", targetPerDay: 1, durationDays: 7
        )
        challenge.completedDaysRaw = nil
        XCTAssertTrue(challenge.completedDays.isEmpty)
    }
}
