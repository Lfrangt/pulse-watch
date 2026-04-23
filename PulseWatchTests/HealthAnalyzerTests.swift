import XCTest
@testable import PulseWatch

/// Tests for HealthAnalyzer data types and enums
/// Cannot test HealthAnalyzer.shared directly (depends on HealthDataService singleton)
/// but we can test the data models, enums, and scoring contracts
final class HealthAnalyzerTests: XCTestCase {

    // MARK: - TrainingAdvice Tests

    func test_trainingAdvice_allCasesHaveLabels() {
        let allCases: [TrainingAdvice] = [.intense, .moderate, .light, .rest]
        for advice in allCases {
            XCTAssertFalse(advice.label.isEmpty, "\(advice) missing label")
            XCTAssertFalse(advice.icon.isEmpty, "\(advice) missing icon")
        }
    }

    func test_trainingAdvice_codableRoundTrip() throws {
        let allCases: [TrainingAdvice] = [.intense, .moderate, .light, .rest]
        for advice in allCases {
            let data = try JSONEncoder().encode(advice)
            let decoded = try JSONDecoder().decode(TrainingAdvice.self, from: data)
            XCTAssertEqual(decoded, advice)
        }
    }

    // MARK: - Trend Tests

    func test_trend_allCasesHaveLabelsAndIcons() {
        let allCases: [Trend] = [.improving, .stable, .declining, .insufficient]
        for trend in allCases {
            XCTAssertFalse(trend.label.isEmpty, "\(trend) missing label")
            XCTAssertFalse(trend.icon.isEmpty, "\(trend) missing icon")
        }
    }

    // MARK: - AnomalySeverityLevel Comparable Tests

    func test_anomalySeverity_ordering() {
        XCTAssertTrue(AnomalySeverityLevel.low < AnomalySeverityLevel.medium)
        XCTAssertTrue(AnomalySeverityLevel.medium < AnomalySeverityLevel.high)
        XCTAssertFalse(AnomalySeverityLevel.high < AnomalySeverityLevel.low)
    }

    // MARK: - AnomalyMetric Raw Values

    func test_anomalyMetric_rawValues() {
        XCTAssertEqual(AnomalyMetric.hrv.rawValue, "HRV")
        XCTAssertEqual(AnomalyMetric.restingHeartRate.rawValue, "Resting HR")
        XCTAssertEqual(AnomalyMetric.sleep.rawValue, "Sleep")
        XCTAssertEqual(AnomalyMetric.bloodOxygen.rawValue, "Blood Oxygen")
    }

    // MARK: - HealthInsight dailyScore Calculation

    func test_healthInsight_dailyScore_weightedAverage() {
        let insight = HealthInsight(
            recoveryScore: 80,
            sleepScore: 60,
            trainingAdvice: .moderate,
            trends: TrendAnalysis(
                hrvTrend: .stable, rhrTrend: .stable,
                sleepTrend: .stable, scoreTrend: .stable,
                weekAvgScore: nil, monthAvgScore: nil
            ),
            insights: [],
            anomalies: [],
            generatedAt: .now
        )
        // 80*0.6 + 60*0.4 = 48 + 24 = 72
        XCTAssertEqual(insight.dailyScore, 72)
    }

    func test_healthInsight_dailyScore_clampedTo0_100() {
        let insight = HealthInsight(
            recoveryScore: 100,
            sleepScore: 100,
            trainingAdvice: .intense,
            trends: TrendAnalysis(
                hrvTrend: .improving, rhrTrend: .improving,
                sleepTrend: .improving, scoreTrend: .improving,
                weekAvgScore: 90, monthAvgScore: 85
            ),
            insights: [],
            anomalies: [],
            generatedAt: .now
        )
        XCTAssertLessThanOrEqual(insight.dailyScore, 100)
        XCTAssertGreaterThanOrEqual(insight.dailyScore, 0)
    }

    func test_healthInsight_dailyScore_zeroBoth() {
        let insight = HealthInsight(
            recoveryScore: 0,
            sleepScore: 0,
            trainingAdvice: .rest,
            trends: TrendAnalysis(
                hrvTrend: .insufficient, rhrTrend: .insufficient,
                sleepTrend: .insufficient, scoreTrend: .insufficient,
                weekAvgScore: nil, monthAvgScore: nil
            ),
            insights: [],
            anomalies: [],
            generatedAt: .now
        )
        XCTAssertEqual(insight.dailyScore, 0)
    }

    // MARK: - CorrelationResult Tests

    func test_correlationResult_strengthLabel_strong() {
        let result = CorrelationResult(
            metricA: .sleepDuration, metricB: .hrv,
            coefficient: 0.75, sampleSize: 30,
            insight: "test"
        )
        XCTAssertEqual(result.strengthLabel, String(localized: "强相关"))
        XCTAssertTrue(result.isPositive)
    }

    func test_correlationResult_strengthLabel_moderate() {
        let result = CorrelationResult(
            metricA: .restingHR, metricB: .hrv,
            coefficient: -0.55, sampleSize: 30,
            insight: "test"
        )
        XCTAssertEqual(result.strengthLabel, String(localized: "中等相关"))
        XCTAssertFalse(result.isPositive)
    }

    func test_correlationResult_strengthLabel_weak() {
        let result = CorrelationResult(
            metricA: .steps, metricB: .sleepDuration,
            coefficient: 0.35, sampleSize: 30,
            insight: "test"
        )
        XCTAssertEqual(result.strengthLabel, String(localized: "弱相关"))
    }

    func test_correlationResult_strengthLabel_negligible() {
        let result = CorrelationResult(
            metricA: .steps, metricB: .dailyScore,
            coefficient: 0.15, sampleSize: 30,
            insight: "test"
        )
        XCTAssertEqual(result.strengthLabel, String(localized: "微弱"))
    }

    // MARK: - CorrelationMetric Tests

    func test_correlationMetric_allHaveLabelsAndIcons() {
        let allCases: [CorrelationMetric] = [
            .sleepDuration, .deepSleepRatio, .hrv,
            .restingHR, .dailyScore, .steps, .exerciseMinutes
        ]
        for metric in allCases {
            XCTAssertFalse(metric.label.isEmpty, "\(metric.rawValue) missing label")
            XCTAssertFalse(metric.icon.isEmpty, "\(metric.rawValue) missing icon")
        }
    }

    // MARK: - LatestVitals Tests

    func test_latestVitals_isValid_requiresHeartRate() {
        var vitals = LatestVitals()
        XCTAssertFalse(vitals.isValid, "Empty vitals should not be valid")

        vitals.heartRate = 72
        XCTAssertTrue(vitals.isValid, "Vitals with heartRate should be valid")
    }

    func test_latestVitals_initialState_allNil() {
        let vitals = LatestVitals()
        XCTAssertNil(vitals.heartRate)
        XCTAssertNil(vitals.hrv)
        XCTAssertNil(vitals.restingHeartRate)
        XCTAssertNil(vitals.bloodOxygen)
        XCTAssertNil(vitals.steps)
        XCTAssertNil(vitals.activeCalories)
        XCTAssertNil(vitals.lastUpdated)
    }
}
