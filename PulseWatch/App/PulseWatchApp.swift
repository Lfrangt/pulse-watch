import SwiftUI
import SwiftData
import UIKit

@main
struct PulseWatchApp: App {

    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            HealthSnapshot.self,
            WorkoutRecord.self,
            SavedLocation.self,
            HealthRecord.self,
            DailySummary.self,
            WorkoutHistoryEntry.self,
            HeartRateAlertEvent.self,
            StrengthRecord.self,
            HealthGoal.self,
            TrainingChallenge.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Analytics
        Analytics.initialize()
        Analytics.trackAppLaunch()

        // 网络与位置
        WatchConnectivityManager.shared.activate()
        LocationManager.shared.requestAuthorization()
        GymCoordinator.shared.startListening()

        // 注入 ModelContainer 到数据服务
        let container = sharedModelContainer
        HealthKitService.shared.modelContainer = container
        HealthDataService.shared.modelContainer = container
        WorkoutHistoryService.shared.modelContainer = container
        OpenClawBridge.shared.modelContainer = container

        // HealthKit 后台采集
        HealthKitService.shared.enableBackgroundDelivery()
        HealthKitService.shared.startObserving()

        // Morning Brief 通知系统
        MorningBriefService.shared.setup()

        // Weekly Health Summary 通知
        WeeklySummaryService.shared.scheduleWeeklySummary()

        // Weekly PB Reminder
        AchievementService.shared.scheduleWeeklyPBReminder()

        // 心率异常提醒
        HeartRateAlertService.shared.modelContainer = container
        HeartRateAlertService.shared.registerCategory()

        // Background health data sync to OpenClaw
        OpenClawBridge.shared.registerBackgroundSync()

        // Auto-reconnect to OpenClaw gateway (saved creds + subnet discovery)
        Task {
            await OpenClawBridge.shared.attemptAutoReconnect()
        }

        // App Store 评价引导 — 记录活跃天数
        Task { @MainActor in
            ReviewRequestManager.shared.recordAppActive()
        }

        Task {
            try? await HealthKitService.shared.requestAuthorization()
            await HealthKitService.shared.performInitialFetch()
            // 训练历史同步 — 每次启动时增量同步
            await WorkoutHistoryService.shared.syncWorkouts()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    Task { @MainActor in
                        _ = OpenClawBridge.shared.handleURL(url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .watchWorkoutCompleted)) { notification in
                    // Watch workout ended → sync HealthKit + push Watch data to OpenClaw immediately
                    Task {
                        await WorkoutHistoryService.shared.syncWorkouts()
                        await MainActor.run {
                            ReviewRequestManager.shared.recordWorkoutCompleted()
                            if let data = notification.userInfo as? [String: Any] {
                                OpenClawBridge.shared.handleWatchWorkoutCompleted(data)
                            }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .watchHealthSnapshotReceived)) { notification in
                    // Watch pushed fresh health data → forward to OpenClaw bridge
                    Task { @MainActor in
                        if let data = notification.userInfo as? [String: Any] {
                            OpenClawBridge.shared.handleWatchHealthSnapshot(data)
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Re-check notification permission when returning from Settings
                MorningBriefService.shared.refreshAuthorizationStatus()

                // Re-establish OpenClaw gateway connection
                Task {
                    await OpenClawBridge.shared.attemptAutoReconnect()
                }

                // 检查并处理 OpenClaw pending workouts（每次前台都检查）
                Task {
                    await OpenClawBridge.shared.checkAndProcessPendingIfNeeded()
                }
            }
        }
    }
}

// MARK: - 根视图（Onboarding 判断）

struct RootView: View {
    @AppStorage("pulse.onboarding.completed") private var onboardingCompleted = false

    var body: some View {
        if onboardingCompleted {
            MainTabView()
                .transition(.opacity)
        } else {
            OnboardingView()
                .transition(.opacity)
        }
    }
}

// MARK: - 主 Tab 导航（4 tabs）

struct MainTabView: View {

    @State private var selectedTab = 0
    init() {
        // 自定义 TabBar 外观
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(PulseTheme.background)
        appearance.shadowColor = .clear
        // Remove iOS 18 tab selection background pill
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(PulseTheme.textTertiary)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(PulseTheme.textTertiary)]
        itemAppearance.selected.iconColor = UIColor(PulseTheme.accent)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(PulseTheme.accent)]
        appearance.selectionIndicatorTintColor = UIColor.white.withAlphaComponent(0.1)
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(String(localized: "Today"), systemImage: "heart.text.clipboard")
                        .accessibilityLabel(String(localized: "Today"))
                        .accessibilityHint(String(localized: "Opens your dashboard"))
                }
                .tag(0)

            WorkoutView()
                .tabItem {
                    Label(String(localized: "Exercise"), systemImage: "figure.run")
                        .accessibilityLabel(String(localized: "Exercise"))
                        .accessibilityHint(String(localized: "Opens your workouts and training history"))
                }
                .tag(1)

            HistoryView()
                .tabItem {
                    Label(String(localized: "Trends"), systemImage: "chart.xyaxis.line")
                        .accessibilityLabel(String(localized: "Trends"))
                        .accessibilityHint(String(localized: "Opens historical trends and reports"))
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(String(localized: "Settings"), systemImage: "gearshape.fill")
                        .accessibilityLabel(String(localized: "Settings"))
                        .accessibilityHint(String(localized: "Opens app settings"))
                }
                .tag(3)
        }
        .tint(PulseTheme.accent)
        .onChange(of: selectedTab) { _, newTab in
            let tabNames = ["Today", "Exercise", "Trends", "Settings"]
            let name = newTab < tabNames.count ? tabNames[newTab] : "unknown"
            Analytics.trackTabSwitch(to: name)
            if newTab == 3 {
                Analytics.trackSettingsOpened()
            }
        }
        // Morning Brief deep link → Dashboard (tab 0)
        .onReceive(NotificationCenter.default.publisher(for: .morningBriefTapped)) { _ in
            selectedTab = 0
        }
    }
}
