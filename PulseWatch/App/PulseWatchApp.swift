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

        // HealthKit 后台采集
        HealthKitService.shared.enableBackgroundDelivery()
        HealthKitService.shared.startObserving()

        // Morning Brief 通知系统
        MorningBriefService.shared.setup()

        // App Store 评价引导 — 记录活跃天数
        Task { @MainActor in
            ReviewManager.shared.recordAppActive()
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

// MARK: - 主 Tab 导航（3 tabs）

struct MainTabView: View {

    @State private var selectedTab = 0
    init() {
        // 自定义 TabBar 外观
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(PulseTheme.surface)
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Today", systemImage: "heart.text.clipboard")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(PulseTheme.accent)
        .onChange(of: selectedTab) { _, newTab in
            let tabNames = ["Today", "Trends", "Settings"]
            let name = newTab < tabNames.count ? tabNames[newTab] : "unknown"
            Analytics.trackTabSwitch(to: name)
            if newTab == 2 {
                Analytics.trackSettingsOpened()
            }
        }
    }
}
