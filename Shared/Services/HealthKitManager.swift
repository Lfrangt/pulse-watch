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
        let yesterday = Calendar.current.safeDate(byAdding: .hour, value: -24, to: now)
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        
        let allSamples = try await descriptor.result(for: store)
        let mainSession = filterToMainSession(allSamples)

        var totalMinutes = 0
        var deepMinutes = 0
        var remMinutes = 0
        var earliestStart: Date? = nil
        var latestEnd: Date? = nil

        for sample in mainSession {
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

            // 用主 session 的 sample 来确定睡眠窗口的起止
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
    
    // MARK: - Most Recent Sleep (fallback up to 7 days)

    /// Finds the most recent sleep session within the past 7 days.
    /// Falls back beyond 24h when last night has no data.
    func fetchMostRecentSleep() async throws -> (total: Int, deep: Int, rem: Int) {
        let type = HKCategoryType(.sleepAnalysis)
        let now = Date()
        let sevenDaysAgo = Calendar.current.safeDate(byAdding: .day, value: -7, to: now)
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )

        let allSamples = try await descriptor.result(for: store)
        guard let mostRecent = allSamples.first else {
            return (0, 0, 0)
        }

        // Find the calendar day of the most recent sample, then collect all samples from that sleep session
        // A sleep session spans from ~18:00 the prior evening to ~12:00 the next day
        let cal = Calendar.current
        let sessionEndDay = cal.startOfDay(for: mostRecent.endDate)
        let sessionWindowStart = cal.safeDate(byAdding: .hour, value: -18, to: sessionEndDay) // 6pm prior day
        let sessionWindowEnd = cal.safeDate(byAdding: .hour, value: 14, to: sessionEndDay) // 2pm session day

        let windowFiltered = allSamples
            .filter { $0.startDate >= sessionWindowStart && $0.endDate <= sessionWindowEnd }
        let mainSession = filterToMainSession(windowFiltered)

        var totalMinutes = 0
        var deepMinutes = 0
        var remMinutes = 0
        var earliestStart: Date? = nil
        var latestEnd: Date? = nil

        for sample in mainSession {
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
                break
            }

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

    /// Fetch sleep samples for the most recent session (up to 7 days back) for hypnogram display
    func fetchMostRecentSleepSamples() async throws -> [SleepSample] {
        let type = HKCategoryType(.sleepAnalysis)
        let now = Date()
        let sevenDaysAgo = Calendar.current.safeDate(byAdding: .day, value: -7, to: now)
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        let allSamples = try await descriptor.result(for: store)
        guard let mostRecent = allSamples.first else { return [] }

        let cal = Calendar.current
        let sessionEndDay = cal.startOfDay(for: mostRecent.endDate)
        let sessionWindowStart = cal.safeDate(byAdding: .hour, value: -18, to: sessionEndDay)
        let sessionWindowEnd = cal.safeDate(byAdding: .hour, value: 14, to: sessionEndDay)

        let windowFiltered = allSamples
            .filter { $0.startDate >= sessionWindowStart && $0.endDate <= sessionWindowEnd }
        let mainSession = filterToMainSession(windowFiltered)
        return mainSession
            .sorted { $0.startDate < $1.startDate }
            .compactMap { sample in
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

    // MARK: - Weekly Sleep Summary

    struct DailySleepSummary {
        let date: Date
        let totalMinutes: Int
        let deepMinutes: Int
        let remMinutes: Int
        let coreMinutes: Int
    }

    /// Returns one entry per day for the past 7 days, including days with 0 data
    func fetchWeekSleepSummary() async throws -> [DailySleepSummary] {
        let type = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let sevenDaysAgo = cal.safeDate(byAdding: .day, value: -7, to: today)
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let allSamples = try await descriptor.result(for: store)

        // Group samples by the day they "belong to" — sleep ending before noon counts as that day,
        // sleep ending after noon counts as the next day. We use the endDate to assign the day.
        var dayBuckets: [Date: (total: Int, deep: Int, rem: Int, core: Int)] = [:]

        for sample in allSamples {
            // Assign to the calendar day of endDate
            let dayKey = cal.startOfDay(for: sample.endDate)
            let duration = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)

            var bucket = dayBuckets[dayKey] ?? (0, 0, 0, 0)
            switch value {
            case .asleepDeep:
                bucket.deep += duration
                bucket.total += duration
            case .asleepREM:
                bucket.rem += duration
                bucket.total += duration
            case .asleepCore:
                bucket.core += duration
                bucket.total += duration
            case .asleepUnspecified:
                bucket.total += duration
            default:
                break
            }
            dayBuckets[dayKey] = bucket
        }

        // Build array for past 7 days, filling gaps with zeroes
        return (0..<7).map { offset in
            let day = cal.safeDate(byAdding: .day, value: -(6 - offset), to: today)
            let bucket = dayBuckets[day]
            return DailySleepSummary(
                date: day,
                totalMinutes: bucket?.total ?? 0,
                deepMinutes: bucket?.deep ?? 0,
                remMinutes: bucket?.rem ?? 0,
                coreMinutes: bucket?.core ?? 0
            )
        }
    }

    // MARK: - Main Session Filter

    /// Groups consecutive HKCategorySamples into sessions (gap < 30 min = same session),
    /// then returns only samples belonging to the longest session (the main overnight sleep).
    private func filterToMainSession(_ samples: [HKCategorySample]) -> [HKCategorySample] {
        guard !samples.isEmpty else { return [] }

        let sorted = samples.sorted { $0.startDate < $1.startDate }
        let maxGap: TimeInterval = 30 * 60 // 30 minutes

        // Build sessions: each session is an array of consecutive samples
        var sessions: [[HKCategorySample]] = [[sorted[0]]]
        for i in 1..<sorted.count {
            let prev = sessions[sessions.count - 1].last!
            let gap = sorted[i].startDate.timeIntervalSince(prev.endDate)
            if gap < maxGap {
                sessions[sessions.count - 1].append(sorted[i])
            } else {
                sessions.append([sorted[i]])
            }
        }

        // Pick the longest session by total duration (sum of sample durations)
        let longest = sessions.max { a, b in
            let aDur = a.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let bDur = b.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            return aDur < bDur
        }

        return longest ?? []
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
        let yesterday = Calendar.current.safeDate(byAdding: .hour, value: -24, to: now)
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let allSamples = try await descriptor.result(for: store)
        let mainSession = filterToMainSession(allSamples)
        return mainSession.compactMap { sample in
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
        // 并行获取所有指标 — 独立查询，互不阻塞，单个失败不影响其他
        async let hr = try? fetchLatestHeartRate()
        async let hrv = try? fetchLatestHRV()
        async let rhr = try? fetchRestingHeartRate()
        async let spo2 = try? fetchBloodOxygen()
        async let steps = try? fetchTodaySteps()
        async let cal = try? fetchTodayCalories()
        async let exercise = try? fetchTodayExerciseTime()
        async let sleep = try? fetchLastNightSleep()
        async let workout: Void = fetchTodayLastWorkout()

        _ = await (hr, hrv, rhr, spo2, steps, cal, exercise, sleep, workout)

        // Check if we have any meaningful health data
        updateHealthDataAvailability()
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

    /// Delegates to ScoreEngine's weighted algorithm for consistency across all surfaces
    func calculateDailyScore() -> Int {
        ScoreEngine.calculateScore(
            hrv: latestHRV,
            restingHR: latestRestingHR,
            bloodOxygen: latestBloodOxygen,
            sleepMinutes: lastNightSleepMinutes
        )
    }
    
    // MARK: - Stress Score Calculation

    /// Computes stress score 0-100 from HRV, resting HR, and sleep.
    /// Higher score = MORE stressed. Weighted: HRV 50%, RHR 30%, Sleep 20%.
    func calculateStressScore() -> Int {
        // HRV component: lower HRV = more stressed
        // Map HRV 20-80ms → stress 100-0 (clamped)
        let hrvStress: Double
        if let hrv = latestHRV {
            let clamped = min(max(hrv, 20), 80)
            hrvStress = 100.0 - ((clamped - 20.0) / 60.0 * 100.0)
        } else {
            hrvStress = 50.0 // neutral fallback
        }

        // RHR component: higher RHR = more stressed
        // Map RHR 50-90bpm → stress 0-100 (clamped)
        let rhrStress: Double
        if let rhr = latestRestingHR {
            let clamped = min(max(rhr, 50), 90)
            rhrStress = (clamped - 50.0) / 40.0 * 100.0
        } else {
            rhrStress = 50.0
        }

        // Sleep component: less sleep = more stressed
        // Map 4-9 hours → stress 100-0 (clamped)
        let sleepHours = Double(lastNightSleepMinutes) / 60.0
        let sleepStress: Double
        if lastNightSleepMinutes > 0 {
            let clamped = min(max(sleepHours, 4.0), 9.0)
            sleepStress = 100.0 - ((clamped - 4.0) / 5.0 * 100.0)
        } else {
            sleepStress = 50.0
        }

        // Weighted average: HRV 50%, RHR 30%, Sleep 20%
        let raw = hrvStress * 0.5 + rhrStress * 0.3 + sleepStress * 0.2
        return max(0, min(100, Int(raw.rounded())))
    }

    /// Calculate stress score from stored DailySummary values (for historical data)
    static func calculateStressScore(hrv: Double?, restingHR: Double?, sleepMinutes: Int?) -> Int {
        let hrvStress: Double
        if let hrv {
            let clamped = min(max(hrv, 20), 80)
            hrvStress = 100.0 - ((clamped - 20.0) / 60.0 * 100.0)
        } else {
            hrvStress = 50.0
        }

        let rhrStress: Double
        if let rhr = restingHR {
            let clamped = min(max(rhr, 50), 90)
            rhrStress = (clamped - 50.0) / 40.0 * 100.0
        } else {
            rhrStress = 50.0
        }

        let sleepStress: Double
        if let sleepMin = sleepMinutes, sleepMin > 0 {
            let hours = min(max(Double(sleepMin) / 60.0, 4.0), 9.0)
            sleepStress = 100.0 - ((hours - 4.0) / 5.0 * 100.0)
        } else {
            sleepStress = 50.0
        }

        let raw = hrvStress * 0.5 + rhrStress * 0.3 + sleepStress * 0.2
        return max(0, min(100, Int(raw.rounded())))
    }

    // MARK: - Weekly Statistics (7-day daily breakdown)

    /// Fetch daily average HRV for the past 7 days from HealthKit
    func fetchWeeklyHRV() async throws -> [(date: Date, value: Double)] {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let unit = HKUnit.secondUnit(with: .milli)
        return try await fetchDailyStatistics(type: type, unit: unit, days: 7, options: .discreteAverage)
    }

    /// Fetch daily total steps for the past 7 days from HealthKit (auto-deduplicated)
    func fetchWeeklySteps() async throws -> [(date: Date, value: Double)] {
        let type = HKQuantityType(.stepCount)
        return try await fetchDailyStatistics(type: type, unit: .count(), days: 7, options: .cumulativeSum)
    }

    /// Generic daily statistics collection query
    private func fetchDailyStatistics(
        type: HKQuantityType,
        unit: HKUnit,
        days: Int,
        options: HKStatisticsOptions
    ) async throws -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.safeDate(byAdding: .day, value: -days + 1, to: calendar.startOfDay(for: now))
        let anchorDate = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now)
        let interval = DateComponents(day: 1)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var dataPoints: [(date: Date, value: Double)] = []
                results?.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                    let quantity: HKQuantity?
                    switch options {
                    case .cumulativeSum:
                        quantity = statistics.sumQuantity()
                    case .discreteAverage:
                        quantity = statistics.averageQuantity()
                    default:
                        quantity = statistics.averageQuantity()
                    }
                    if let value = quantity?.doubleValue(for: unit) {
                        dataPoints.append((date: statistics.startDate, value: value))
                    }
                }

                continuation.resume(returning: dataPoints)
            }

            store.execute(query)
        }
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
