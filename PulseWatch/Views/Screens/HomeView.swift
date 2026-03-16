import SwiftUI
import SwiftData

/// Main iPhone screen — the daily command center
struct HomeView: View {

    @State private var healthManager = HealthKitManager.shared
    @State private var connectivityManager = WatchConnectivityManager.shared
    @State private var isLoading = true
    @State private var brief: ScoreEngine.DailyBrief?
    @State private var showLocationSetup = false
    @State private var showGymPrompt = false
    @State private var breathe = false

    @Query(sort: \WorkoutRecord.date, order: .reverse) private var recentWorkouts: [WorkoutRecord]
    @Query private var savedLocations: [SavedLocation]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseTheme.spacingM) {
                    // Greeting
                    greetingSection
                        .staggered(index: 0)

                    // Hero status card
                    if let brief {
                        StatusCard(
                            score: brief.score,
                            headline: brief.headline,
                            insight: brief.insight
                        )
                        .staggered(index: 1)
                    } else if isLoading {
                        loadingCard
                    }

                    // Metrics
                    MetricsCard(
                        heartRate: healthManager.latestHeartRate,
                        hrv: healthManager.latestHRV,
                        bloodOxygen: healthManager.latestBloodOxygen,
                        steps: healthManager.todaySteps,
                        calories: healthManager.todayActiveCalories,
                        sleepSummary: brief?.sleepSummary
                    )
                    .staggered(index: 2)

                    // Training plan
                    if let plan = brief?.trainingPlan, plan.targetMuscleGroup != "rest" {
                        TrainingCard(plan: plan)
                            .staggered(index: 3)
                    }

                    // Recovery note
                    if let note = brief?.recoveryNote {
                        RecoveryCard(note: note)
                            .staggered(index: 4)
                    }

                    // Gym setup prompt if no gym saved
                    if !hasGymLocation {
                        gymSetupPrompt
                            .staggered(index: 5)
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.spacingM)
            }
            .background(
                ZStack {
                    PulseTheme.background
                    // Ambient warm glow — subtle breathing
                    if let brief {
                        PulseTheme.ambientGradient(for: brief.score)
                            .scaleEffect(breathe ? 1.05 : 1.0)
                            .ignoresSafeArea()
                    }
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLocationSetup = true
                    } label: {
                        Image(systemName: "location.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
            }
            .sheet(isPresented: $showLocationSetup) {
                LocationSetupView()
            }
            .alert(String(localized: "Arrived at Gym"), isPresented: $showGymPrompt) {
                Button("OK") {}
            } message: {
                if let plan = brief?.trainingPlan {
                    Text("建议今天练\(localizedGroup(plan.targetMuscleGroup))，已通知手表")
                } else {
                    Text("Watch notified")
                }
            }
            .task {
                await loadData()
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
            .refreshable {
                await loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didEnterSavedRegion)) { notification in
                handleGeofenceEntry(notification)
            }
        }
    }

    // MARK: - Subviews

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                Text(greeting)
                    .font(PulseTheme.titleFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(dateString)
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            Spacer()
        }
        .padding(.top, PulseTheme.spacingM)
    }

    private var loadingCard: some View {
        RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
            .fill(PulseTheme.cardBackground)
            .frame(height: 140)
            .shadow(color: PulseTheme.cardShadow, radius: 16, y: 6)
            .overlay(
                ProgressView()
                    .tint(PulseTheme.accent)
            )
    }

    private var gymSetupPrompt: some View {
        Button {
            showLocationSetup = true
        } label: {
            HStack(spacing: PulseTheme.spacingM) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PulseTheme.accent.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: "mappin.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PulseTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Gym Location")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)

                    Text("Auto-remind when arriving")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            .padding(PulseTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.cardBackground)
                    .shadow(color: PulseTheme.cardShadow.opacity(0.3), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .stroke(PulseTheme.accent.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed

    private var hasGymLocation: Bool {
        savedLocations.contains { $0.locationType == "gym" && $0.isActive }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return String(localized: "Good Morning")
        case 12..<14: return String(localized: "Good Afternoon")
        case 14..<18: return String(localized: "Good Afternoon")
        case 18..<22: return String(localized: "Good Evening")
        default: return String(localized: "Late Night")
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: .now)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        do {
            try await healthManager.requestAuthorization()
            await healthManager.refreshAll()

            let sleep = try await healthManager.fetchLastNightSleep()

            brief = ScoreEngine.generateBrief(
                hrv: healthManager.latestHRV,
                restingHR: healthManager.latestRestingHR,
                bloodOxygen: healthManager.latestBloodOxygen,
                sleepMinutes: sleep.total,
                deepSleepMinutes: sleep.deep,
                remSleepMinutes: sleep.rem,
                steps: healthManager.todaySteps,
                recentWorkouts: recentWorkouts
            )

            // Sync to Watch
            if let brief {
                connectivityManager.sendHealthSummary(
                    score: brief.score,
                    headline: brief.headline,
                    insight: brief.insight,
                    heartRate: Int(healthManager.latestHeartRate ?? 0),
                    steps: healthManager.todaySteps
                )
            }
        } catch {
            print("Load error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Geofence Handling

    private func handleGeofenceEntry(_ notification: Notification) {
        guard let regionId = notification.userInfo?["regionId"] as? String else { return }

        // Find the matching gym location
        guard let location = savedLocations.first(where: {
            $0.id.uuidString == regionId && $0.locationType == "gym"
        }) else { return }

        // Send gym arrival to Watch
        let group = brief?.trainingPlan?.targetMuscleGroup ?? "chest"
        let reason = brief?.trainingPlan?.reason ?? "到达\(location.name)"

        connectivityManager.sendGymArrival(muscleGroup: group, reason: reason)
        showGymPrompt = true
    }

    private func localizedGroup(_ group: String) -> String {
        switch group {
        case "chest": return String(localized: "Chest")
        case "back": return String(localized: "Back")
        case "legs": return String(localized: "Legs")
        case "shoulders": return String(localized: "Shoulders")
        default: return group
        }
    }
}

// MARK: - Location Setup

struct LocationSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var locationManager = LocationManager.shared
    @State private var isSaving = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            VStack(spacing: PulseTheme.spacingL) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(PulseTheme.accent.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(PulseTheme.accent)
                }

                Text("Set Frequent Location")
                    .font(PulseTheme.titleFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                Text("Add gym location\nPulse will remind you when you arrive")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                if saved {
                    HStack(spacing: PulseTheme.spacingS) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseTheme.statusGood)
                        Text("Saved")
                            .foregroundStyle(PulseTheme.statusGood)
                    }
                    .font(PulseTheme.bodyFont)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        saveGymLocation()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(PulseTheme.background)
                        } else {
                            Text("Add gym using current location")
                        }
                    }
                    .buttonStyle(PulseButtonStyle())
                    .disabled(isSaving)
                }

                Button("Set Up Later") {
                    dismiss()
                }
                .foregroundStyle(PulseTheme.textTertiary)
                .padding(.bottom, PulseTheme.spacingL)
            }
            .padding(.horizontal, PulseTheme.spacingL)
            .background(PulseTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }

    private func saveGymLocation() {
        isSaving = true
        locationManager.requestAuthorization()

        // Brief delay for location to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let location = locationManager.saveCurrentAsLocation(
                name: String(localized: "Gym"),
                type: "gym",
                radius: 100
            ) {
                modelContext.insert(location)
                locationManager.registerGeofence(for: location)

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    saved = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
            isSaving = false
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
