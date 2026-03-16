import SwiftUI

/// 首次启动引导流程 — 欢迎 → 功能介绍 → 权限请求 → 开始使用
struct OnboardingView: View {

    @AppStorage("pulse.onboarding.completed") private var onboardingCompleted = false
    @State private var currentPage = 0
    @State private var isRequestingPermissions = false
    @State private var permissionsGranted = false

    private let totalPages = 4

    var body: some View {
        ZStack {
            // 暖色调渐变背景
            backgroundGradient

            VStack(spacing: 0) {
                // 页面内容
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    permissionsPage.tag(2)
                    completionPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)

                // 底部控制区
                bottomControls
                    .padding(.horizontal, PulseTheme.spacingL)
                    .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 渐变背景

    private var backgroundGradient: some View {
        ZStack {
            PulseTheme.background

            // 暖色光晕
            RadialGradient(
                colors: [
                    PulseTheme.accent.opacity(0.12),
                    PulseTheme.accent.opacity(0.04),
                    Color.clear,
                ],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    PulseTheme.statusGood.opacity(0.06),
                    Color.clear,
                ],
                center: .bottomLeading,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Page 1: 欢迎

    private var welcomePage: some View {
        VStack(spacing: PulseTheme.spacingL) {
            Spacer()

            // App 图标占位
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Circle()
                    .fill(PulseTheme.cardBackground)
                    .frame(width: 100, height: 100)
                    .shadow(color: PulseTheme.accent.opacity(0.2), radius: 20)

                Image(systemName: "heart.text.clipboard.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.accent, PulseTheme.statusGood],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: PulseTheme.spacingS) {
                Text("Pulse Watch")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text("你的智能健康伙伴")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
            }

            Text("基于 Apple Watch 数据，用 AI 分析你的身体状态\n每天给出个性化的恢复评分和训练建议")
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, PulseTheme.spacingL)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: 功能介绍

    private var featuresPage: some View {
        VStack(spacing: PulseTheme.spacingXL) {
            Spacer()

            Text("核心功能")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)

            VStack(spacing: PulseTheme.spacingL) {
                featureRow(
                    icon: "gauge.open.with.lines.needle.33percent.and.arrowtriangle",
                    color: PulseTheme.accent,
                    title: String(localized: "每日状态评分"),
                    description: String(localized: "综合 HRV、心率、睡眠等数据\n生成 0-100 恢复评分")
                )

                featureRow(
                    icon: "brain.head.profile.fill",
                    color: PulseTheme.statusGood,
                    title: String(localized: "AI 健康洞察"),
                    description: String(localized: "智能分析趋势和异常\n所有计算在设备本地完成")
                )

                featureRow(
                    icon: "dumbbell.fill",
                    color: PulseTheme.statusModerate,
                    title: String(localized: "训练建议"),
                    description: String(localized: "根据恢复状态推荐训练强度\n到达健身房自动提醒")
                )

                featureRow(
                    icon: "applewatch",
                    color: PulseTheme.statusPoor,
                    title: String(localized: "手表联动"),
                    description: String(localized: "表盘 Complication 实时显示\n手腕上即时查看状态")
                )
            }
            .padding(.horizontal, PulseTheme.spacingM)

            Spacer()
            Spacer()
        }
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(description)
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .lineSpacing(2)
            }

            Spacer()
        }
    }

    // MARK: - Page 3: 权限请求

    private var permissionsPage: some View {
        VStack(spacing: PulseTheme.spacingXL) {
            Spacer()

            // 盾牌图标
            ZStack {
                Circle()
                    .fill(PulseTheme.statusGood.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .blur(radius: 15)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(PulseTheme.statusGood)
            }

            VStack(spacing: PulseTheme.spacingS) {
                Text("需要一些权限")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text("你的数据仅存储在设备上\n我们不会上传任何信息")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // 权限列表
            VStack(spacing: PulseTheme.spacingM) {
                permissionRow(
                    icon: "heart.fill",
                    title: "HealthKit",
                    description: String(localized: "读取心率、HRV、睡眠等健康数据"),
                    granted: permissionsGranted
                )

                permissionRow(
                    icon: "bell.fill",
                    title: String(localized: "通知"),
                    description: String(localized: "发送每日健康摘要和异常提醒"),
                    granted: permissionsGranted
                )

                permissionRow(
                    icon: "location.fill",
                    title: String(localized: "位置"),
                    description: String(localized: "到达健身房时智能提醒训练计划"),
                    granted: permissionsGranted
                )
            }
            .padding(.horizontal, PulseTheme.spacingM)

            // 一键授权按钮
            Button {
                requestAllPermissions()
            } label: {
                HStack(spacing: PulseTheme.spacingS) {
                    if isRequestingPermissions {
                        ProgressView()
                            .tint(PulseTheme.background)
                    } else if permissionsGranted {
                        Image(systemName: "checkmark.circle.fill")
                        Text("已授权")
                    } else {
                        Image(systemName: "hand.raised.fill")
                        Text("一键授权")
                    }
                }
            }
            .buttonStyle(PulseButtonStyle())
            .disabled(isRequestingPermissions || permissionsGranted)
            .padding(.horizontal, PulseTheme.spacingL)

            Spacer()
        }
    }

    private func permissionRow(icon: String, title: String, description: String, granted: Bool) -> some View {
        HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.accent.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PulseTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(description)
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(PulseTheme.statusGood)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(granted ? PulseTheme.statusGood.opacity(0.2) : PulseTheme.border.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Page 4: 完成

    private var completionPage: some View {
        VStack(spacing: PulseTheme.spacingL) {
            Spacer()

            // 庆祝图标
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .blur(radius: 25)

                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.accent, PulseTheme.statusGood],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: PulseTheme.spacingS) {
                Text("一切就绪")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text("Pulse Watch 正在后台收集你的健康数据\n几小时后就能看到你的第一份状态评分")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, PulseTheme.spacingM)
            }

            Spacer()

            // 开始使用
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    onboardingCompleted = true
                }
            } label: {
                Text("开始使用")
            }
            .buttonStyle(PulseButtonStyle())
            .padding(.horizontal, PulseTheme.spacingL)

            Spacer()
        }
    }

    // MARK: - 底部控制

    private var bottomControls: some View {
        HStack {
            // 跳过按钮（最后一页不显示）
            if currentPage < totalPages - 1 {
                Button {
                    withAnimation {
                        onboardingCompleted = true
                    }
                } label: {
                    Text("跳过")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            } else {
                Spacer().frame(width: 44)
            }

            Spacer()

            // 页面指示器
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? PulseTheme.accent : PulseTheme.border)
                        .frame(width: index == currentPage ? 20 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            Spacer()

            // 下一步按钮（最后一页不显示）
            if currentPage < totalPages - 1 {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        currentPage += 1
                    }
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(PulseTheme.accent)
                }
            } else {
                Spacer().frame(width: 44)
            }
        }
    }

    // MARK: - 权限请求

    private func requestAllPermissions() {
        isRequestingPermissions = true

        Task {
            // HealthKit
            try? await HealthKitService.shared.requestAuthorization()

            // 通知
            let _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])

            // 位置（先请求 whenInUse，再升级到 always 用于地理围栏）
            LocationManager.shared.requestAlwaysAuthorization()

            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isRequestingPermissions = false
                    permissionsGranted = true
                }

                // 自动翻到下一页
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        currentPage = 3
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}
