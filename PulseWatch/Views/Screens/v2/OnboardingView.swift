import SwiftUI

/// 首次启动引导流程 — 4 页，每页一个核心功能
/// Page 1: 每日评分 (Recovery Score)
/// Page 2: 趋势图 (Weekly Trends)
/// Page 3: 训练记录 (Workout History)
/// Page 4: AI 教练 (AI Coach) + 开始按钮
struct OnboardingView: View {

    @AppStorage("pulse.onboarding.completed") private var onboardingCompleted = false
    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let totalPages = 4

    var body: some View {
        ZStack {
            backgroundGradient(for: currentPage)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    scorePage.tag(0)
                    trendsPage.tag(1)
                    workoutPage.tag(2)
                    coachPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: currentPage)

                bottomControls
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.bottom, DS.Spacing.m)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Dynamic Background

    private func backgroundGradient(for page: Int) -> some View {
        let colors: [(top: Color, bottom: Color)] = [
            (DS.Color.accent, DS.Color.good),       // Score: gold → green
            (DS.Color.accent, DS.Color.accent),         // Trends: blue → gold
            (DS.Color.warn, DS.Color.bad),// Workout: amber → terracotta
            (DS.Color.good, DS.Color.accent),     // Coach: green → blue
        ]
        let pair = colors[min(page, colors.count - 1)]

        return ZStack {
            DS.Color.bg.ignoresSafeArea()

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
            iconColors: [DS.Color.accent, DS.Color.good],
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
                .stroke(DS.Color.line.opacity(0.3), lineWidth: 8)
                .frame(width: DS.Spacing.xxl * 3 + DS.Spacing.l, height: DS.Spacing.xxl * 3 + DS.Spacing.l)

            Circle()
                .trim(from: 0, to: 0.82)
                .stroke(
                    LinearGradient(
                        colors: [DS.Color.good, DS.Color.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: DS.Spacing.xxl * 3 + DS.Spacing.l, height: DS.Spacing.xxl * 3 + DS.Spacing.l)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("82")
                    .font(DS.Typography.display3)
                    .foregroundStyle(DS.Color.ink)

                Text("Good")
                    .font(DS.Typography.bodyS.weight(.medium))
                    .foregroundStyle(DS.Color.good)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Example recovery score of 82 out of 100, rated Good"))
    }

    // MARK: - Page 2: 趋势图

    private var trendsPage: some View {
        OnboardingPageView(
            icon: "chart.xyaxis.line",
            iconColors: [DS.Color.accent, DS.Color.accent],
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

        return VStack(spacing: DS.Spacing.s) {
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
                        colors: [DS.Color.accent.opacity(0.3), Color.clear],
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
                        colors: [DS.Color.accent, DS.Color.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                // Dots
                ForEach(0..<points.count, id: \.self) { i in
                    Circle()
                        .fill(i == points.count - 1 ? DS.Color.accent : DS.Color.accent)
                        .frame(width: DS.Spacing.s, height: DS.Spacing.s)
                        .position(x: step * CGFloat(i), y: h * (1 - points[i]))
                }
            }
            .frame(height: 100)
            .padding(.horizontal, DS.Spacing.m)

            // Day labels
            HStack {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Color.inkDim)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DS.Spacing.m)
        }
        .frame(width: 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Example 7-day trend chart showing improving health data"))
    }

    // MARK: - Page 3: 训练记录

    private var workoutPage: some View {
        OnboardingPageView(
            icon: "dumbbell.fill",
            iconColors: [DS.Color.warn, DS.Color.bad],
            title: String(localized: "Training Records"),
            subtitle: String(localized: "Every rep counts"),
            description: String(localized: "Auto-syncs workouts from Apple Watch. Heart rate zones, calories, duration — all saved and shareable."),
            illustration: { workoutIllustration }
        )
    }

    private var workoutIllustration: some View {
        VStack(spacing: DS.Spacing.s) {
            workoutRow(icon: "figure.run", name: String(localized: "Running"), duration: "32 min", cal: "320 kcal", color: DS.Color.bad)
            workoutRow(icon: "figure.strengthtraining.traditional", name: String(localized: "Strength"), duration: "48 min", cal: "280 kcal", color: DS.Color.warn)
            workoutRow(icon: "figure.outdoor.cycle", name: String(localized: "Cycling"), duration: "25 min", cal: "210 kcal", color: DS.Color.good)
        }
        .frame(width: 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Example workout list showing Running, Strength, and Cycling sessions"))
    }

    private func workoutRow(icon: String, name: String, duration: String, cal: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: DS.Spacing.xxl, height: DS.Spacing.xxl)

                Image(systemName: icon)
                    .font(DS.Typography.bodyL.weight(.medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)

                Text(duration)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.inkMid)
            }

            Spacer()

            Text(cal)
                .font(DS.Typography.bodyS.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                .fill(DS.Color.bgElev)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                .stroke(DS.Color.line.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Page 4: AI 教练 + 开始按钮

    private var coachPage: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(DS.Color.good.opacity(0.08))
                    .frame(width: DS.Spacing.xxl * 2 + DS.Spacing.l, height: DS.Spacing.xxl * 2 + DS.Spacing.l)
                    .blur(radius: 20)

                Image(systemName: "brain.head.profile.fill")
                    .font(DS.Typography.display3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DS.Color.good, DS.Color.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Title area
            VStack(spacing: DS.Spacing.s) {
                Text("AI Coach")
                    .font(DS.Typography.title1.weight(.bold))
                    .foregroundStyle(DS.Color.ink)

                Text("Your personal fitness advisor")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Color.good)
            }

            Text("Personalized training advice based on your recovery. Push day or rest day? AI analyzes your data and tells you exactly what to do.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.inkMid)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, DS.Spacing.xl)

            // Coach bubble illustration
            coachIllustration

            Spacer()

            // Get Started button
            Button {
                requestPermissionsAndStart()
            } label: {
                Text("Get Started")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.l)
            .accessibilityLabel(String(localized: "Get Started"))
            .accessibilityHint(String(localized: "Requests health permissions and starts the app"))

            Spacer()
        }
    }

    private var coachIllustration: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            chatBubble(
                text: String(localized: "Recovery 82 — great day for strength training! 💪"),
                isAI: true
            )
            chatBubble(
                text: String(localized: "HRV trending up 12% this week. Keep it up."),
                isAI: true
            )
        }
        .padding(.horizontal, DS.Spacing.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Example AI Coach messages: personalized training advice based on your recovery data"))
    }

    private func chatBubble(text: String, isAI: Bool) -> some View {
        HStack(spacing: DS.Spacing.s) {
            if isAI {
                Image(systemName: "brain.head.profile.fill")
                    .font(DS.Typography.bodyS)
                    .foregroundStyle(DS.Color.good)
            }

            Text(text)
                .font(DS.Typography.bodyS)
                .foregroundStyle(DS.Color.ink)
        }
        .padding(DS.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.Color.bgElev)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.Color.good.opacity(0.15), lineWidth: 0.5)
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
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Color.inkDim)
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
                        .fill(index == currentPage ? DS.Color.accent : DS.Color.line)
                        .frame(width: index == currentPage ? 20 : 8, height: 8)
                        .animation(reduceMotion ? nil : .spring(response: 0.3), value: currentPage)
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
                        .font(DS.Typography.title1)
                        .foregroundStyle(DS.Color.accent)
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
        VStack(spacing: DS.Spacing.l) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(iconColors.first?.opacity(0.08) ?? Color.clear)
                    .frame(width: DS.Spacing.xxl * 2 + DS.Spacing.l, height: DS.Spacing.xxl * 2 + DS.Spacing.l)
                    .blur(radius: 20)

                Image(systemName: icon)
                    .font(DS.Typography.display3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Title area
            VStack(spacing: DS.Spacing.s) {
                Text(title)
                    .font(DS.Typography.title1.weight(.bold))
                    .foregroundStyle(DS.Color.ink)

                Text(subtitle)
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(iconColors.first ?? DS.Color.accent)
            }

            Text(description)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.inkMid)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, DS.Spacing.xl)

            // Illustration
            illustration()
                .padding(.top, DS.Spacing.m)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
