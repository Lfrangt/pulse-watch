import SwiftUI
import SwiftData

/// Main iPhone screen — the daily command center
struct HomeView: View {
    
    @State private var healthManager = HealthKitManager.shared
    @State private var isLoading = true
    @State private var brief: ScoreEngine.DailyBrief?
    @State private var showLocationSetup = false
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseTheme.spacingM) {
                    // Greeting
                    greetingSection
                    
                    // Hero status card
                    if let brief {
                        StatusCard(
                            score: brief.score,
                            headline: brief.headline,
                            insight: brief.insight
                        )
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
                    
                    // Training plan
                    if let plan = brief?.trainingPlan, plan.targetMuscleGroup != "rest" {
                        TrainingCard(plan: plan)
                    }
                    
                    // Recovery note
                    if let note = brief?.recoveryNote {
                        recoveryCard(note: note)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, PulseTheme.spacingM)
            }
            .background(PulseTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLocationSetup = true
                    } label: {
                        Image(systemName: "location.circle")
                            .foregroundStyle(PulseTheme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showLocationSetup) {
                LocationSetupView()
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
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
        RoundedRectangle(cornerRadius: PulseTheme.radiusL)
            .fill(PulseTheme.cardBackground)
            .frame(height: 140)
            .overlay(
                ProgressView()
                    .tint(PulseTheme.accent)
            )
    }
    
    private func recoveryCard(note: String) -> some View {
        HStack(spacing: PulseTheme.spacingM) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(PulseTheme.statusModerate)
            
            Text(note)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
            
            Spacer()
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM)
                .fill(PulseTheme.statusModerate.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusM)
                        .stroke(PulseTheme.statusModerate.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Helpers
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "早上好"
        case 12..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<22: return "晚上好"
        default: return "夜深了"
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: .now)
    }
    
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
                recentWorkouts: [] // TODO: fetch from SwiftData
            )
        } catch {
            print("Load error: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Location Setup (placeholder)

struct LocationSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var locationManager = LocationManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: PulseTheme.spacingL) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PulseTheme.accent)
                
                Text("设置常去地点")
                    .font(PulseTheme.titleFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                
                Text("添加健身房、学校、家等位置\nPulse 会在你到达时智能提醒")
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button("使用当前位置添加健身房") {
                    // TODO: save current location as gym
                    dismiss()
                }
                .buttonStyle(PulseButtonStyle())
                
                Button("稍后设置") {
                    dismiss()
                }
                .foregroundStyle(PulseTheme.textTertiary)
                .padding(.bottom)
            }
            .padding(PulseTheme.spacingL)
            .background(PulseTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Button Style

struct PulseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PulseTheme.bodyFont)
            .foregroundStyle(PulseTheme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM)
                    .fill(PulseTheme.accent)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
}
