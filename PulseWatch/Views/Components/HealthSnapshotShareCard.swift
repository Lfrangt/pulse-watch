import SwiftUI
import SwiftData

/// 健康快照分享卡 — 今日评分 + 关键指标，适合社交媒体分享
struct HealthSnapshotShareCard: View {

    let score: Int
    let restingHR: Double?
    let hrv: Double?
    let sleepHours: Double?
    let steps: Int?
    let trainingAdvice: String?
    let ratio: CardRatio

    enum CardRatio: String, CaseIterable {
        case story = "9:16"
        case square = "1:1"

        var aspectRatio: CGFloat {
            switch self {
            case .story: return 9.0 / 16.0
            case .square: return 1.0
            }
        }
    }

    var body: some View {
        ZStack {
            // 背景渐变
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "0A1628"), location: 0),
                            .init(color: Color(hex: "0F2A3D"), location: 0.3),
                            .init(color: Color(hex: "134E5E"), location: 0.6),
                            .init(color: Color(hex: "0A1A24"), location: 1.0),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: ratio == .story ? 32 : 20) {
                // 品牌
                HStack {
                    Text("PULSE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.accentTeal.opacity(0.7))
                        .tracking(3)
                    Spacer()
                    Text(Date.now, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                // 核心评分
                VStack(spacing: 8) {
                    Text("\(score)")
                        .font(.system(size: ratio == .story ? 72 : 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(PulseTheme.statusLabel(for: score))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.statusColor(for: score))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(PulseTheme.statusColor(for: score).opacity(0.15))
                        )
                }

                Spacer()

                // 指标网格
                HStack(spacing: 0) {
                    if let rhr = restingHR {
                        miniMetric(icon: "heart.fill", value: "\(Int(rhr))", unit: "bpm", color: PulseTheme.activityCoral)
                    }
                    if let hrv = hrv {
                        miniMetric(icon: "waveform.path.ecg", value: "\(Int(hrv))", unit: "ms", color: PulseTheme.accentTeal)
                    }
                    if let sleep = sleepHours {
                        miniMetric(icon: "moon.fill", value: String(format: "%.1f", sleep), unit: "h", color: PulseTheme.sleepViolet)
                    }
                    if let steps = steps {
                        miniMetric(icon: "figure.walk", value: formatSteps(steps), unit: "", color: PulseTheme.statusWarning)
                    }
                }

                // 水印
                Text("pulse-watch.app")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(24)
        }
        .aspectRatio(ratio.aspectRatio, contentMode: .fit)
    }

    private func miniMetric(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 10000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
}

// MARK: - 分享屏幕

struct HealthSnapshotShareScreen: View {

    @AppStorage("pulse.demo.enabled") private var demoMode = false
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    @State private var selectedRatio: HealthSnapshotShareCard.CardRatio = .story
    @State private var renderedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    private var todaySummary: DailySummary? {
        summaries.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: PulseTheme.spacingM) {
                // 比例选择
                Picker("", selection: $selectedRatio) {
                    ForEach(HealthSnapshotShareCard.CardRatio.allCases, id: \.rawValue) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, PulseTheme.spacingM)
                .onChange(of: selectedRatio) { _, _ in renderedImage = nil }

                // 预览
                ScrollView {
                    cardView
                        .padding(.horizontal, PulseTheme.spacingL)
                }

                // 分享按钮
                Button {
                    shareImage()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text(String(localized: "分享"))
                    }
                }
                .buttonStyle(PulseButtonStyle())
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.bottom, PulseTheme.spacingM)
            }
            .background(PulseTheme.background)
            .navigationTitle(String(localized: "分享健康快照"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }

    private var cardView: some View {
        let summary = todaySummary
        let insight = demoMode ? DemoDataProvider.makeInsight() : HealthAnalyzer.shared.generateInsight()

        return HealthSnapshotShareCard(
            score: insight.dailyScore,
            restingHR: summary?.restingHeartRate,
            hrv: summary?.averageHRV,
            sleepHours: summary?.sleepDurationMinutes.map { Double($0) / 60.0 },
            steps: summary?.totalSteps,
            trainingAdvice: insight.trainingAdvice.label,
            ratio: selectedRatio
        )
    }

    @MainActor
    private func shareImage() {
        let renderer = ImageRenderer(content:
            cardView.frame(width: selectedRatio == .story ? 390 : 390)
        )
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    HealthSnapshotShareScreen()
        .preferredColorScheme(.dark)
}
