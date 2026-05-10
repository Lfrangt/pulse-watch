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
            VStack(spacing: DS.Spacing.l) {

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
            .padding(.horizontal, DS.Spacing.m)
            .padding(.top, DS.Spacing.s)
        }
        .background(DS.Color.bg)
        .navigationTitle(String(localized: "教练模式"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            generateQRCode()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: DS.Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.Color.accent.opacity(0.12))
                    .frame(width: DS.Spacing.xl + DS.Spacing.xs, height: DS.Spacing.xl + DS.Spacing.xs)
                Image(systemName: "person.2.fill")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Color.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "教练模式"))
                    .font(DS.Typography.bodyL)
                    .foregroundStyle(DS.Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "生成健康快照分享给教练或朋友"))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkDim)
            }
            Spacer()
        }
        .dsCard()
    }

    // MARK: - Status Card

    private var currentInsight: HealthInsight {
        demoMode ? DemoDataProvider.makeInsight() : HealthAnalyzer.shared.generateInsight()
    }

    private var statusCard: some View {
        let today = summaries.first { Calendar.current.isDateInToday($0.date) }
        let insight = currentInsight

        return VStack(spacing: DS.Spacing.m) {
            // 评分
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "今日评分"))
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Color.inkDim)
                    Text("\(insight.dailyScore)")
                        .font(DS.Typography.display3)
                        .foregroundStyle(PulseTheme.statusColor(for: insight.dailyScore))
                }
                Spacer()
                // 训练建议
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: insight.trainingAdvice.icon)
                        .font(DS.Typography.bodyL)
                        .foregroundStyle(DS.Color.accent)
                    Text(insight.trainingAdvice.label)
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Color.inkMid)
                }
            }

            Divider().background(DS.Color.line)

            // 关键指标
            HStack(spacing: 0) {
                coachMetric(label: "RHR", value: today?.restingHeartRate.map { "\(Int($0))" } ?? "—", unit: "bpm")
                coachMetric(label: "HRV", value: today?.averageHRV.map { "\(Int($0))" } ?? "—", unit: "ms")
                coachMetric(label: String(localized: "睡眠"), value: today?.sleepDurationMinutes.map { String(format: "%.1f", Double($0) / 60.0) } ?? "—", unit: "h")
                coachMetric(label: String(localized: "步数"), value: today?.totalSteps.map { "\($0)" } ?? "—", unit: "")
            }
        }
        .dsCard()
    }

    private func coachMetric(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Typography.bodyL.weight(.bold))
                .foregroundStyle(DS.Color.ink)
            HStack(spacing: 2) {
                Text(label)
                    .font(DS.Typography.mono.weight(.medium))
                    .foregroundStyle(DS.Color.inkDim)
                if !unit.isEmpty {
                    Text(unit)
                        .font(DS.Typography.monoS)
                        .foregroundStyle(DS.Color.inkDim.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - QR Code

    private var qrCard: some View {
        VStack(spacing: DS.Spacing.m) {
            Text(String(localized: "健康快照 QR 码"))
                .font(DS.Typography.bodyS.weight(.semibold))
                .foregroundStyle(DS.Color.inkMid)

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: DS.Spacing.xxl * 5, height: DS.Spacing.xxl * 5)
                    .accessibilityLabel(String(localized: "健康快照 QR 码"))
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .fill(.white)
                            .padding(-12)
                    )
            } else {
                ProgressView()
                    .tint(DS.Color.accent)
                    .frame(width: DS.Spacing.xxl * 5, height: DS.Spacing.xxl * 5)
            }

            Text(String(localized: "扫码查看今日健康数据快照"))
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.inkDim)
        }
        .frame(maxWidth: .infinity)
        .dsCard()
    }

    // MARK: - Share Buttons

    private var shareButtons: some View {
        VStack(spacing: DS.Spacing.s) {
            // 分享快照图片
            Button {
                shareSnapshot()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                    Text(String(localized: "分享健康快照图片"))
                }
                .font(DS.Typography.body.weight(.medium))
                .foregroundStyle(DS.Color.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.card)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                        .fill(DS.Color.bgElev)
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
                .font(DS.Typography.body.weight(.medium))
                .foregroundStyle(DS.Color.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.card)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                        .fill(DS.Color.bgElev)
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
