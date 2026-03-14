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

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
        .modelContainer(sharedModelContainer)
    }
}
