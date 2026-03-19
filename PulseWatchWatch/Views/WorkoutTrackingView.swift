import SwiftUI
import HealthKit

/// 训练进行中 + 训练结束摘要界面
struct WorkoutTrackingView: View {

    @State private var manager = WorkoutSessionManager.shared
    @State private var appeared = false

    /// 初始运动类型（从外部传入）
    var initialType: WorkoutSessionManager.WorkoutType = .strength

    /// 关闭回调
    var onClose: () -> Void = {}

    var body: some View {
        Group {
            switch manager.state {
            case .idle:
                // 选择运动类型
                workoutPicker
            case .running, .paused:
                activeWorkoutView
            case .ended:
                workoutSummary
            }
        }
        .containerBackground(
            LinearGradient(
                colors: [Color(hex: "0D0C0B"), Color(hex: "111010")],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigation
        )
        .onAppear {
            if manager.state == .idle {
                // 自动开始
                manager.startWorkout(type: initialType)
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - 运动类型选择器

    private var workoutPicker: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Choose Workout")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                ForEach(WorkoutSessionManager.WorkoutType.allCases, id: \.label) { type in
                    Button {
                        manager.startWorkout(type: type)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(PulseTheme.accent)
                                .frame(width: 28)

                            Text(type.label)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(PulseTheme.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(PulseTheme.cardBackground)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 训练进行中

    private var activeWorkoutView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // 运动类型图标
                workoutTypeIcon
                    .opacity(appeared ? 1 : 0)

                // 大号心率
                heartRateDisplay
                    .opacity(appeared ? 1 : 0)

                // 心率区间指示条
                heartRateZoneBar
                    .opacity(appeared ? 1 : 0)

                // 时长 + 卡路里
                metricsRow
                    .opacity(appeared ? 1 : 0)

                // 控制按钮
                controlButtons
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 运动类型图标

    private var workoutTypeIcon: some View {
        let type = WorkoutSessionManager.WorkoutType.allCases.first {
            $0.activityType == manager.currentWorkoutType
        } ?? .strength

        return HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 11))
                .foregroundStyle(PulseTheme.accent)
            Text(type.label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(PulseTheme.cardBackground)
        )
    }

    // MARK: - 心率显示

    private var heartRateDisplay: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: manager.currentZone.color))
                    .symbolEffect(.pulse, options: .repeating, isActive: manager.state == .running)

                Text(manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: Int(manager.heartRate))

                Text("bpm")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Text(manager.currentZone.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: manager.currentZone.color))
        }
    }

    // MARK: - 心率区间指示条

    private var heartRateZoneBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(WorkoutSessionManager.HeartRateZone.allCases, id: \.rawValue) { zone in
                    let isActive = zone == manager.currentZone
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: zone.color).opacity(isActive ? 1.0 : 0.25))
                        .frame(height: isActive ? 8 : 5)
                        .animation(.spring(response: 0.3), value: manager.currentZone)
                }
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 8)
    }

    // MARK: - 时长 & 卡路里

    private var metricsRow: some View {
        HStack(spacing: 16) {
            // 时长
            VStack(spacing: 1) {
                Text(manager.formattedDuration)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .monospacedDigit()
                Text("Duration")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            // 分隔
            Rectangle()
                .fill(PulseTheme.border)
                .frame(width: 1, height: 24)

            // 卡路里
            VStack(spacing: 1) {
                Text(manager.formattedCalories)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .contentTransition(.numericText())
                Text("kcal")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
    }

    // MARK: - 控制按钮

    private var controlButtons: some View {
        HStack(spacing: 12) {
            // 暂停/恢复
            Button {
                manager.togglePause()
            } label: {
                Image(systemName: manager.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle().fill(PulseTheme.cardElevated)
                    )
            }
            .buttonStyle(.plain)

            // 结束
            Button {
                manager.endWorkout()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "0D0C0B"))
                    .frame(width: 48, height: 48)
                    .background(
                        Circle().fill(PulseTheme.activityAccent)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 训练结束摘要

    private var workoutSummary: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 标题
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(PulseTheme.statusGood)

                    Text("Workout Complete")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                }

                // 统计数据
                summaryGrid

                // 心率区间分布
                zoneDistribution

                // 保存按钮
                Button {
                    manager.reset()
                    onClose()
                } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "0D0C0B"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(PulseTheme.accent)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 摘要网格

    private var summaryGrid: some View {
        let items: [(String, String, String, String)] = [
            ("clock", String(localized: "Duration"), manager.formattedDuration, "9A938C"),
            ("heart.fill", String(localized: "Avg Heart Rate"), "\(Int(manager.averageHeartRate))", "C75C5C"),
            ("heart.fill", String(localized: "Max Heart Rate"), "\(Int(manager.maxHeartRateRecorded))", "9B3D3D"),
            ("flame.fill", String(localized: "Active kcal"), manager.formattedCalories, "D4A056"),
        ]

        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(items, id: \.1) { icon, label, value, color in
                VStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: color))
                    Text(value)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                    Text(label)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PulseTheme.cardBackground)
                )
            }
        }
    }

    // MARK: - 心率区间分布

    private var zoneDistribution: some View {
        let totalSeconds = max(manager.elapsedSeconds, 1)

        return VStack(alignment: .leading, spacing: 6) {
            Text("Heart Rate Zone")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)

            ForEach(WorkoutSessionManager.HeartRateZone.allCases, id: \.rawValue) { zone in
                let seconds = manager.zoneSeconds[zone] ?? 0
                let pct = Double(seconds) / Double(totalSeconds)

                HStack(spacing: 6) {
                    Text(zone.label)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: zone.color))
                        .frame(width: 24, alignment: .leading)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: zone.color))
                            .frame(width: max(geo.size.width * pct, 2))
                    }
                    .frame(height: 6)

                    Text(formatZoneTime(seconds))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
    }

    // MARK: - 工具

    private func formatZoneTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
}

#Preview {
    WorkoutTrackingView()
}
