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

        Task {
            try? await HealthKitService.shared.requestAuthorization()
            await HealthKitService.shared.performInitialFetch()
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - 主 Tab 导航

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
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "heart.text.clipboard")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .tint(PulseTheme.accent)
    }
}
