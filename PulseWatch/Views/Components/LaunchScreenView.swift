import SwiftUI

// MARK: - Launch Screen（启动画面）
// 纯色暖调背景 + "Pulse" 标题 + "by Abundra" 副标题

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // 暖色渐变背景
            LinearGradient(
                colors: [
                    Color(hex: "B8894A"),
                    Color(hex: "9A6B3A"),
                    Color(hex: "8B4A3A"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                Text("Pulse")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("by Abundra")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
