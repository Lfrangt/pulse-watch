import SwiftUI

// MARK: - App Icon（SwiftUI 代码生成）
// 暖色调渐变 + 心跳脉搏线条，premium 质感

struct AppIconView: View {
    /// 图标尺寸（默认 1024 用于导出）
    let size: CGFloat

    init(size: CGFloat = 1024) {
        self.size = size
    }

    // MARK: - 主色板（与 PulseTheme 一致的暖色调）

    /// 渐变背景色：amber/gold → terracotta
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "C9A96E"),  // 暖金色（PulseTheme.accent）
                Color(hex: "B8894A"),  // 深金色过渡
                Color(hex: "A0633A"),  // 过渡色
                Color(hex: "8B4A3A"),  // terracotta 陶土色
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 微妙的径向高光，增加深度感
    private var innerGlow: RadialGradient {
        RadialGradient(
            colors: [
                PulseTheme.highlight,
                PulseTheme.highlight,
                Color.clear
            ],
            center: .init(x: 0.35, y: 0.3),
            startRadius: size * 0.05,
            endRadius: size * 0.5
        )
    }

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width
            let center = CGPoint(x: s / 2, y: s / 2)

            // --- 1. 背景渐变 ---
            let bgRect = CGRect(origin: .zero, size: canvasSize)
            context.fill(
                Path(roundedRect: bgRect, cornerSize: .zero),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(hex: "C9A96E"),
                        Color(hex: "B8894A"),
                        Color(hex: "A0633A"),
                        Color(hex: "8B4A3A"),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: s, y: s)
                )
            )

            // --- 2. 内部高光层 ---
            context.fill(
                Path(roundedRect: bgRect, cornerSize: .zero),
                with: .radialGradient(
                    Gradient(colors: [
                        PulseTheme.highlight,
                        PulseTheme.highlight,
                        Color.clear
                    ]),
                    center: CGPoint(x: s * 0.35, y: s * 0.3),
                    startRadius: s * 0.05,
                    endRadius: s * 0.55
                )
            )

            // --- 3. 圆形轮廓（外环） ---
            let ringRadius = s * 0.30
            let ringLineWidth = s * 0.022

            var ringPath = Path()
            ringPath.addArc(
                center: center,
                radius: ringRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )

            context.stroke(
                ringPath,
                with: .color(PulseTheme.highlight),
                lineWidth: ringLineWidth
            )

            // --- 4. 心跳脉搏线（在圆内横穿） ---
            let pulseLineWidth = s * 0.025
            let midY = center.y
            let leftX = center.x - ringRadius * 0.85
            let rightX = center.x + ringRadius * 0.85

            // 心电图式脉搏线：平 → 小跳 → 大尖峰 → 大下沉 → 回平
            var pulsePath = Path()
            pulsePath.move(to: CGPoint(x: leftX, y: midY))

            // 平稳段
            let seg1 = leftX + (rightX - leftX) * 0.25
            pulsePath.addLine(to: CGPoint(x: seg1, y: midY))

            // 小P波
            let seg2 = leftX + (rightX - leftX) * 0.32
            pulsePath.addLine(to: CGPoint(x: seg2, y: midY - s * 0.035))

            // 回到基线
            let seg3 = leftX + (rightX - leftX) * 0.37
            pulsePath.addLine(to: CGPoint(x: seg3, y: midY))

            // QRS 复合波 — 急速上升（R波）
            let seg4 = leftX + (rightX - leftX) * 0.43
            pulsePath.addLine(to: CGPoint(x: seg4, y: midY + s * 0.025))

            let seg5 = leftX + (rightX - leftX) * 0.50
            pulsePath.addLine(to: CGPoint(x: seg5, y: midY - s * 0.14))

            // 急速下降（S波）
            let seg6 = leftX + (rightX - leftX) * 0.57
            pulsePath.addLine(to: CGPoint(x: seg6, y: midY + s * 0.06))

            // 回到基线
            let seg7 = leftX + (rightX - leftX) * 0.63
            pulsePath.addLine(to: CGPoint(x: seg7, y: midY))

            // T波（圆滑小丘）
            let seg8 = leftX + (rightX - leftX) * 0.72
            pulsePath.addQuadCurve(
                to: CGPoint(x: seg8, y: midY),
                control: CGPoint(x: leftX + (rightX - leftX) * 0.675, y: midY - s * 0.04)
            )

            // 末尾平稳段
            pulsePath.addLine(to: CGPoint(x: rightX, y: midY))

            context.stroke(
                pulsePath,
                with: .color(PulseTheme.highlight),
                style: StrokeStyle(lineWidth: pulseLineWidth, lineCap: .round, lineJoin: .round)
            )

            // --- 5. 底部微妙暗角 ---
            context.fill(
                Path(roundedRect: bgRect, cornerSize: .zero),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.clear,
                        Color.black.opacity(0.15)
                    ]),
                    center: center,
                    startRadius: s * 0.35,
                    endRadius: s * 0.75
                )
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("App Icon 1024x1024") {
    AppIconView(size: 300)
        .clipShape(RoundedRectangle(cornerRadius: 60, style: .continuous))
}

#Preview("App Icon Grid") {
    VStack(spacing: 20) {
        // iOS App Icon 预览
        AppIconView(size: 180)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))

        HStack(spacing: 16) {
            // 通知图标
            AppIconView(size: 60)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            // 设置图标
            AppIconView(size: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            // Spotlight
            AppIconView(size: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
    .padding(40)
    .background(Color.black)
}
