import SwiftUI

/// 首次启动引导流程 — 4 页，每页一个核心功能
/// Page 1: 每日评分 (Recovery Score)
/// Page 2: 趋势图 (Weekly Trends)
/// Page 3: 训练记录 (Workout History)
/// Page 4: AI 教练 (AI Coach) + 开始按钮
struct OnboardingView: View {

    @AppStorage("pulse.onboarding.completed") private var onboardingCompleted = false
    @State private var currentPage = 0

    private let totalPages = 4

    var body: some View {
        ZStack {
            backgroundGradient(for: currentPage)
                .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    scorePage.tag(0)
                    trendsPage.tag(1)
                    workoutPage.tag(2)
                    coachPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)

                bottomControls
                    .padding(.horizontal, PulseTheme.spacingL)
                    .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Dynamic Background

    private func backgroundGradient(for page: Int) -> some View {
        let colors: [(top: Color, bottom: Color)] = [
            (PulseTheme.accent, PulseTheme.statusGood),       // Score: gold → green
            (Color(hex: "5B8DEF"), PulseTheme.accent),         // Trends: blue → gold
            (PulseTheme.statusModerate, PulseTheme.statusPoor),// Workout: amber → terracotta
            (PulseTheme.statusGood, Color(hex: "5B8DEF")),     // Coach: green → blue
        ]
        let pair = colors[min(page, colors.count - 1)]

        return ZStack {
            PulseTheme.background.ignoresSafeArea()

            RadialGradient(
                colors: [pair.top.opacity(0.12), pair.top.opacity(0.03), Color.clear],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [pair.bottom.opacity(0.06), Color.clear],
                center: .bottomLeading,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Page 1: 每日评分

    private var scorePage: some View {
        OnboardingPageView(
            icon: "gauge.open.with.lines.needle.33percent.and.arrowtriangle",
            iconColors: [PulseTheme.accent, PulseTheme.statusGood],
            title: String(localized: "Daily Recovery Score"),
            subtitle: String(localized: "Know your body's readiness"),
            description: String(localized: "Combines heart rate, HRV, and sleep quality into a single 0-100 score every morning. Green means go hard, red means rest."),
            illustration: { scoreIllustration }
        )
    }

    private var scoreIllustration: some View {
        ZStack {
            // Score ring
            Circle()
                .stroke(PulseTheme.border.opacity(0.3), lineWidth: 8)
                .frame(width: 140, height: 140)

            Circle()
                .trim(from: 0, to: 0.82)
                .stroke(
                    LinearGradient(
                        colors: [PulseTheme.statusGood, PulseTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("82")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text("Good")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.statusGood)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Example recovery score of 82 out of 100, rated Good"))
    }

    // MARK: - Page 2: 趋势图

    private var trendsPage: some View {
        OnboardingPageView(
            icon: "chart.xyaxis.line",
            iconColors: [Color(hex: "5B8DEF"), PulseTheme.accent],
            title: String(localized: "Weekly Trends"),
            subtitle: String(localized: "See your progress over time"),
            description: String(localized: "7-day charts for heart rate, HRV, and sleep. Spot patterns, track improvement, and share your gains."),
            illustration: { trendIllustration }
        )
    }

    private var trendIllustration: some View {
        // Mini sparkline chart
        let points: [CGFloat] = [0.4, 0.5, 0.35, 0.6, 0.55, 0.75, 0.82]
        let days = ["M", "T", "W", "T", "F", "S", "S"]

        return VStack(spacing: PulseTheme.spacingS) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let step = w / CGFloat(points.count - 1)

                // Gradient fill under line
                Path { path in
                    for (i, pt) in points.enumerated() {
                        let x = step * CGFloat(i)
                        let y = h * (1 - pt)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "5B8DEF").opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    for (i, pt) in points.enumerated() {
                        let x = step * CGFloat(i)
                        let y = h * (1 - pt)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "5B8DEF"), PulseTheme.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                // Dots
                ForEach(0..<points.count, id: \.self) { i in
                    Circle()
                        .fill(i == points.count - 1 ? PulseTheme.accent : Color(hex: "5B8DEF"))
                        .frame(width: 8, height: 8)
                        .position(x: step * CGFloat(i), y: h * (1 - points[i]))
                }
            }
            .frame(height: 100)
            .padding(.horizontal, PulseTheme.spacingM)

            // Day labels
            HStack {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, PulseTheme.spacingM)
        }
        .frame(width: 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Example 7-day trend chart showing improving health data"))
    }

    // MARK: - Page 3: 训练记录

    private var workoutPage: some View {
        OnboardingPageView(
            icon: "dumbbell.fill",
            iconColors: [PulseTheme.statusModerate, PulseTheme.statusPoor],
            title: String(localized: "Training Records"),
            subtitle: String(localized: "Every rep counts"),
            description: String(localized: "Auto-syncs workouts from Apple Watch. Heart rate zones, calories, duration — all saved and shareable."),
            illustration: { workoutIllustration }
        )
    }

    private var workoutIllustration: some View {
        VStack(spacing: PulseTheme.spacingS) {
            workoutRow(icon: "figure.run", name: String(localized: "Running"), duration: "32 min", cal: "320 kcal", color: PulseTheme.statusPoor)
            workoutRow(icon: "figure.strengthtraining.traditional", name: String(localized: "Strength"), duration: "48 min", cal: "280 kcal", color: PulseTheme.statusModerate)
            workoutRow(icon: "figure.outdoor.cycle", name: String(localized: "Cycling"), duration: "25 min", cal: "210 kcal", color: PulseTheme.statusGood)
        }
        .frame(width: 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Example workout list showing Running, Strength, and Cycling sessions"))
    }

    private func workoutRow(icon: String, name: String, duration: String, cal: String, color: Color) -> some View {
        HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(duration)
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textSecondary)
            }

            Spacer()

            Text(cal)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.border.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Page 4: AI 教练 + 开始按钮

    private var coachPage: some View {
        VStack(spacing: PulseTheme.spacingL) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(PulseTheme.statusGood.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.statusGood, Color(hex: "5B8DEF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Title area
            VStack(spacing: PulseTheme.spacingS) {
                Text("AI Coach")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text("Your personal fitness advisor")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.statusGood)
            }

            Text("Personalized training advice based on your recovery. Push day or rest day? AI analyzes your data and tells you exactly what to do.")
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, PulseTheme.spacingXL)

            // Coach bubble illustration
            coachIllustration

            Spacer()

            // Get Started button
            Button {
                requestPermissionsAndStart()
            } label: {
                Text("Get Started")
            }
            .buttonStyle(PulseButtonStyle())
            .padding(.horizontal, PulseTheme.spacingL)
            .accessibilityLabel(String(localized: "Get Started"))
            .accessibilityHint(String(localized: "Requests health permissions and starts the app"))

            Spacer()
        }
    }

    private var coachIllustration: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
            chatBubble(
                text: String(localized: "Recovery 82 — great day for strength training! 💪"),
                isAI: true
            )
            chatBubble(
                text: String(localized: "HRV trending up 12% this week. Keep it up."),
                isAI: true
            )
        }
        .padding(.horizontal, PulseTheme.spacingXL)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Example AI Coach messages: personalized training advice based on your recovery data"))
    }

    private func chatBubble(text: String, isAI: Bool) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            if isAI {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PulseTheme.statusGood)
            }

            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PulseTheme.statusGood.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            // Skip (hidden on last page)
            if currentPage < totalPages - 1 {
                Button {
                    completeOnboarding()
                } label: {
                    Text("Skip")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
                .accessibilityLabel(String(localized: "Skip onboarding"))
                .accessibilityHint(String(localized: "Skips the introduction and goes to the main app"))
            } else {
                Spacer().frame(width: 44)
            }

            Spacer()

            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? PulseTheme.accent : PulseTheme.border)
                        .frame(width: index == currentPage ? 20 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Page \(currentPage + 1) of \(totalPages)"))

            Spacer()

            // Next arrow (hidden on last page)
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
                .accessibilityLabel(String(localized: "Next page"))
                .accessibilityHint(String(localized: "Goes to the next introduction page"))
            } else {
                Spacer().frame(width: 44)
            }
        }
    }

    // MARK: - Actions

    /// Request permissions button accessibility
    private func requestPermissionsAndStart() {
        Task {
            // HealthKit
            try? await HealthKitService.shared.requestAuthorization()

            // Notifications
            let _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])

            // Location (for gym geo-fence)
            LocationManager.shared.requestAuthorization()

            await MainActor.run {
                completeOnboarding()
            }
        }
    }

    private func completeOnboarding() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            onboardingCompleted = true
            Analytics.trackOnboardingCompleted()
        }
    }
}

// MARK: - Reusable Page Template

private struct OnboardingPageView<Illustration: View>: View {
    let icon: String
    let iconColors: [Color]
    let title: String
    let subtitle: String
    let description: String
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        VStack(spacing: PulseTheme.spacingL) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(iconColors.first?.opacity(0.08) ?? Color.clear)
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Title area
            VStack(spacing: PulseTheme.spacingS) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(iconColors.first ?? PulseTheme.accent)
            }

            Text(description)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, PulseTheme.spacingXL)

            // Illustration
            illustration()
                .padding(.top, PulseTheme.spacingM)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
