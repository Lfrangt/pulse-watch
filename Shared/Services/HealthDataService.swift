import Foundation
import SwiftData
import os

/// 统一健康数据读取 API
/// 上层（Morning Brief、Complication、AI 引擎）全部从此 Service 读取
/// 数据源：SwiftData（由 HealthKitService 负责写入）
@Observable
final class HealthDataService {

    static let shared = HealthDataService()

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "HealthDataService")

    /// SwiftData ModelContainer — 由 App 启动时注入
    var modelContainer: ModelContainer?

    private init() {}

    // MARK: - 今日摘要

    /// 获取今天的 DailySummary
    @MainActor
    func fetchTodaySummary() -> DailySummary? {
        guard let container = modelContainer else { return nil }

        let context = container.mainContext
        let today = DailySummary.dateFormatter.string(from: Date())
        let predicate = #Predicate<DailySummary> { $0.dateString == today }
        let descriptor = FetchDescriptor<DailySummary>(predicate: predicate)

        return try? context.fetch(descriptor).first
    }

    // MARK: - 周趋势

    /// 获取过去 N 天的 DailySummary（默认 7 天）
    @MainActor
    func fetchWeekTrend(days: Int = 7) -> [DailySummary] {
        guard let container = modelContainer else { return [] }

        let context = container.mainContext
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let startOfDay = Calendar.current.startOfDay(for: startDate)

        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay }
        var descriptor = FetchDescriptor<DailySummary>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 最新生命体征

    /// 获取最新的关键生命体征（心率、HRV、血氧、静息心率）
    @MainActor
    func getLatestVitals() -> LatestVitals {
        guard let container = modelContainer else { return LatestVitals() }

        let context = container.mainContext

        return LatestVitals(
            heartRate: fetchLatestRecord(context: context, type: .heartRate)?.value,
            hrv: fetchLatestRecord(context: context, type: .heartRateVariability)?.value,
            restingHeartRate: fetchLatestRecord(context: context, type: .restingHeartRate)?.value,
            bloodOxygen: fetchLatestRecord(context: context, type: .bloodOxygen)?.value,
            steps: fetchLatestRecord(context: context, type: .stepCount).map { Int($0.value) },
            activeCalories: fetchLatestRecord(context: context, type: .activeCalories)?.value,
            lastUpdated: fetchLatestRecord(context: context, type: .heartRate)?.timestamp
        )
    }

    // MARK: - 按类型查询记录

    /// 获取指定类型在时间范围内的所有记录
    @MainActor
    func fetchRecords(
        type: HealthMetricType,
        from startDate: Date,
        to endDate: Date = .now
    ) -> [HealthRecord] {
        guard let container = modelContainer else { return [] }

        let context = container.mainContext
        let typeRaw = type.rawValue
        let predicate = #Predicate<HealthRecord> {
            $0.metricType == typeRaw &&
            $0.timestamp >= startDate &&
            $0.timestamp <= endDate
        }
        var descriptor = FetchDescriptor<HealthRecord>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 评分趋势

    /// 获取过去 N 天的每日评分
    @MainActor
    func fetchScoreTrend(days: Int = 7) -> [(date: Date, score: Int)] {
        return fetchWeekTrend(days: days).compactMap { summary in
            guard let score = summary.dailyScore else { return nil }
            return (date: summary.date, score: score)
        }
    }

    // MARK: - 异常检测

    /// 检查是否有健康异常（HRV 骤降、心率异常升高等）
    @MainActor
    func checkAnomalies() -> [HealthAnomaly] {
        var anomalies: [HealthAnomaly] = []
        let trend = fetchWeekTrend(days: 7)

        guard trend.count >= 3 else { return anomalies }

        // 检查 HRV 骤降
        let recentHRVs = trend.compactMap(\.averageHRV)
        if recentHRVs.count >= 3 {
            let average = recentHRVs.dropLast().reduce(0, +) / Double(recentHRVs.count - 1)
            if let latest = recentHRVs.last, latest < average * 0.7 {
                anomalies.append(.hrvDrop(current: latest, baseline: average))
            }
        }

        // 检查静息心率异常升高
        let recentRHRs = trend.compactMap(\.restingHeartRate)
        if recentRHRs.count >= 3 {
            let average = recentRHRs.dropLast().reduce(0, +) / Double(recentRHRs.count - 1)
            if let latest = recentRHRs.last, latest > average * 1.15 {
                anomalies.append(.elevatedRestingHR(current: latest, baseline: average))
            }
        }

        // 检查连续差睡眠
        let recentSleep = trend.suffix(3).compactMap(\.sleepDurationMinutes)
        if recentSleep.count == 3 && recentSleep.allSatisfy({ $0 < 360 }) {
            anomalies.append(.poorSleepStreak(nights: 3))
        }

        return anomalies
    }

    // MARK: - Workout History

    /// Fetch recent workout entries (last N days)
    @MainActor
    func fetchRecentWorkouts(days: Int = 7) -> [WorkoutHistoryEntry] {
        guard let container = modelContainer else { return [] }

        let context = container.mainContext
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        let predicate = #Predicate<WorkoutHistoryEntry> { $0.startDate >= startDate }
        var descriptor = FetchDescriptor<WorkoutHistoryEntry>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.startDate, order: .reverse)]
        descriptor.fetchLimit = 20

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Private Helpers

    /// 获取指定类型的最新一条记录
    private func fetchLatestRecord(context: ModelContext, type: HealthMetricType) -> HealthRecord? {
        let typeRaw = type.rawValue
        let predicate = #Predicate<HealthRecord> { $0.metricType == typeRaw }
        var descriptor = FetchDescriptor<HealthRecord>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchLimit = 1

        return try? context.fetch(descriptor).first
    }
}

// MARK: - 数据结构

/// 最新生命体征快照
struct LatestVitals {
    var heartRate: Double?
    var hrv: Double?
    var restingHeartRate: Double?
    var bloodOxygen: Double?
    var steps: Int?
    var activeCalories: Double?
    var lastUpdated: Date?

    /// 数据是否有效（至少有心率数据）
    var isValid: Bool { heartRate != nil }
}

/// 健康异常类型
enum HealthAnomaly {
    case hrvDrop(current: Double, baseline: Double)
    case elevatedRestingHR(current: Double, baseline: Double)
    case poorSleepStreak(nights: Int)

    var message: String {
        switch self {
        case .hrvDrop(let current, let baseline):
            return "HRV drop: \(Int(current))ms vs baseline \(Int(baseline))ms"
        case .elevatedRestingHR(let current, let baseline):
            return "RHR elevated: \(Int(current))bpm vs baseline \(Int(baseline))bpm"
        case .poorSleepStreak(let nights):
            return "\(nights) nights under 6h sleep"
        }
    }

    var severity: AnomalySeverity {
        switch self {
        case .hrvDrop: return .warning
        case .elevatedRestingHR: return .warning
        case .poorSleepStreak: return .alert
        }
    }
}

enum AnomalySeverity {
    case info, warning, alert
}
