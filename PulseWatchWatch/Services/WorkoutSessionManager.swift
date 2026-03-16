import Foundation
import HealthKit
import WatchKit

/// Watch 训练 Session 管理器
/// 使用 HKWorkoutSession + HKLiveWorkoutBuilder 实时采集心率、卡路里、时长
@Observable
final class WorkoutSessionManager: NSObject {

    static let shared = WorkoutSessionManager()

    // MARK: - 训练状态

    enum SessionState {
        case idle           // 未开始
        case running        // 进行中
        case paused         // 已暂停
        case ended          // 已结束（显示摘要）
    }

    private(set) var state: SessionState = .idle

    // MARK: - 实时数据

    private(set) var heartRate: Double = 0
    private(set) var activeCalories: Double = 0
    private(set) var elapsedSeconds: Int = 0
    private(set) var currentWorkoutType: HKWorkoutActivityType = .traditionalStrengthTraining

    // MARK: - 心率区间（基于最大心率 220 - 年龄，默认 190）

    enum HeartRateZone: Int, CaseIterable {
        case warmup = 1     // < 60% — 热身
        case fatBurn = 2    // 60-70% — 燃脂
        case cardio = 3     // 70-80% — 有氧
        case anaerobic = 4  // 80-90% — 无氧
        case peak = 5       // 90%+   — 极限

        var label: String {
            switch self {
            case .warmup:    return "Warm-up"
            case .fatBurn:   return "Fat Burn"
            case .cardio:    return "Cardio"
            case .anaerobic: return "Anaerobic"
            case .peak:      return "Peak"
            }
        }

        var color: String {
            switch self {
            case .warmup:    return "7FB069"  // 绿
            case .fatBurn:   return "C9A96E"  // 金
            case .cardio:    return "D4A056"  // 橙
            case .anaerobic: return "C75C5C"  // 红
            case .peak:      return "9B3D3D"  // 深红
            }
        }
    }

    private(set) var currentZone: HeartRateZone = .warmup
    private var maxHeartRate: Double = 190 // 默认值，可根据年龄调整

    // MARK: - 心率区间时间分布（秒）

    private(set) var zoneSeconds: [HeartRateZone: Int] = [
        .warmup: 0, .fatBurn: 0, .cardio: 0, .anaerobic: 0, .peak: 0
    ]

    // MARK: - 训练摘要

    private(set) var averageHeartRate: Double = 0
    private(set) var maxHeartRateRecorded: Double = 0
    private var heartRateReadings: [Double] = []

    // MARK: - 私有属性

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?

    // MARK: - 支持的运动类型

    enum WorkoutType: CaseIterable {
        case strength
        case running
        case cycling
        case yoga
        case hiit

        var activityType: HKWorkoutActivityType {
            switch self {
            case .strength: return .traditionalStrengthTraining
            case .running:  return .running
            case .cycling:  return .cycling
            case .yoga:     return .yoga
            case .hiit:     return .highIntensityIntervalTraining
            }
        }

        var label: String {
            switch self {
            case .strength: return "Strength"
            case .running:  return "Running"
            case .cycling:  return "Cycling"
            case .yoga:     return "Yoga"
            case .hiit:     return "HIIT"
            }
        }

        var icon: String {
            switch self {
            case .strength: return "dumbbell.fill"
            case .running:  return "figure.run"
            case .cycling:  return "bicycle"
            case .yoga:     return "figure.mind.and.body"
            case .hiit:     return "bolt.heart.fill"
            }
        }
    }

    // MARK: - 开始训练

    func startWorkout(type: WorkoutType) {
        guard state == .idle || state == .ended else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = type.activityType
        config.locationType = type == .running || type == .cycling ? .outdoor : .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            print("WorkoutSession 创建失败: \(error)")
            return
        }

        guard let session, let builder else { return }

        session.delegate = self
        builder.delegate = self

        // 实时数据源
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )

        // 重置状态
        currentWorkoutType = type.activityType
        heartRate = 0
        activeCalories = 0
        elapsedSeconds = 0
        heartRateReadings = []
        maxHeartRateRecorded = 0
        averageHeartRate = 0
        currentZone = .warmup
        zoneSeconds = [.warmup: 0, .fatBurn: 0, .cardio: 0, .anaerobic: 0, .peak: 0]

        // 启动
        let startDate = Date()
        session.startActivity(with: startDate)
        builder.beginCollection(withStart: startDate) { _, _ in }

        state = .running
        startTimer()

        // 触觉反馈
        HapticManager.workoutStarted()

        // 埋点
        Analytics.trackWorkoutStart(type: type.label)
    }

    // MARK: - 暂停/恢复

    func pause() {
        guard state == .running else { return }
        session?.pause()
        state = .paused
        stopTimer()
        HapticManager.tap()
    }

    func resume() {
        guard state == .paused else { return }
        session?.resume()
        state = .running
        startTimer()
        HapticManager.tap()
    }

    func togglePause() {
        if state == .running { pause() }
        else if state == .paused { resume() }
    }

    // MARK: - 结束训练

    func endWorkout() {
        guard state == .running || state == .paused else { return }

        session?.end()
        stopTimer()

        // 计算摘要
        if !heartRateReadings.isEmpty {
            averageHeartRate = heartRateReadings.reduce(0, +) / Double(heartRateReadings.count)
        }

        // 保存到 HealthKit
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, error in
                if let error {
                    print("保存 workout 失败: \(error)")
                }
            }
        }

        state = .ended
        HapticManager.workoutStopped()

        // 埋点
        Analytics.trackWorkoutComplete(type: "\(currentWorkoutType.rawValue)", durationMinutes: elapsedSeconds / 60)
    }

    // MARK: - 重置（返回空闲）

    func reset() {
        state = .idle
        session = nil
        builder = nil
    }

    // MARK: - 计时器

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.state == .running else { return }
            self.elapsedSeconds += 1
            // 每秒更新心率区间累积
            self.zoneSeconds[self.currentZone, default: 0] += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 心率区间计算

    private func updateHeartRateZone() {
        let pct = heartRate / maxHeartRate
        switch pct {
        case ..<0.6:     currentZone = .warmup
        case 0.6..<0.7:  currentZone = .fatBurn
        case 0.7..<0.8:  currentZone = .cardio
        case 0.8..<0.9:  currentZone = .anaerobic
        default:         currentZone = .peak
        }
    }

    // MARK: - 格式化

    var formattedDuration: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var formattedCalories: String {
        if activeCalories >= 1000 {
            return String(format: "%.1fk", activeCalories / 1000)
        }
        return "\(Int(activeCalories))"
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutSessionManager: HKWorkoutSessionDelegate {

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // 状态由 start/pause/resume/end 方法管理
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("WorkoutSession 错误: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // 事件（如暂停/恢复标记）
    }

    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // 实时数据更新
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            let stats = workoutBuilder.statistics(for: quantityType)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch quantityType {
                case HKQuantityType(.heartRate):
                    if let bpm = stats?.mostRecentQuantity()?.doubleValue(
                        for: HKUnit.count().unitDivided(by: .minute())
                    ) {
                        self.heartRate = bpm
                        self.heartRateReadings.append(bpm)
                        if bpm > self.maxHeartRateRecorded {
                            self.maxHeartRateRecorded = bpm
                        }
                        self.updateHeartRateZone()
                    }

                case HKQuantityType(.activeEnergyBurned):
                    if let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.activeCalories = kcal
                    }

                default:
                    break
                }
            }
        }
    }
}
