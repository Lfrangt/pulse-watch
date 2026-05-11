import XCTest
@testable import PulseWatch

/// Tests for PulseTheme — ensures UI labels match score ranges correctly
/// App Store rejection risk: misleading health status labels
final class PulseThemeTests: XCTestCase {

    // MARK: - Status Label Tests

    func test_statusLabel_rest_below30() {
        XCTAssertEqual(PulseTheme.statusLabel(for: 0), String(localized: "Rest"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 15), String(localized: "Rest"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 29), String(localized: "Rest"))
    }

    func test_statusLabel_average_30to49() {
        XCTAssertEqual(PulseTheme.statusLabel(for: 30), String(localized: "Average"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 40), String(localized: "Average"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 49), String(localized: "Average"))
    }

    func test_statusLabel_fair_50to69() {
        XCTAssertEqual(PulseTheme.statusLabel(for: 50), String(localized: "Fair"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 60), String(localized: "Fair"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 69), String(localized: "Fair"))
    }

    func test_statusLabel_good_70to84() {
        XCTAssertEqual(PulseTheme.statusLabel(for: 70), String(localized: "Good"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 75), String(localized: "Good"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 84), String(localized: "Good"))
    }

    func test_statusLabel_peak_85plus() {
        XCTAssertEqual(PulseTheme.statusLabel(for: 85), String(localized: "Peak"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 95), String(localized: "Peak"))
        XCTAssertEqual(PulseTheme.statusLabel(for: 100), String(localized: "Peak"))
    }

    // MARK: - Edge Cases

    func test_statusLabel_exactBoundaries() {
        // Ensure no gaps or overlaps at boundaries
        let rest = PulseTheme.statusLabel(for: 29)
        let avg = PulseTheme.statusLabel(for: 30)
        XCTAssertNotEqual(rest, avg, "29 and 30 should have different labels")

        let fair = PulseTheme.statusLabel(for: 50)
        let good = PulseTheme.statusLabel(for: 70)
        XCTAssertNotEqual(fair, good, "50 and 70 should have different labels")
    }

    func test_statusLabel_negativeScore_isRest() {
        // Shouldn't happen but defensive test
        let label = PulseTheme.statusLabel(for: -5)
        XCTAssertEqual(label, String(localized: "Rest"),
            "Negative score should map to Rest")
    }

    func test_statusLabel_allScores_noEmptyLabels() {
        for score in stride(from: 0, through: 100, by: 5) {
            let label = PulseTheme.statusLabel(for: score)
            XCTAssertFalse(label.isEmpty, "Score \(score) should have a non-empty label")
        }
    }
}
