import SwiftUI

/// Watch 端摘要视图
/// 显示完整的每日健康数据：评分仪表盘 + 四项指标卡片 + 操作按钮
struct SummaryView: View {

    @State private var healthManager = HealthKitManager.shared
    @State private var connectivity = WatchConnectivityManager.shared

    @State private var score: Int = 0
    @State private var headline: String = String(localized: "加载中…")
    @State private var heartRate: Int = 0
    @State private var hrv: Double = 0
    @State private var sleepMinutes: Int = 0
    @State private var steps: Int = 0
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // MARK: - 状态评分 Gauge
                scoreGauge
                    .padding(.top, 4)

                // MARK: - 指标卡片
                metricsGrid

                // MARK: - Action 按钮
                NavigationLink {
                    WatchHomeView()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12))
                        Text("查看趋势")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(PulseTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(PulseTheme.accent.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 8)
        }
        .containerBackground(
            LinearGradient(
                colors: [Color(hex: "0D0C0B"), Color(hex: "111010")],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigation
        )
        .navigationTitle("摘要")
        .onAppear {
            loadData()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }

    // MARK: - 评分仪表盘

    private var scoreGauge: some View {
        ZStack {
            // 背景光晕
            Circle()
                .fill(statusColor.opacity(0.08))
                .frame(width: 100, height: 100)
                .blur(radius: 12)

            // 仪表盘
            Gauge(value: Double(score), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 1) {
                    Text("\(score)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                        .contentTransition(.numericText())

                    Text(headline)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(statusColor)
                }
            }
            .gaugeStyle(.accessoryCircular)
            .scaleEffect(2.2)
            .tint(gaugeGradient)
        }
        .frame(height: 110)
        .opacity(appeared ? 1 : 0)
    }

    private var gaugeGradient: Gradient {
        switch score {
        case 0..<40:
            return Gradient(colors: [Color(hex: "C75C5C"), Color(hex: "A04040")])
        case 40..<70:
            return Gradient(colors: [Color(hex: "D4A056"), Color(hex: "B88A40")])
        default:
            return Gradient(colors: [Color(hex: "7FB069"), Color(hex: "5A9044")])
        }
    }

    // MARK: - 指标网格

    private var metricsGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                MetricCard(
                    icon: "heart.fill",
                    label: String(localized: "心率"),
                    value: heartRate > 0 ? "\(heartRate)" : "--",
                    unit: "bpm",
                    color: PulseTheme.statusPoor
                )
                MetricCard(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: hrv > 0 ? "\(Int(hrv))" : "--",
                    unit: "ms",
                    color: PulseTheme.accent
                )
            }
            .staggered(index: 1)

            HStack(spacing: 8) {
                MetricCard(
                    icon: "moon.fill",
                    label: String(localized: "睡眠"),
                    value: sleepMinutes > 0 ? formatSleep(sleepMinutes) : "--",
                    unit: "",
                    color: Color(hex: "8B7EC8")
                )
                MetricCard(
                    icon: "figure.walk",
                    label: String(localized: "步数"),
                    value: formatSteps(steps),
                    unit: "",
                    color: PulseTheme.statusGood
                )
            }
            .staggered(index: 2)
        }
    }

    // MARK: - 数据加载

    private func loadData() {
        // 优先使用 WatchConnectivity 同步数据
        if let wcScore = connectivity.receivedScore {
            score = wcScore
            headline = connectivity.receivedHeadline ?? PulseTheme.statusLabel(for: wcScore)
            heartRate = connectivity.receivedHeartRate ?? 0
            steps = connectivity.receivedSteps ?? 0
        }

        // 本地 HealthKit 补充
        Task {
            do {
                try await healthManager.requestAuthorization()
                await healthManager.refreshAll()

                let localScore = healthManager.calculateDailyScore()
                if connectivity.receivedScore == nil {
                    score = localScore
                    headline = PulseTheme.statusLabel(for: localScore)
                }

                heartRate = Int(healthManager.latestHeartRate ?? 0)
                hrv = healthManager.latestHRV ?? 0
                sleepMinutes = healthManager.lastNightSleepMinutes
                steps = healthManager.todaySteps

                // 触觉反馈：评分刷新完成
                HapticManager.scoreRefreshed()

                // 异常告警：评分过低
                if (connectivity.receivedScore ?? localScore) < 30 {
                    HapticManager.alertTriggered()
                }
            } catch {
                print("SummaryView HealthKit error: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        PulseTheme.statusColor(for: score)
    }

    private func formatSleep(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return "\(h)h\(m)m"
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 10000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        } else if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }
}

// MARK: - 指标卡片组件

struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .contentTransition(.numericText())

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.4), lineWidth: 0.5)
        )
    }
}

#Preview {
    NavigationStack {
        SummaryView()
    }
}
