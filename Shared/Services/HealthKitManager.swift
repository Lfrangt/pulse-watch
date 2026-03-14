import Foundation
import HealthKit

/// Central manager for all HealthKit data access
@Observable
final class HealthKitManager {
    
    static let shared = HealthKitManager()
    
    private let store = HKHealthStore()
    
    var isAuthorized = false
    var latestHeartRate: Double?
    var latestHRV: Double?
    var latestRestingHR: Double?
    var latestBloodOxygen: Double?
    var todaySteps: Int = 0
    var todayActiveCalories: Double = 0
    var lastNightSleepMinutes: Int = 0
    
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
                break // inBed, awake
            }
        }
        
        lastNightSleepMinutes = totalMinutes
        return (totalMinutes, deepMinutes, remMinutes)
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
            _ = try await fetchLastNightSleep()
        } catch {
            print("HealthKit refresh error: \(error)")
        }
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
        case .healthDataUnavailable: return "健康数据不可用"
        case .locationNotAuthorized: return "位置权限未授权"
        case .workoutNotStarted: return "训练未开始"
        }
    }
}
