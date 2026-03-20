import Foundation
import HealthKit
import SwiftUI

/// Central manager for all HealthKit data access
@Observable
final class HealthKitManager {
    
    static let shared = HealthKitManager()
    
    private let store = HKHealthStore()
    
    var isAuthorized = false
    var hasHealthData = false
    var authorizationStatus: AuthorizationStatus = .notDetermined
    
    var latestHeartRate: Double?
    var latestHRV: Double?
    var latestRestingHR: Double?
    var latestBloodOxygen: Double?
    var todaySteps: Int = 0
    var todayActiveCalories: Double = 0
    var todayExerciseMinutes: Double = 0  // Apple Watch appleExerciseTime（真实运动分钟）
    var lastNightSleepMinutes: Int = 0
    var lastNightDeepSleepMinutes: Int = 0  // HealthKit .asleepDeep 真实深睡时长
    var lastNightREMSleepMinutes: Int = 0   // HealthKit .asleepREM 真实 REM 时长
    var lastNightSleepStart: Date? = nil    // 真实入睡时间（第一个睡眠 sample 的 startDate）
    var lastNightSleepEnd: Date? = nil      // 真实醒来时间（最后一个睡眠 sample 的 endDate）
    var todayLastWorkoutStart: Date? = nil  // 今日最近一次 workout 的真实开始时间
    
    enum AuthorizationStatus {
        case notDetermined
        case denied
        case partiallyAuthorized
        case authorized
        
        var icon: String {
            switch self {
            case .authorized: return "checkmark.circle.fill"
            case .partiallyAuthorized: return "exclamationmark.circle"
            case .denied, .notDetermined: return "xmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .authorized: return PulseTheme.statusGood
            case .partiallyAuthorized: return PulseTheme.statusModerate
            case .denied, .notDetermined: return PulseTheme.statusPoor
            }
        }
        
        var description: String {
            switch self {
            case .authorized: return String(localized: "Authorized")
            case .partiallyAuthorized: return String(localized: "Partially Authorized")
            case .denied: return String(localized: "Not Authorized")
            case .notDetermined: return String(localized: "Not Determined")
            }
        }
    }
    
    // MARK: - Authorization
    
