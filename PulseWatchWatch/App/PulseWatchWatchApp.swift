import SwiftUI
import SwiftData

@main
struct PulseWatchWatchApp: App {

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
        Analytics.initialize()

        WatchConnectivityManager.shared.activate()

        // 注入 ModelContainer 到数据服务
        let container = sharedModelContainer
        HealthKitService.shared.modelContainer = container
        HealthDataService.shared.modelContainer = container

        // Watch 端也启动后台采集
        HealthKitService.shared.enableBackgroundDelivery()
        HealthKitService.shared.startObserving()

        Task {
            try? await HealthKitService.shared.requestAuthorization()
            await HealthKitService.shared.performInitialFetch()
        }
    }

    @State private var showSummary = false

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchHomeView()
                    .navigationDestination(isPresented: $showSummary) {
                        SummaryView()
                    }
            }
            .onOpenURL { url in
                // Complication 点击跳转到摘要视图
                if url.absoluteString == "pulse://summary" {
                    showSummary = true
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
