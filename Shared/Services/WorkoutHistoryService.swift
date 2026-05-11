import Foundation
import HealthKit
import SwiftData
import os

/// 训练历史同步服务 — 从 HealthKit 同步 HKWorkout 到 SwiftData
/// 自动去重，支持增量同步和心率区间计算
final class WorkoutHistoryService {

    static let shared = WorkoutHistoryService()

    private let store = HKHealthStore()
    private let logger = Logger(subsystem: "com.abundra.pulse", category: "WorkoutHistory")

    /// SwiftData ModelContainer — 由 App 启动时注入
    var modelContainer: ModelContainer?

    private init() {}

    // MARK: - 同步入口

    /// 同步最近 90 天的 HKWorkout 到本地数据库
    @MainActor
    func syncWorkouts() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let container = modelContainer else {
            logger.warning("ModelContainer 未注入，跳过同步")
            return
        }

        let workoutType = HKWorkoutType.workoutType()
        let hrType = HKQuantityType(.heartRate)

        do {
            try await store.requestAuthorization(toShare: [], read: [workoutType, hrType])
        } catch {
            logger.error("HealthKit 授权失败: \(error.localizedDescription)")
            return
        }

        // 查询最近 90 天
        let calendar = Calendar.current
        guard let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: .now) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: ninetyDaysAgo, end: .now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 200
        )

        do {
            let hkWorkouts = try await descriptor.result(for: store)
            logger.info("HealthKit 查询到 \(hkWorkouts.count) 条训练记录")

            let context = container.mainContext

            // 获取 90 天内已有记录的 UUID 集合，用于去重（不加载全部历史）
            var existingDescriptor = FetchDescriptor<WorkoutHistoryEntry>(
                predicate: #Predicate { $0.startDate >= ninetyDaysAgo }
            )
            existingDescriptor.propertiesToFetch = [\.hkWorkoutUUID]
            let existing = (try? context.fetch(existingDescriptor)) ?? []
            let existingUUIDs = Set(existing.map(\.hkWorkoutUUID))

            var newCount = 0

            for hkWorkout in hkWorkouts {
                let uuidString = hkWorkout.uuid.uuidString

                // 跳过已同步的
                guard !existingUUIDs.contains(uuidString) else { continue }

                let entry = WorkoutHistoryEntry(
                    hkWorkoutUUID: uuidString,
                    activityType: Int(hkWorkout.workoutActivityType.rawValue),
                    startDate: hkWorkout.startDate,
                    endDate: hkWorkout.endDate,
                    durationSeconds: hkWorkout.duration,
                    totalCalories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                    totalDistance: hkWorkout.totalDistance?.doubleValue(for: .meter()),
                    sourceName: hkWorkout.sourceRevision.source.name
                )

                // 异步获取心率数据
                let hrData = await fetchHeartRateData(for: hkWorkout)
                entry.averageHeartRate = hrData.average
                entry.maxHeartRate = hrData.max
                entry.heartRateZones = hrData.zones

                context.insert(entry)
                newCount += 1
            }

            if newCount > 0 {
                try context.save()
                logger.info("新增 \(newCount) 条训练历史记录")
            } else {
                logger.info("无新训练记录需要同步")
            }

        } catch {
            logger.error("训练同步失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 心率数据提取

    private struct HeartRateResult {
        var average: Double?
        var max: Double?
        var zones: [HRZoneEntry]
    }

    /// 获取指定训练期间的心率采样，计算均值、最大值和区间分布
    private func fetchHeartRateData(for workout: HKWorkout) async -> HeartRateResult {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        do {
            let samples = try await descriptor.result(for: store)
            let bpmValues = samples.map {
                $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }

            guard !bpmValues.isEmpty else {
                return HeartRateResult(average: nil, max: nil, zones: [])
            }

            let avg = bpmValues.reduce(0, +) / Double(bpmValues.count)
            let maxBPM = bpmValues.max()

            // 5区间划分 — 使用用户设置的最大心率，否则从年龄估算（220-age），默认 190
            let userMaxHR = UserDefaults.standard.double(forKey: "pulse.user.maxHeartRate")
            let userAge = UserDefaults.standard.integer(forKey: "pulse.user.age")
            let maxHR: Double = userMaxHR > 0 ? userMaxHR : (userAge > 0 ? Double(220 - userAge) : 190)
            var zoneCounts = [0, 0, 0, 0, 0]
            let total = Double(bpmValues.count)

            for bpm in bpmValues {
                let pct = bpm / maxHR
                switch pct {
                case ..<0.6:    zoneCounts[0] += 1
                case 0.6..<0.7: zoneCounts[1] += 1
                case 0.7..<0.8: zoneCounts[2] += 1
                case 0.8..<0.9: zoneCounts[3] += 1
                default:        zoneCounts[4] += 1
                }
            }

            let zones: [HRZoneEntry] = [
                HRZoneEntry(name: String(localized: "Warm-up"),   percentage: Double(zoneCounts[0]) / total, colorHex: "7FB069"),
                HRZoneEntry(name: String(localized: "Fat Burn"),  percentage: Double(zoneCounts[1]) / total, colorHex: "A8C256"),
                HRZoneEntry(name: String(localized: "Cardio"),    percentage: Double(zoneCounts[2]) / total, colorHex: "D4A056"),
                HRZoneEntry(name: String(localized: "Anaerobic"), percentage: Double(zoneCounts[3]) / total, colorHex: "D47456"),
                HRZoneEntry(name: String(localized: "Peak"),      percentage: Double(zoneCounts[4]) / total, colorHex: "C75C5C"),
            ]

            return HeartRateResult(average: avg, max: maxBPM, zones: zones)
        } catch {
            logger.error("心率数据获取失败: \(error.localizedDescription)")
            return HeartRateResult(average: nil, max: nil, zones: [])
        }
    }

    // MARK: - 删除

    /// 删除指定训练记录
    @MainActor
    func deleteEntry(_ entry: WorkoutHistoryEntry) {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        context.delete(entry)
        try? context.save()
        logger.info("已删除训练记录: \(entry.activityName) @ \(entry.startDate)")
    }
}
