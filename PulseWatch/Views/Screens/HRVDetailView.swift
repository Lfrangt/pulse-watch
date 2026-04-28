import SwiftUI
import Charts
import os

/// HRV deep-dive — 7-day trend, score context, what HRV means
struct HRVDetailView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "HRVDetailView")

    @State private var healthManager = HealthKitManager.shared
    @State private var weekSamples: [(date: Date, value: Double)] = []
    @State private var chartAppeared = false
    @State private var selectedTrendDate: Date?

    private var currentHRV: Double { healthManager.latestHRV ?? 0 }

    private var status: String {
        switch currentHRV {
        case 0..<30:  return String(localized: "Low — consider resting")
        case 30..<50: return String(localized: "Fair — light training OK")
        case 50..<80: return String(localized: "Good — ready to train")
        default:      return String(localized: "Excellent — push hard")
        }
    }

    private var statusColor: Color {
        switch currentHRV {
        case 0..<30:  return PulseTheme.statusPoor
        case 30..<50: return PulseTheme.statusWarning
        case 50..<80: return PulseTheme.statusGood
        default:      return PulseTheme.accentTeal
        }
    }

    private var avg7day: Double {
        guard !weekSamples.isEmpty else { return currentHRV }
        return weekSamples.map(\.value).reduce(0, +) / Double(weekSamples.count)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {

                // ── Hero number
                heroCard
                    .staggered(index: 0)

                // ── 7-day chart
                if !weekSamples.isEmpty {
                    trendCard
                        .staggered(index: 1)
                }

                // ── What is HRV
                explainerCard
                    .staggered(index: 2)

                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "HRV"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack {
                Text("HRV · " + String(localized: "Last reading"))
                    .pulseEyebrow()
                Spacer()
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusXS, style: .continuous)
                            .stroke(statusColor, lineWidth: PulseTheme.hairline)
                    )
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(currentHRV))")
                    .font(PulseTheme.metricLFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Text("ms")
                    .font(PulseTheme.unitFont)
                    .foregroundStyle(PulseTheme.textTertiary)

                Spacer()

                if !weekSamples.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f ms", avg7day))
                            .font(PulseTheme.metricSFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(String(localized: "7-day avg"))
                            .font(PulseTheme.monoFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
            }
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    // MARK: - Trend Chart

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "7-Day Trend"))
                .pulseEyebrow()

            Chart {
                ForEach(weekSamples, id: \.date) { s in
                    // Area fill
                    AreaMark(
                        x: .value("Date", s.date),
                        y: .value("HRV", chartAppeared ? s.value : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.accentTeal.opacity(0.25), PulseTheme.accentTeal.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    // Line
                    LineMark(
                        x: .value("Date", s.date),
                        y: .value("HRV", chartAppeared ? s.value : 0)
                    )
                    .foregroundStyle(PulseTheme.accentTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    // Point
                    PointMark(
                        x: .value("Date", s.date),
                        y: .value("HRV", chartAppeared ? s.value : 0)
                    )
                    .foregroundStyle(PulseTheme.accentTeal)
                    .symbolSize(30)
                }

                if let selectedTrendDate {
                    RuleMark(x: .value("Selected", selectedTrendDate))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 0.5))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { val in
                    if let date = val.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.weekday(.abbreviated))
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(PulseTheme.highlight)
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let plotFrame = geo[proxy.plotAreaFrame]
                                let x = value.location.x - plotFrame.origin.x
                                guard let date: Date = proxy.value(atX: x) else { return }
                                let cal = Calendar.current
                                if let nearest = weekSamples.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                    let newDate = cal.startOfDay(for: nearest.date)
                                    if selectedTrendDate != newDate {
                                        selectedTrendDate = newDate
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.25)) { selectedTrendDate = nil }
                            }
                        )
                }
            }
            .overlay(alignment: .top) {
                if let sel = selectedTrendDate,
                   let point = weekSamples.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
                    let dateFmt: DateFormatter = {
                        let f = DateFormatter()
                        f.locale = Locale.current
                        f.dateFormat = "EEEE, M/d"
                        return f
                    }()
                    VStack(spacing: 2) {
                        Text("\(Int(point.value)) ms")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(dateFmt.string(from: point.date))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(PulseTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTrendDate)
                }
            }
            .frame(height: 160)
            .animation(.easeInOut(duration: 0.8), value: chartAppeared)

            // Avg baseline
            HStack {
                Rectangle()
                    .fill(PulseTheme.highlight)
                    .frame(width: 16, height: 1)
                Text(String(format: String(localized: "Avg %.0f ms"), avg7day))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    // MARK: - Explainer

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "What is HRV?"))
                .pulseEyebrow()

            ForEach(explainerPoints, id: \.title) { point in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: point.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(PulseTheme.accentTeal)
                        .frame(width: 20)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(point.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(point.body)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(PulseTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    private struct ExplainerPoint { let icon: String; let title: String; let body: String }
    private let explainerPoints: [ExplainerPoint] = [
        .init(icon: "waveform.path.ecg",
              title: String(localized: "Heart Rate Variability"),
              body: String(localized: "The variation in time between consecutive heartbeats. Higher is generally better — it means your nervous system is adaptable.")),
        .init(icon: "bed.double.fill",
              title: String(localized: "Recovery Indicator"),
              body: String(localized: "Low HRV often signals fatigue, stress, or illness before you feel it. Use it to decide whether to train hard or recover.")),
        .init(icon: "chart.line.uptrend.xyaxis",
              title: String(localized: "Trend over time"),
              body: String(localized: "Your baseline HRV naturally changes with age and fitness. Compare to your own 7-day average, not population norms.")),
    ]

    // MARK: - Helpers

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
            .fill(PulseTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                    .stroke(PulseTheme.border, lineWidth: PulseTheme.hairline)
            )
    }

    private func loadData() async {
        // Fetch 7-day HRV daily averages from HealthKit
        do {
            let hkData = try await healthManager.fetchWeeklyHRV()
            if !hkData.isEmpty {
                weekSamples = hkData
            }
        } catch {
            logger.error("HRV weekly fetch error: \(error)")
        }
        withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
            chartAppeared = true
        }
    }
}

#Preview {
    NavigationStack {
        HRVDetailView()
            .preferredColorScheme(.dark)
    }
}
