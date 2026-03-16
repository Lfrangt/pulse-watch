import SwiftUI
import SwiftData

@main
struct PulseWatchApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            HealthSnapshot.self,
            WorkoutRecord.self,
            SavedLocation.self,
            HealthRecord.self,
            DailySummary.self,
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
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // 处理 OpenClaw URL Scheme 请求
                    Task { @MainActor in
                        _ = OpenClawBridge.shared.handleURL(url)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
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
            let tabNames = ["今日", "趋势", "设置"]
            let name = newTab < tabNames.count ? tabNames[newTab] : "unknown"
            Analytics.trackTabSwitch(to: name)
            if newTab == 2 {
                Analytics.trackSettingsOpened()
            }
        }
    }
}
