import SwiftUI

/// 分享卡片 — 生成可分享的成绩图片
/// 支持 Instagram Story (9:16) 和正方形 (1:1)
struct ShareCardView: View {
    let score: Int
    let headline: String
    let workoutType: String?
    let duration: String?
    let calories: Int?
    let date: Date

    enum CardRatio: String, CaseIterable {
        case story = "9:16"
        case square = "1:1"

        var size: CGSize {
            switch self {
            case .story: return CGSize(width: 1080, height: 1920)
            case .square: return CGSize(width: 1080, height: 1080)
            }
        }
    }

    var ratio: CardRatio = .story

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            VStack(spacing: ratio == .story ? 40 : 24) {
                if ratio == .story { Spacer() }

                // 日期
                Text(dateString)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))

                // 大评分圆环
                scoreRing
                    .frame(width: ringSize, height: ringSize)

                // 训练信息
                if workoutType != nil || duration != nil || calories != nil {
                    trainingInfo
                }

                if ratio == .story { Spacer() }

                // 品牌水印
                watermark

                if ratio == .story {
                    Spacer().frame(height: 40)
                }
            }
            .padding(32)
        }
        .frame(width: ratio.size.width / 3, height: ratio.size.height / 3)
    }

    // MARK: - 背景

    private var backgroundGradient: some View {
        let statusColor = PulseTheme.statusColor(for: score)
        return ZStack {
            // 深色底
            LinearGradient(
                colors: [Color(hex: "0D0C0B"), Color(hex: "1A1715")],
                startPoint: .top,
                endPoint: .bottom
            )

            // 状态色光晕
            RadialGradient(
                colors: [statusColor.opacity(0.3), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 250
            )
        }
    }

    // MARK: - 评分圆环

    private var ringSize: CGFloat { ratio == .story ? 180 : 140 }

    private var scoreRing: some View {
        let statusColor = PulseTheme.statusColor(for: score)
        let progress = CGFloat(score) / 100.0

        return ZStack {
            // 光晕
            Circle()
                .fill(statusColor.opacity(0.12))
                .frame(width: ringSize + 30, height: ringSize + 30)
                .blur(radius: 20)

            // 轨道
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)

            // 进度弧
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [statusColor.opacity(0.5), statusColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // 分数
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(headline)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(statusColor)
            }
        }
    }

    // MARK: - 训练信息

    private var trainingInfo: some View {
        VStack(spacing: 12) {
            if let type = workoutType {
                infoChip(icon: "dumbbell.fill", text: type)
            }

            HStack(spacing: 16) {
                if let dur = duration {
                    infoChip(icon: "clock.fill", text: dur)
                }
                if let cal = calories, cal > 0 {
                    infoChip(icon: "flame.fill", text: "\(cal) kcal")
                }
            }
        }
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(PulseTheme.accent)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - 水印

    private var watermark: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(PulseTheme.accent)
            Text("Tracked with Pulse 💪")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Helpers

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }

    // MARK: - 渲染为图片

    @MainActor
    func renderImage(ratio: CardRatio = .story) -> UIImage? {
        var card = self
        card.ratio = ratio
        let size = CGSize(width: ratio.size.width / 3, height: ratio.size.height / 3)
        let renderer = ImageRenderer(content: card.frame(width: size.width, height: size.height))
        renderer.scale = 3.0 // @3x for high quality
        return renderer.uiImage
    }
}

// MARK: - Share Helper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ShareCardView(
        score: 85,
        headline: "Peak",
        workoutType: "Push Day",
        duration: "48 min",
        calories: 320,
        date: .now
    )
    .preferredColorScheme(.dark)
}
