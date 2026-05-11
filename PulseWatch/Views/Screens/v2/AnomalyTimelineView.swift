import SwiftUI
import SwiftData

/// 异常事件时间线 — 按日期展示检测到的健康异常
struct AnomalyTimelineView: View {

    @AppStorage("pulse.demo.enabled") private var demoMode = false
    @Query(sort: \DailySummary.date, order: .reverse) private var allSummaries: [DailySummary]
    @State private var anomalyDays: [(date: Date, anomalies: [Anomaly])] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.m) {
                // 说明
                headerCard
                    .staggered(index: 0)

                if isLoading {
                    ProgressView()
                        .tint(DS.Color.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xl)
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
            .padding(.horizontal, DS.Spacing.m)
            .padding(.top, DS.Spacing.s)
        }
        .background(DS.Color.bg)
        .navigationTitle(String(localized: "异常记录"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if demoMode {
                anomalyDays = DemoDataProvider.makeAnomalyDays()
                isLoading = false
            } else {
                await detectAnomalies()
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: DS.Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.Color.warn.opacity(0.12))
                    .frame(width: DS.Spacing.xl + DS.Spacing.xs, height: DS.Spacing.xl + DS.Spacing.xs)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Color.warn)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "健康异常时间线"))
                    .font(DS.Typography.bodyL)
                    .foregroundStyle(DS.Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "基于个人基线的标准差检测，非医学诊断"))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)
            }

            Spacer()
        }
        .dsCard()
    }

    // MARK: - All Clear

    private var allClearCard: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: "checkmark.shield.fill")
                .font(DS.Typography.title1)
                .foregroundStyle(DS.Color.accent)

            Text(String(localized: "一切正常"))
                .font(DS.Typography.bodyL)
                .foregroundStyle(DS.Color.ink)

            Text(String(localized: "过去 90 天内未检测到显著异常"))
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .dsCard()
    }

    // MARK: - 每日异常段

    private func daySection(_ date: Date, anomalies: [Anomaly]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            // 日期头
            HStack(spacing: DS.Spacing.s) {
                Circle()
                    .fill(severityColor(anomalies.first?.severity ?? .low))
                    .frame(width: DS.Spacing.s, height: DS.Spacing.s)

                Text(date, format: .dateTime.month(.wide).day().weekday(.wide))
                    .font(DS.Typography.bodyS.weight(.semibold))
                    .foregroundStyle(DS.Color.inkMid)

                Spacer()

                Text("\(anomalies.count)")
                    .font(DS.Typography.caption.weight(.bold))
                    .foregroundStyle(DS.Color.inkDim)
                    .padding(.horizontal, DS.Spacing.s)
                    .padding(.vertical, DS.Spacing.m)
                    .background(Capsule().fill(DS.Color.bgElev))
            }

            // 异常卡片列表
            ForEach(anomalies) { anomaly in
                anomalyRow(anomaly)
            }
        }
        .dsCard()
    }

    private func anomalyRow(_ anomaly: Anomaly) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            // 指标图标
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(severityColor(anomaly.severity).opacity(0.12))
                    .frame(width: DS.Spacing.xl, height: DS.Spacing.xl)
                Image(systemName: metricIcon(anomaly.metric))
                    .font(DS.Typography.bodyS.weight(.medium))
                    .foregroundStyle(severityColor(anomaly.severity))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(anomaly.message)
                        .font(DS.Typography.bodyS.weight(.semibold))
                        .foregroundStyle(DS.Color.ink)

                    severityBadge(anomaly.severity)
                }

                Text(anomaly.detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkMid)

                // z-score 指示
                Text(String(format: "z = %.1f", anomaly.zScore))
                    .font(DS.Typography.mono.weight(.medium))
                    .foregroundStyle(DS.Color.inkDim)
            }

            Spacer()
        }
    }

    // MARK: - 辅助

    private func severityColor(_ severity: AnomalySeverityLevel) -> Color {
        switch severity {
        case .high: return DS.Color.bad
        case .medium: return DS.Color.warn
        case .low: return DS.Color.inkDim
        }
    }

    private func severityBadge(_ severity: AnomalySeverityLevel) -> some View {
        let (label, color): (String, Color) = {
            switch severity {
            case .high: return (String(localized: "严重"), DS.Color.bad)
            case .medium: return (String(localized: "注意"), DS.Color.warn)
            case .low: return (String(localized: "轻微"), DS.Color.inkDim)
            }
        }()

        return Text(label)
            .font(DS.Typography.monoS.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.m)
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