    private var readTypes: Set<HKObjectType> {
        Set([
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.appleStandTime),
            HKCategoryType(.sleepAnalysis),
        ].compactMap { $0 })
    }
    
    private var writeTypes: Set<HKSampleType> {
        Set([
            HKQuantityType(.activeEnergyBurned),
        ].compactMap { $0 })
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw PulseError.healthDataUnavailable
        }
        
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        isAuthorized = true
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        // HealthKit authorizationStatus(for:) only works for WRITE types.
        // For read-only apps, we check if we can actually query data.
        // After requestAuthorization succeeds, assume authorized.
        // Will be updated to .authorized once hasHealthData == true.
        Task {
            do {
                // If requestAuthorization was called successfully before, the system
                // shows it as authorized even though we can't check read status directly.
                let status = try await store.statusForAuthorizationRequest(
                    toShare: [],
                    read: Set([
                        HKQuantityType(.heartRate),
                        HKQuantityType(.heartRateVariabilitySDNN),
                        HKQuantityType(.stepCount),
                        HKCategoryType(.sleepAnalysis),
                    ] as [HKObjectType])
                )

                await MainActor.run {
                    switch status {
                    case .unnecessary:
                        authorizationStatus = .authorized
                    case .shouldRequest:
                        authorizationStatus = .notDetermined
                    case .unknown:
                        authorizationStatus = hasHealthData ? .authorized : .notDetermined
                    @unknown default:
                        authorizationStatus = hasHealthData ? .authorized : .notDetermined
                    }
                }
            } catch {
                // Fallback: if we have data, we're authorized
                await MainActor.run {
                    if hasHealthData {
                        authorizationStatus = .authorized
                    }
                }
            }
        }
    }
    
    var isFullyAuthorized: Bool {
        return authorizationStatus == .authorized
    }
    
    // MARK: - Heart Rate
    
    func fetchLatestHeartRate() async throws -> Double? {
        let type = HKQuantityType(.heartRate)
        let sample = try await fetchMostRecentSample(for: type)
        let value = sample?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        latestHeartRate = value
        return value
    }
    
    // MARK: - HRV
    
    func fetchLatestHRV() async throws -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let sample = try await fetchMostRecentSample(for: type)
        let value = sample?.quantity.doubleValue(for: .secondUnit(with: .milli))
        latestHRV = value
        return value
    }
    
    // MARK: - Resting Heart Rate
    
    func fetchRestingHeartRate() async throws -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let sample = try await fetchMostRecentSample(for: type)
        let value = sample?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        latestRestingHR = value
        return value
    }
    
    // MARK: - Blood Oxygen
    
    func fetchBloodOxygen() async throws -> Double? {
        let type = HKQuantityType(.oxygenSaturation)
        let sample = try await fetchMostRecentSample(for: type)
        let value = sample.map { $0.quantity.doubleValue(for: .percent()) * 100 }
        latestBloodOxygen = value
        return value
    }
    
    // MARK: - Steps (today)
    
    func fetchTodaySteps() async throws -> Int {
        let type = HKQuantityType(.stepCount)
        let sum = try await fetchTodaySum(for: type, unit: .count())
        todaySteps = Int(sum)
        return Int(sum)
    }
    
    // MARK: - Active Calories (today)
    
    func fetchTodayCalories() async throws -> Double {
        let type = HKQuantityType(.activeEnergyBurned)
        let sum = try await fetchTodaySum(for: type, unit: .kilocalorie())
        todayActiveCalories = sum
        return sum
    }

    // MARK: - Exercise Time (today) — Apple Watch appleExerciseTime
    
    func fetchTodayExerciseTime() async throws -> Double {
        let type = HKQuantityType(.appleExerciseTime)
        let minutes = try await fetchTodaySum(for: type, unit: .minute())
        todayExerciseMinutes = minutes
        return minutes
    }
    
    // MARK: - Sleep (last night)
    
    func fetchLastNightSleep() async throws -> (total: Int, deep: Int, rem: Int) {
        let type = HKCategoryType(.sleepAnalysis)
        
        // Look back 24 hours
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now)
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        
        let samples = try await descriptor.result(for: store)
        
        var totalMinutes = 0
        var deepMinutes = 0
        var remMinutes = 0
        var earliestStart: Date? = nil
        var latestEnd: Date? = nil

        for sample in samples {
            let duration = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)

            switch value {
            case .asleepDeep:
                deepMinutes += duration
                totalMinutes += duration
            case .asleepREM:
                remMinutes += duration
                totalMinutes += duration
            case .asleepCore:
                totalMinutes += duration
            case .asleepUnspecified:
                totalMinutes += duration
            default:
                break // inBed, awake — 不计入睡眠时长，但可以作为入睡/起床边界
            }

            // 用所有 sample（包括 inBed）来确定整体睡眠窗口的起止
            if earliestStart == nil || sample.startDate < earliestStart! {
                earliestStart = sample.startDate
            }
            if latestEnd == nil || sample.endDate > latestEnd! {
                latestEnd = sample.endDate
            }
        }

        lastNightSleepMinutes = totalMinutes
        lastNightDeepSleepMinutes = deepMinutes
        lastNightREMSleepMinutes = remMinutes
        lastNightSleepStart = earliestStart
        lastNightSleepEnd = latestEnd
        return (totalMinutes, deepMinutes, remMinutes)
    }
    
    // MARK: - Sleep Samples (for hypnogram)

    struct SleepSample: Identifiable {
        let id = UUID()
        let stage: SleepStage
        let start: Date
        let end: Date
        var durationMinutes: Int { Int(end.timeIntervalSince(start) / 60) }
    }

    enum SleepStage: String, CaseIterable {
        case deep, rem, core, awake
    }

    func fetchSleepSamples() async throws -> [SleepSample] {
        let type = HKCategoryType(.sleepAnalysis)
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)
        return samples.compactMap { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            let stage: SleepStage?
            switch value {
            case .asleepDeep: stage = .deep
            case .asleepREM: stage = .rem
            case .asleepCore: stage = .core
            case .awake, .inBed: stage = .awake
            default: stage = nil
            }
            guard let s = stage else { return nil }
            return SleepSample(stage: s, start: sample.startDate, end: sample.endDate)
        }
    }

    // MARK: - Today's Last Workout

    func fetchTodayLastWorkout() async {
        // workoutType not needed — using .workout() predicate directly
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        if let sample = try? await descriptor.result(for: store).first {
            todayLastWorkoutStart = sample.startDate
        }
    }

    // MARK: - Refresh All
    
    func refreshAll() async {
        do {
            _ = try await fetchLatestHeartRate()
            _ = try await fetchLatestHRV()
            _ = try await fetchRestingHeartRate()
            _ = try await fetchBloodOxygen()
            _ = try await fetchTodaySteps()
            _ = try await fetchTodayCalories()
            _ = try await fetchTodayExerciseTime()
            _ = try await fetchLastNightSleep()
            await fetchTodayLastWorkout()
            
            // Check if we have any meaningful health data
            updateHealthDataAvailability()
        } catch {
            #if DEBUG
            print("HealthKit refresh error: \(error)")
            #endif
            hasHealthData = false
        }
    }
    
    private func updateHealthDataAvailability() {
        let hasAnyData = latestHeartRate != nil ||
                        latestHRV != nil ||
                        latestRestingHR != nil ||
                        latestBloodOxygen != nil ||
                        todaySteps > 0 ||
                        todayActiveCalories > 0 ||
                        lastNightSleepMinutes > 0
        
        hasHealthData = hasAnyData
    }
    
    // MARK: - Daily Score Calculation
    
    func calculateDailyScore() -> Int {
        var score = 50 // baseline
        
        // HRV contribution (higher = better, personal baseline matters)
        if let hrv = latestHRV {
            if hrv > 60 { score += 15 }
            else if hrv > 40 { score += 5 }
            else { score -= 10 }
        }
        
        // Resting HR (lower = better for most people)
        if let rhr = latestRestingHR {
            if rhr < 60 { score += 10 }
            else if rhr < 70 { score += 5 }
            else if rhr > 80 { score -= 10 }
        }
        
        // Sleep
        if lastNightSleepMinutes > 420 { score += 15 }        // 7+ hours
        else if lastNightSleepMinutes > 360 { score += 5 }    // 6+ hours
        else if lastNightSleepMinutes < 300 { score -= 15 }   // <5 hours
        
        // Blood oxygen
        if let spo2 = latestBloodOxygen {
            if spo2 >= 96 { score += 5 }
            else if spo2 < 92 { score -= 15 }
        }
        
        // Activity
        if todaySteps > 8000 { score += 5 }
        
        return max(0, min(100, score))
    }
    
    // MARK: - Private Helpers
    
    private func fetchMostRecentSample(for type: HKQuantityType) async throws -> HKQuantitySample? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        return try await descriptor.result(for: store).first
    }
    
    private func fetchTodaySum(for type: HKQuantityType, unit: HKUnit) async throws -> Double {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)
        
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        
        let result = try await descriptor.result(for: store)
        return result?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }
}

// MARK: - Errors

enum PulseError: LocalizedError {
    case healthDataUnavailable
    case locationNotAuthorized
    case workoutNotStarted
    
    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable: return "Health data unavailable"
        case .locationNotAuthorized: return "Location not authorized"
        case .workoutNotStarted: return "Not Started"
        }
    }
}
