import SwiftUI
import SwiftData

/// 异常事件时间线 — 按日期展示检测到的健康异常
struct AnomalyTimelineView: View {

    @Query(sort: \DailySummary.date, order: .reverse) private var allSummaries: [DailySummary]
    @State private var anomalyDays: [(date: Date, anomalies: [Anomaly])] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {
                // 说明
                headerCard
                    .staggered(index: 0)

                if isLoading {
                    ProgressView()
                        .tint(PulseTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PulseTheme.spacingXL)
                } else if anomalyDays.isEmpty {
                    allClearCard
                        .staggered(index: 1)
                } else {
                    // 时间线
                    ForEach(Array(anomalyDays.enumerated()), id: \.offset) { index, day in
                        daySection(day.date, anomalies: day.anomalies)
                            .staggered(index: index + 1)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingS)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "异常记录"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await detectAnomalies()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.statusWarning.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PulseTheme.statusWarning)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "健康异常时间线"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(String(localized: "基于个人基线的标准差检测，非医学诊断"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()
        }
        .pulseCard()
    }

    // MARK: - All Clear

    private var allClearCard: some View {
        VStack(spacing: PulseTheme.spacingM) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(PulseTheme.accentTeal)

            Text(String(localized: "一切正常"))
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)

            Text(String(localized: "过去 90 天内未检测到显著异常"))
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseTheme.spacingXL)
        .pulseCard()
    }

    // MARK: - 每日异常段

    private func daySection(_ date: Date, anomalies: [Anomaly]) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            // 日期头
            HStack(spacing: PulseTheme.spacingS) {
                Circle()
                    .fill(severityColor(anomalies.first?.severity ?? .low))
                    .frame(width: 8, height: 8)

                Text(date, format: .dateTime.month(.wide).day().weekday(.wide))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)

                Spacer()

                Text("\(anomalies.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(PulseTheme.surface2))
            }

            // 异常卡片列表
            ForEach(anomalies) { anomaly in
                anomalyRow(anomaly)
            }
        }
        .pulseCard()
    }

    private func anomalyRow(_ anomaly: Anomaly) -> some View {
        HStack(alignment: .top, spacing: PulseTheme.spacingM) {
            // 指标图标
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(severityColor(anomaly.severity).opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: metricIcon(anomaly.metric))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(severityColor(anomaly.severity))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(anomaly.message)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)

                    severityBadge(anomaly.severity)
                }

                Text(anomaly.detail)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)

                // z-score 指示
                Text(String(format: "z = %.1f", anomaly.zScore))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - 辅助

    private func severityColor(_ severity: AnomalySeverityLevel) -> Color {
        switch severity {
        case .high: return PulseTheme.statusPoor
        case .medium: return PulseTheme.statusWarning
        case .low: return PulseTheme.textTertiary
        }
    }

    private func severityBadge(_ severity: AnomalySeverityLevel) -> some View {
        let (label, color): (String, Color) = {
            switch severity {
            case .high: return (String(localized: "严重"), PulseTheme.statusPoor)
            case .medium: return (String(localized: "注意"), PulseTheme.statusWarning)
            case .low: return (String(localized: "轻微"), PulseTheme.textTertiary)
            }
        }()

        return Text(label)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func metricIcon(_ metric: AnomalyMetric) -> String {
        switch metric {
        case .hrv: return "waveform.path.ecg"
        case .restingHeartRate: return "heart.fill"
        case .sleep: return "moon.fill"
        case .bloodOxygen: return "lungs.fill"
        }
    }

    // MARK: - 异常检测

    private func detectAnomalies() async {
        let analyzer = HealthAnalyzer.shared
        let summaries = Array(allSummaries.sorted { $0.date < $1.date })

        guard summaries.count >= 7 else {
            isLoading = false
            return
        }

        var days: [(date: Date, anomalies: [Anomaly])] = []

        // 检查最近 90 天
        let recentCount = min(summaries.count, 90)
        let recent = Array(summaries.suffix(recentCount))

        for i in 7..<recent.count {
            let history = Array(recent[max(0, i - 7)..<i])
            let current = recent[i]
            let detected = analyzer.detectAnomaliesForDate(summary: current, history: history)

            if !detected.isEmpty {
                days.append((current.date, detected))
            }
        }

        // 最新的在前
        anomalyDays = days.reversed()
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        AnomalyTimelineView()
    }
    .preferredColorScheme(.dark)
}
