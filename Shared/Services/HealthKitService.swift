import Foundation
import HealthKit
import SwiftData
import os

/// 后台 HealthKit 数据采集服务
/// 职责：权限请求、Background Delivery、Observer Query + Anchored Object Query
/// 采集到的数据写入 SwiftData（HealthRecord + DailySummary）
final class HealthKitService {

    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "HealthKitService")

    /// Anchored Object Query 的锚点，持久化到 UserDefaults
    private var anchors: [String: HKQueryAnchor] = [:]
    private let anchorDefaultsKey = "com.abundra.pulse.hkAnchors"

    /// SwiftData ModelContainer — 由 App 启动时注入
    var modelContainer: ModelContainer?

    // MARK: - 需要读取的 HealthKit 类型

    private var readTypes: Set<HKObjectType> {
        Set([
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKCategoryType(.sleepAnalysis),
        ].compactMap { $0 })
    }

    private var writeTypes: Set<HKSampleType> {
        Set([
            HKQuantityType(.activeEnergyBurned),
        ].compactMap { $0 })
    }

    /// 需要后台投递的量化类型（睡眠单独处理）
    private var backgroundQuantityTypes: [HKQuantityType] {
        [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.appleExerciseTime),
        ]
    }

    // MARK: - 初始化

    private init() {
        loadAnchors()
    }

    // MARK: - 权限请求

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw PulseError.healthDataUnavailable
        }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        logger.info("HealthKit 权限请求完成")
    }

    // MARK: - 注册后台投递（Background Delivery）

    /// 在 App 启动时调用，注册所有类型的后台投递
    func enableBackgroundDelivery() {
        // 量化类型
        for type in backgroundQuantityTypes {
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error {
                    self.logger.error("后台投递注册失败 [\(type.identifier)]: \(error.localizedDescription)")
                } else if success {
                    self.logger.info("后台投递已注册: \(type.identifier)")
                }
            }
        }

        // 睡眠类型
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            store.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { success, error in
                if let error {
                    self.logger.error("后台投递注册失败 [sleep]: \(error.localizedDescription)")
                } else if success {
                    self.logger.info("后台投递已注册: sleepAnalysis")
                }
            }
        }
    }

    // MARK: - Observer Query（监听数据变更）

    /// 启动所有 Observer Query，当 HealthKit 有新数据时触发 Anchored Object Query
    func startObserving() {
        for type in backgroundQuantityTypes {
            startObserverQuery(for: type)
        }

        // 睡眠
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            startSleepObserverQuery(for: sleepType)
        }

        logger.info("所有 Observer Query 已启动")
    }

    private func startObserverQuery(for type: HKQuantityType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self, error == nil else {
                completionHandler()
                return
            }

            self.logger.debug("Observer 触发: \(type.identifier)")

            Task {
                await self.performAnchoredQuery(for: type)
                completionHandler()
            }
        }
        store.execute(query)
    }

    private func startSleepObserverQuery(for type: HKCategoryType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self, error == nil else {
                completionHandler()
                return
            }

            self.logger.debug("Observer 触发: sleepAnalysis")

            Task {
                await self.performSleepAnchoredQuery(for: type)
                completionHandler()
            }
        }
        store.execute(query)
    }

    // MARK: - Anchored Object Query（增量采集）

    /// 对量化类型执行增量查询，将新数据写入 SwiftData
    @MainActor
    private func performAnchoredQuery(for type: HKQuantityType) async {
        let anchor = anchors[type.identifier]

        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            anchor: anchor
        )

        do {
            let results = try await descriptor.result(for: store)

            // 更新锚点
            anchors[type.identifier] = results.newAnchor
            saveAnchors()

            guard !results.addedSamples.isEmpty else { return }

            logger.info("增量采集 \(type.identifier): \(results.addedSamples.count) 条新数据")

            // 转换并写入 SwiftData
            var affectedDates: Set<Date> = []
            let records = results.addedSamples.map { sample in
                let metricType = self.metricType(for: type)
                let value = self.extractValue(from: sample, type: type)
                let source = sample.sourceRevision.source.name
                let sampleDate = Calendar.current.startOfDay(for: sample.startDate)
                affectedDates.insert(sampleDate)
                return HealthRecord(
                    metricType: metricType,
                    value: value,
                    timestamp: sample.startDate,
                    source: source,
                    sampleUUID: sample.uuid.uuidString
                )
            }

            await saveRecords(records)

            // 更新所有受影响日期的 DailySummary（而非仅更新今天）
            for date in affectedDates {
                await updateDailySummary(for: date)
            }

            // 心率异常检测：静息心率数据到达时触发
            #if os(iOS)
            if type.identifier == HKQuantityTypeIdentifier.restingHeartRate.rawValue,
               let latestSample = results.addedSamples.last {
                let bpm = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                HeartRateAlertService.shared.checkHeartRate(bpm)
            }
            #endif

            // 数据更新后推送到 OpenClaw (iPhone) 或同步到 iPhone (Watch)
            #if os(iOS)
            OpenClawBridge.shared.checkAndPushIfNeeded()
            #elseif os(watchOS)
            pushHealthSnapshotToiPhone()
            #endif

        } catch {
            logger.error("Anchored Query 失败 [\(type.identifier)]: \(error.localizedDescription)")
        }
    }

    /// 睡眠数据的增量查询 — 按阶段分别记录（深睡/REM/核心/总睡眠）
    @MainActor
    private func performSleepAnchoredQuery(for type: HKCategoryType) async {
        let anchor = anchors[type.identifier]

        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.categorySample(type: type)],
            anchor: anchor
        )

        do {
            let results = try await descriptor.result(for: store)

            anchors[type.identifier] = results.newAnchor
            saveAnchors()

            guard !results.addedSamples.isEmpty else { return }

            logger.info("增量采集 sleep: \(results.addedSamples.count) 条新数据")

            var records: [HealthRecord] = []
            var affectedDates: Set<Date> = []

            for sample in results.addedSamples {
                let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)

                // 只记录实际睡眠阶段，忽略 inBed/awake
                guard sleepValue == .asleepCore || sleepValue == .asleepDeep ||
                      sleepValue == .asleepREM || sleepValue == .asleepUnspecified else {
                    continue
                }

                let durationMinutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
                let source = sample.sourceRevision.source.name
                let baseUUID = sample.uuid.uuidString

                // 总睡眠记录
                records.append(HealthRecord(
                    metricType: .sleepAnalysis,
                    value: durationMinutes,
                    timestamp: sample.startDate,
                    source: source,
                    sampleUUID: "\(baseUUID)-sleep"
                ))

                // 按阶段记录（使用 HKSample UUID + 阶段后缀保证唯一性）
                switch sleepValue {
                case .asleepDeep:
                    records.append(HealthRecord(
                        metricType: .sleepDeep,
                        value: durationMinutes,
                        timestamp: sample.startDate,
                        source: source,
                        sampleUUID: "\(baseUUID)-deep"
                    ))
                case .asleepREM:
                    records.append(HealthRecord(
                        metricType: .sleepREM,
                        value: durationMinutes,
                        timestamp: sample.startDate,
                        source: source,
                        sampleUUID: "\(baseUUID)-rem"
                    ))
                case .asleepCore:
                    records.append(HealthRecord(
                        metricType: .sleepCore,
                        value: durationMinutes,
                        timestamp: sample.startDate,
                        source: source,
                        sampleUUID: "\(baseUUID)-core"
                    ))
                default:
                    break // asleepUnspecified — 只计入总睡眠
                }

                // 睡眠归属到醒来日期（凌晨的睡眠归今天）
                let attributionDate = Calendar.current.startOfDay(for: sample.endDate)
                affectedDates.insert(attributionDate)
            }

            await saveRecords(records)

            // 更新所有受影响日期的 DailySummary
            for date in affectedDates {
                await updateDailySummary(for: date)
            }

            // 数据更新后推送到 OpenClaw (iPhone) 或同步到 iPhone (Watch)
            #if os(iOS)
            OpenClawBridge.shared.checkAndPushIfNeeded()
            #elseif os(watchOS)
            pushHealthSnapshotToiPhone()
            #endif

        } catch {
            logger.error("Sleep Anchored Query 失败: \(error.localizedDescription)")
        }
    }

    // MARK: - SwiftData 写入

    /// 批量写入 HealthRecord
    @MainActor
    private func saveRecords(_ records: [HealthRecord]) async {
        guard let container = modelContainer, !records.isEmpty else { return }

        let context = container.mainContext
        for record in records {
            context.insert(record)
        }

        do {
            try context.save()
            logger.info("已写入 \(records.count) 条 HealthRecord")
        } catch {
            logger.error("SwiftData 写入失败: \(error.localizedDescription)")
        }
    }

    /// 更新指定日期的 DailySummary
    /// 对累计型指标（步数、卡路里、运动分钟）直接从 HealthKit 查询去重后的统计值，
    /// 避免 iPhone + Apple Watch 重复样本导致双倍计数
    @MainActor
    func updateDailySummary(for date: Date) async {
        guard let container = modelContainer else { return }

        let context = container.mainContext
        let dateString = DailySummary.dateFormatter.string(from: date)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // 查找或创建当天的 DailySummary
        let predicate = #Predicate<DailySummary> { $0.dateString == dateString }
        let descriptor = FetchDescriptor<DailySummary>(predicate: predicate)

        let summary: DailySummary
        if let existing = try? context.fetch(descriptor).first {
            summary = existing
        } else {
            summary = DailySummary(date: date)
            context.insert(summary)
        }

        // 从 HealthRecord 聚合非累计型数据（心率、HRV 等取均值/极值即可）
        let recordPredicate = #Predicate<HealthRecord> {
            $0.timestamp >= startOfDay && $0.timestamp < endOfDay
        }
        let recordDescriptor = FetchDescriptor<HealthRecord>(predicate: recordPredicate)

        guard let records = try? context.fetch(recordDescriptor) else { return }

        // 按类型分组
        let hrRecords = records.filter { $0.metricType == HealthMetricType.heartRate.rawValue }
        let hrvRecords = records.filter { $0.metricType == HealthMetricType.heartRateVariability.rawValue }
        let restingHRRecords = records.filter { $0.metricType == HealthMetricType.restingHeartRate.rawValue }
        let spo2Records = records.filter { $0.metricType == HealthMetricType.bloodOxygen.rawValue }

        // 心率聚合（均值/极值，不存在重复计数问题）
        if !hrRecords.isEmpty {
            let values = hrRecords.map(\.value)
            summary.averageHeartRate = values.reduce(0, +) / Double(values.count)
            summary.minHeartRate = values.min()
            summary.maxHeartRate = values.max()
        }

        // 静息心率（取最新值）
        if let latest = restingHRRecords.sorted(by: { $0.timestamp > $1.timestamp }).first {
            summary.restingHeartRate = latest.value
        }

        // HRV 均值
        if !hrvRecords.isEmpty {
            let values = hrvRecords.map(\.value)
            summary.averageHRV = values.reduce(0, +) / Double(values.count)
        }

        // 血氧
        if !spo2Records.isEmpty {
            let values = spo2Records.map(\.value)
            summary.averageBloodOxygen = values.reduce(0, +) / Double(values.count)
            summary.minBloodOxygen = values.min()
        }

        // ---- 累计型指标：从 HealthKit 直接查询去重后的统计值 ----
        let hkPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)

        // 步数（HealthKit 自动去重 iPhone + Watch 重叠样本）
        if let steps = await fetchStatisticsSum(type: HKQuantityType(.stepCount), predicate: hkPredicate, unit: .count()) {
            summary.totalSteps = Int(steps)
        }

        // 活跃卡路里
        if let activeCal = await fetchStatisticsSum(type: HKQuantityType(.activeEnergyBurned), predicate: hkPredicate, unit: .kilocalorie()) {
            summary.activeCalories = activeCal
        }

        // 静息卡路里
        if let restingCal = await fetchStatisticsSum(type: HKQuantityType(.basalEnergyBurned), predicate: hkPredicate, unit: .kilocalorie()) {
            summary.restingCalories = restingCal
        }

        // 运动分钟（Apple Watch appleExerciseTime）
        if let exerciseMin = await fetchStatisticsSum(type: HKQuantityType(.appleExerciseTime), predicate: hkPredicate, unit: .minute()) {
            summary.exerciseMinutes = exerciseMin
        }

        // ---- 睡眠：按阶段聚合 ----
        let sleepRecords = records.filter { $0.metricType == HealthMetricType.sleepAnalysis.rawValue }
        let deepRecords = records.filter { $0.metricType == HealthMetricType.sleepDeep.rawValue }
        let remRecords = records.filter { $0.metricType == HealthMetricType.sleepREM.rawValue }
        let coreRecords = records.filter { $0.metricType == HealthMetricType.sleepCore.rawValue }

        if !sleepRecords.isEmpty {
            summary.sleepDurationMinutes = Int(sleepRecords.map(\.value).reduce(0, +))
        }
        if !deepRecords.isEmpty {
            summary.deepSleepMinutes = Int(deepRecords.map(\.value).reduce(0, +))
        }
        if !remRecords.isEmpty {
            summary.remSleepMinutes = Int(remRecords.map(\.value).reduce(0, +))
        }
        if !coreRecords.isEmpty {
            summary.coreSleepMinutes = Int(coreRecords.map(\.value).reduce(0, +))
        }

        // 计算每日评分
        summary.dailyScore = calculateScore(from: summary)
        summary.lastUpdated = .now

        do {
            try context.save()
            logger.info("DailySummary 已更新: \(dateString), 评分: \(summary.dailyScore ?? 0)")
        } catch {
            logger.error("DailySummary 保存失败: \(error.localizedDescription)")
        }
    }

    /// 从 HealthKit 查询指定类型的去重累计值（HKStatisticsQuery 自动处理多源去重）
    private func fetchStatisticsSum(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async -> Double? {
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        do {
            let result = try await descriptor.result(for: store)
            return result?.sumQuantity()?.doubleValue(for: unit)
        } catch {
            logger.error("Statistics Query 失败 [\(type.identifier)]: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 手动触发全量采集（首次启动或需要补数据时）

    @MainActor
    func performInitialFetch() async {
        for type in backgroundQuantityTypes {
            await performAnchoredQuery(for: type)
        }
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            await performSleepAnchoredQuery(for: sleepType)
        }
        logger.info("初始全量采集完成")
        Analytics.trackHealthDataSync()
    }

    // MARK: - Watch → iPhone Health Sync

    #if os(watchOS)
    /// Push latest Watch HealthKit data to iPhone via WatchConnectivity.
    /// Called after observer queries produce new data on the Watch side.
    @MainActor
    private func pushHealthSnapshotToiPhone() {
        guard let container = modelContainer else { return }
        let context = container.mainContext

        let today = Calendar.current.startOfDay(for: Date())
        let dateString = DailySummary.dateFormatter.string(from: today)
        let predicate = #Predicate<DailySummary> { $0.dateString == dateString }
        let descriptor = FetchDescriptor<DailySummary>(predicate: predicate)

        guard let summary = try? context.fetch(descriptor).first else { return }

        WatchConnectivityManager.shared.sendHealthSnapshot(
            heartRate: summary.averageHeartRate,
            hrv: summary.averageHRV,
            restingHeartRate: summary.restingHeartRate,
            steps: summary.totalSteps,
            activeCalories: summary.activeCalories,
            sleepMinutes: summary.sleepDurationMinutes
        )
    }
    #endif

    // MARK: - 辅助方法

    /// HealthKit 类型 → HealthMetricType 映射
    private func metricType(for hkType: HKQuantityType) -> HealthMetricType {
        switch hkType.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return .heartRate
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            return .heartRateVariability
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            return .restingHeartRate
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return .bloodOxygen
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .stepCount
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return .activeCalories
        case HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return .restingCalories
        case HKQuantityTypeIdentifier.appleExerciseTime.rawValue:
            return .exerciseTime
        default:
            return .heartRate // 不应到达
        }
    }

    /// 从 HKQuantitySample 提取数值（根据类型使用对应单位）
    private func extractValue(from sample: HKQuantitySample, type: HKQuantityType) -> Double {
        switch type.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            return sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            return sample.quantity.doubleValue(for: .secondUnit(with: .milli))
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return sample.quantity.doubleValue(for: .percent()) * 100
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return sample.quantity.doubleValue(for: .count())
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return sample.quantity.doubleValue(for: .kilocalorie())
        case HKQuantityTypeIdentifier.appleExerciseTime.rawValue:
            return sample.quantity.doubleValue(for: .minute())
        default:
            return 0
        }
    }

    /// 基于 DailySummary 计算评分 — delegates to ScoreEngine for consistency
    private func calculateScore(from summary: DailySummary) -> Int {
        ScoreEngine.calculateScore(
            hrv: summary.averageHRV,
            restingHR: summary.restingHeartRate,
            bloodOxygen: summary.averageBloodOxygen,
            sleepMinutes: summary.sleepDurationMinutes ?? 0
        )
    }

    // MARK: - 锚点持久化

    private func loadAnchors() {
        guard let data = UserDefaults.standard.dictionary(forKey: anchorDefaultsKey) else { return }
        for (key, value) in data {
            if let anchorData = value as? Data,
               let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData) {
                anchors[key] = anchor
            }
        }
    }

    private func saveAnchors() {
        var data: [String: Data] = [:]
        for (key, anchor) in anchors {
            if let anchorData = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
                data[key] = anchorData
            }
        }
        UserDefaults.standard.set(data, forKey: anchorDefaultsKey)
    }
}
