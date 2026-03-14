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
            let records = results.addedSamples.map { sample in
                let metricType = self.metricType(for: type)
                let value = self.extractValue(from: sample, type: type)
                let source = sample.sourceRevision.source.name
                return HealthRecord(
                    metricType: metricType,
                    value: value,
                    timestamp: sample.startDate,
                    source: source
                )
            }

            await saveRecords(records)
            await updateDailySummary(for: Date())

        } catch {
            logger.error("Anchored Query 失败 [\(type.identifier)]: \(error.localizedDescription)")
        }
    }

    /// 睡眠数据的增量查询
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

            let records = results.addedSamples.compactMap { sample -> HealthRecord? in
                let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value)

                // 只记录实际睡眠阶段，忽略 inBed/awake
                guard sleepValue == .asleepCore || sleepValue == .asleepDeep ||
                      sleepValue == .asleepREM || sleepValue == .asleepUnspecified else {
                    return nil
                }

                let durationMinutes = sample.endDate.timeIntervalSince(sample.startDate) / 60
                let source = sample.sourceRevision.source.name
                return HealthRecord(
                    metricType: .sleepAnalysis,
                    value: durationMinutes,
                    timestamp: sample.startDate,
                    source: source
                )
            }

            await saveRecords(records)
            await updateDailySummary(for: Date())

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

    /// 更新当天的 DailySummary（聚合 HealthRecord）
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

        // 从 HealthRecord 聚合数据
        let recordPredicate = #Predicate<HealthRecord> {
            $0.timestamp >= startOfDay && $0.timestamp < endOfDay
        }
        let recordDescriptor = FetchDescriptor<HealthRecord>(predicate: recordPredicate)

        guard let records = try? context.fetch(recordDescriptor) else { return }

        // 按类型分组聚合
        let hrRecords = records.filter { $0.metricType == HealthMetricType.heartRate.rawValue }
        let hrvRecords = records.filter { $0.metricType == HealthMetricType.heartRateVariability.rawValue }
        let restingHRRecords = records.filter { $0.metricType == HealthMetricType.restingHeartRate.rawValue }
        let spo2Records = records.filter { $0.metricType == HealthMetricType.bloodOxygen.rawValue }
        let stepRecords = records.filter { $0.metricType == HealthMetricType.stepCount.rawValue }
        let activeCalRecords = records.filter { $0.metricType == HealthMetricType.activeCalories.rawValue }
        let restingCalRecords = records.filter { $0.metricType == HealthMetricType.restingCalories.rawValue }
        let sleepRecords = records.filter { $0.metricType == HealthMetricType.sleepAnalysis.rawValue }

        // 心率聚合
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

        // 步数（累加）
        if !stepRecords.isEmpty {
            summary.totalSteps = Int(stepRecords.map(\.value).reduce(0, +))
        }

        // 卡路里
        if !activeCalRecords.isEmpty {
            summary.activeCalories = activeCalRecords.map(\.value).reduce(0, +)
        }
        if !restingCalRecords.isEmpty {
            summary.restingCalories = restingCalRecords.map(\.value).reduce(0, +)
        }

        // 睡眠（总分钟数）
        if !sleepRecords.isEmpty {
            summary.sleepDurationMinutes = Int(sleepRecords.map(\.value).reduce(0, +))
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
    }

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
        default:
            return 0
        }
    }

    /// 基于 DailySummary 计算评分
    private func calculateScore(from summary: DailySummary) -> Int {
        var score = 50

        if let hrv = summary.averageHRV {
            if hrv > 60 { score += 15 }
            else if hrv > 40 { score += 5 }
            else { score -= 10 }
        }

        if let rhr = summary.restingHeartRate {
            if rhr < 60 { score += 10 }
            else if rhr < 70 { score += 5 }
            else if rhr > 80 { score -= 10 }
        }

        if let sleep = summary.sleepDurationMinutes {
            if sleep > 420 { score += 15 }
            else if sleep > 360 { score += 5 }
            else if sleep < 300 { score -= 15 }
        }

        if let spo2 = summary.averageBloodOxygen {
            if spo2 >= 96 { score += 5 }
            else if spo2 < 92 { score -= 15 }
        }

        if let steps = summary.totalSteps, steps > 8000 {
            score += 5
        }

        return max(0, min(100, score))
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
