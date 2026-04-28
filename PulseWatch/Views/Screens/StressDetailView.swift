import SwiftUI
import SwiftData
import Charts
import os

/// Stress & Energy deep-dive — gauge, contributing factors, 7-day trend, energy bank advice
struct StressDetailView: View {

    private let logger = Logger(subsystem: "com.abundra.pulse", category: "StressDetailView")

    @State private var healthManager = HealthKitManager.shared
    @State private var chartAppeared = false
    @State private var gaugeAnimated = false
    @State private var selectedTrendDate: Date?

    @Query(sort: \DailySummary.date, order: .forward) private var allSummaries: [DailySummary]

    private var stressScore: Int {
        healthManager.calculateStressScore()
    }

    private var stressLevel: StressLevel {
        StressLevel.from(score: stressScore)
    }

    // Contributing factor scores (individual, 0-100 stress)
    private var hrvStress: Double {
        guard let hrv = healthManager.latestHRV else { return 50 }
        let clamped = min(max(hrv, 20), 80)
        return 100.0 - ((clamped - 20.0) / 60.0 * 100.0)
    }

    private var rhrStress: Double {
        guard let rhr = healthManager.latestRestingHR else { return 50 }
        let clamped = min(max(rhr, 50), 90)
        return (clamped - 50.0) / 40.0 * 100.0
    }

    private var sleepStress: Double {
        let minutes = healthManager.lastNightSleepMinutes
        guard minutes > 0 else { return 50 }
        let hours = min(max(Double(minutes) / 60.0, 4.0), 9.0)
        return 100.0 - ((hours - 4.0) / 5.0 * 100.0)
    }

