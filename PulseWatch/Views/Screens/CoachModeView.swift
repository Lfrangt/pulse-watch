import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

/// Coach Mode — 生成只读健康快照 QR 码，供教练/朋友扫描查看
struct CoachModeView: View {

    @AppStorage("pulse.demo.enabled") private var demoMode = false
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    @State private var qrImage: UIImage?
    @State private var snapshotRendered: UIImage?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingL) {

                headerCard
                    .staggered(index: 0)

                // 当前状态概览
                statusCard
                    .staggered(index: 1)

                // QR 码
                qrCard
                    .staggered(index: 2)

                // 分享按钮
                shareButtons
                    .staggered(index: 3)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingS)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "教练模式"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            generateQRCode()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.accentTeal.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PulseTheme.accentTeal)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "教练模式"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "生成健康快照分享给教练或朋友"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            Spacer()
        }
        .pulseCard()
    }

    // MARK: - Status Card

    private var currentInsight: HealthInsight {
        demoMode ? DemoDataProvider.makeInsight() : HealthAnalyzer.shared.generateInsight()
    }

    private var statusCard: some View {
        let today = summaries.first { Calendar.current.isDateInToday($0.date) }
        let insight = currentInsight

        return VStack(spacing: PulseTheme.spacingM) {
            // 评分
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "今日评分"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                    Text("\(insight.dailyScore)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.statusColor(for: insight.dailyScore))
                }
                Spacer()
                // 训练建议
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: insight.trainingAdvice.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(PulseTheme.accent)
                    Text(insight.trainingAdvice.label)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }

            Divider().background(PulseTheme.border)

            // 关键指标
            HStack(spacing: 0) {
                coachMetric(label: "RHR", value: today?.restingHeartRate.map { "\(Int($0))" } ?? "—", unit: "bpm")
                coachMetric(label: "HRV", value: today?.averageHRV.map { "\(Int($0))" } ?? "—", unit: "ms")
                coachMetric(label: String(localized: "睡眠"), value: today?.sleepDurationMinutes.map { String(format: "%.1f", Double($0) / 60.0) } ?? "—", unit: "h")
                coachMetric(label: String(localized: "步数"), value: today?.totalSteps.map { "\($0)" } ?? "—", unit: "")
            }
        }
        .pulseCard()
    }

    private func coachMetric(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - QR Code

    private var qrCard: some View {
        VStack(spacing: PulseTheme.spacingM) {
            Text(String(localized: "健康快照 QR 码"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .accessibilityLabel(String(localized: "健康快照 QR 码"))
                    .background(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                            .fill(.white)
                            .padding(-12)
                    )
            } else {
                ProgressView()
                    .tint(PulseTheme.accent)
                    .frame(width: 200, height: 200)
            }

            Text(String(localized: "扫码查看今日健康数据快照"))
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .pulseCard()
    }

    // MARK: - Share Buttons

    private var shareButtons: some View {
        VStack(spacing: PulseTheme.spacingS) {
            // 分享快照图片
            Button {
                shareSnapshot()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                    Text(String(localized: "分享健康快照图片"))
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .fill(PulseTheme.surface2)
                )
            }

            // 分享 QR 码图片
            Button {
                shareQR()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode")
                    Text(String(localized: "分享 QR 码"))
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                        .fill(PulseTheme.surface2)
                )
            }
        }
    }

    // MARK: - QR Generation

    private func generateQRCode() {
        let today = summaries.first { Calendar.current.isDateInToday($0.date) }
        let insight = currentInsight

        // 编码健康快照为 JSON → base64 → deep link
        let snapshot: [String: Any] = [
            "score": insight.dailyScore,
            "rhr": today?.restingHeartRate ?? 0,
            "hrv": today?.averageHRV ?? 0,
            "sleep": (today?.sleepDurationMinutes ?? 0),
            "steps": today?.totalSteps ?? 0,
            "advice": insight.trainingAdvice.rawValue,
            "date": DailySummary.dateFormatter.string(from: .now)
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: snapshot),
              let jsonStr = String(data: data, encoding: .utf8) else { return }

        let deepLink = "pulse-health://coach?data=\(jsonStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(deepLink.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return }

        let scale = 200.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return }
        qrImage = UIImage(cgImage: cgImage)
    }

    // MARK: - Share Actions

    @MainActor
    private func shareSnapshot() {
        let today = summaries.first { Calendar.current.isDateInToday($0.date) }
        let insight = currentInsight

        let card = HealthSnapshotShareCard(
            score: insight.dailyScore,
            restingHR: today?.restingHeartRate,
            hrv: today?.averageHRV,
            sleepHours: today?.sleepDurationMinutes.map { Double($0) / 60.0 },
            steps: today?.totalSteps,
            trainingAdvice: insight.trainingAdvice.label,
            ratio: .square
        )

        let renderer = ImageRenderer(content: card.frame(width: 390))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        presentShare(items: [image])
    }

    private func shareQR() {
        guard let qrImage else { return }
        presentShare(items: [qrImage])
    }

    private func presentShare(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    NavigationStack {
        CoachModeView()
    }
    .preferredColorScheme(.dark)
}