    private var weekData: [(date: Date, score: Int)] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.startOfDay(
            for: calendar.safeDate(byAdding: .day, value: -7, to: .now)
        )
        return allSummaries
            .filter { $0.date >= sevenDaysAgo && $0.stressScore != nil }
            .map { ($0.date, $0.stressScore!) }
    }

    private var avg7day: Double {
        guard !weekData.isEmpty else { return Double(stressScore) }
        return Double(weekData.map(\.score).reduce(0, +)) / Double(weekData.count)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {

                // Hero — stress gauge
                heroCard
                    .staggered(index: 0)

                // Contributing factors
                factorsCard
                    .staggered(index: 1)

                // 7-day trend
                if !weekData.isEmpty {
                    trendCard
                        .staggered(index: 2)
                }

                // Energy bank advice
                energyBankCard
                    .staggered(index: 3)

                Spacer(minLength: 60)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingM)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "Stress & Energy"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                gaugeAnimated = true
            }
            withAnimation(.easeInOut(duration: 0.6).delay(0.5)) {
                chartAppeared = true
            }
        }
    }

    // MARK: - Hero Card with Circular Gauge

    private var heroCard: some View {
        VStack(spacing: PulseTheme.spacingL) {
            // Emoji + label
            Text(stressLevel.emoji)
                .font(.system(size: 40))

            // Circular gauge
            ZStack {
                // Track
                Circle()
                    .stroke(PulseTheme.highlight, lineWidth: 8)
                    .frame(width: 160, height: 160)

                // Progress arc
                Circle()
                    .trim(from: 0, to: gaugeAnimated ? CGFloat(stressScore) / 100.0 : 0)
                    .stroke(
                        AngularGradient(
                            colors: [stressLevel.color.opacity(0.4), stressLevel.color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: gaugeAnimated)

                // Score text
                VStack(spacing: 4) {
                    Text("\(stressScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                        .contentTransition(.numericText())

                    Text(String(localized: "Stress"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            // Status label
            Text(stressLevel.label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(stressLevel.color)

            // 7-day average
            if !weekData.isEmpty {
                HStack(spacing: 4) {
                    Text(String(format: "%.0f", avg7day))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                    Text(String(localized: "7-day avg"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    // MARK: - Contributing Factors

    private var factorsCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "Contributing Factors"))
                .pulseEyebrow()

            factorBar(
                icon: "waveform.path.ecg",
                label: "HRV",
                value: hrvStress,
                detail: healthManager.latestHRV.map { String(format: "%.0f ms", $0) } ?? "--",
                color: PulseTheme.accentTeal
            )

            factorBar(
                icon: "heart.fill",
                label: String(localized: "Resting HR"),
                value: rhrStress,
                detail: healthManager.latestRestingHR.map { String(format: "%.0f bpm", $0) } ?? "--",
                color: PulseTheme.activityCoral
            )

            factorBar(
                icon: "moon.fill",
                label: String(localized: "Sleep"),
                value: sleepStress,
                detail: healthManager.lastNightSleepMinutes > 0
                    ? String(format: "%.1fh", Double(healthManager.lastNightSleepMinutes) / 60.0)
                    : "--",
                color: PulseTheme.sleepViolet
            )

            // Weight legend
            HStack(spacing: PulseTheme.spacingS) {
                Text(String(localized: "Weight: HRV 50% / RHR 30% / Sleep 20%"))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    private func factorBar(icon: String, label: String, value: Double, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
                Text(detail)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(PulseTheme.highlight)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(stressBarColor(value))
                        .frame(width: gaugeAnimated ? geo.size.width * CGFloat(value / 100.0) : 0, height: 6)
                        .animation(.easeInOut(duration: 0.8), value: gaugeAnimated)
                }
            }
            .frame(height: 6)
        }
    }

    private func stressBarColor(_ value: Double) -> Color {
        switch value {
        case 0..<35:  return Color(hex: "00F5FF")  // teal — low stress
        case 35..<65: return PulseTheme.statusWarning   // amber — moderate
        default:      return PulseTheme.activityCoral   // coral — high
        }
    }

    // MARK: - 7-Day Trend Chart

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            Text(String(localized: "7-Day Trend"))
                .pulseEyebrow()

            Chart {
                ForEach(weekData, id: \.date) { item in
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Stress", chartAppeared ? item.score : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [stressLevel.color.opacity(0.25), stressLevel.color.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Stress", chartAppeared ? item.score : 0)
                    )
                    .foregroundStyle(stressLevel.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Stress", chartAppeared ? item.score : 0)
                    )
                    .foregroundStyle(stressLevel.color)
                    .symbolSize(30)
                }

                if let selectedTrendDate {
                    RuleMark(x: .value("Selected", selectedTrendDate))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 0.5))
                }
            }
            .chartYScale(domain: 0...100)
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
                AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(PulseTheme.highlight)
                    AxisValueLabel {
                        if let v = val.as(Int.self) {
                            Text("\(v)")
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
                                if let nearest = weekData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                    let newDate = Calendar.current.startOfDay(for: nearest.date)
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
                   let point = weekData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
                    let dateFmt: DateFormatter = {
                        let f = DateFormatter()
                        f.locale = Locale.current
                        f.dateFormat = "EEEE, M/d"
                        return f
                    }()
                    VStack(spacing: 2) {
                        Text("\(point.score)")
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

            // Average baseline
            HStack {
                Rectangle()
                    .fill(stressLevel.color.opacity(0.5))
                    .frame(width: 16, height: 1)
                Text(String(format: String(localized: "Avg %.0f"), avg7day))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    // MARK: - Energy Bank

    private var energyBankCard: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(stressLevel.color)
                Text(String(localized: "Energy Bank"))
                    .pulseEyebrow()
            }

            Text(stressLevel.energyAdvice)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)
                .lineSpacing(3)

            // Visual energy meter
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    let threshold = (4 - i) * 20 // 80, 60, 40, 20, 0
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(stressScore <= threshold
                              ? Color(hex: "00F5FF").opacity(0.8)
                              : PulseTheme.highlight)
                        .frame(height: 8)
                }
            }

            HStack {
                Text(String(localized: "Depleted"))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
                Spacer()
                Text(String(localized: "Full"))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
        }
        .padding(PulseTheme.spacingL)
        .background(cardBg)
    }

    // MARK: - Helpers

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
            .fill(PulseTheme.highlight)
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                    .stroke(PulseTheme.highlight, lineWidth: 0.5)
            )
    }
}

// MARK: - Stress Level Model

enum StressLevel {
    case low, moderate, high

    static func from(score: Int) -> StressLevel {
        switch score {
        case 0..<35:  return .low
        case 35..<65: return .moderate
        default:      return .high
        }
    }

    var emoji: String {
        switch self {
        case .low:      return "\u{1F60C}" // relaxed face
        case .moderate: return "\u{1F610}" // neutral face
        case .high:     return "\u{1F630}" // anxious face
        }
    }

    var label: String {
        switch self {
        case .low:      return String(localized: "Low Stress")
        case .moderate: return String(localized: "Moderate Stress")
        case .high:     return String(localized: "High Stress")
        }
    }

    var color: Color {
        switch self {
        case .low:      return Color(hex: "00F5FF")  // teal
        case .moderate: return PulseTheme.statusWarning   // amber
        case .high:     return PulseTheme.activityCoral   // coral
        }
    }

    var energyAdvice: String {
        switch self {
        case .low:
            return String(localized: "Good energy reserves \u{2014} push harder today. Your body is well recovered and ready for intensity.")
        case .moderate:
            return String(localized: "Balanced \u{2014} maintain your routine. Moderate effort is sustainable, avoid overreaching.")
        case .high:
            return String(localized: "Recovery needed \u{2014} prioritize rest. Consider lighter activity, better sleep, and stress management today.")
        }
    }
}

#Preview {
    NavigationStack {
        StressDetailView()
            .preferredColorScheme(.dark)
    }
}
