import SwiftUI
import SwiftData
import UserNotifications
import HealthKit
import UniformTypeIdentifiers

/// Settings — Clinical v2 layout matching Settings.jsx
/// - Header (title only)
/// - Profile card (avatar + name + chevron)
/// - Grouped sections: each section = eyebrow label above a flush-padding card
///   with hairline-separated rows.
/// - JSX-aligned groups first, Pulse-only extras BEHIND a "More from Pulse" divider.
struct SettingsView: View {

    // MARK: - Persisted settings

    @AppStorage("pulse.brief.enabled") private var morningBriefEnabled = true
    @AppStorage("pulse.brief.hour") private var briefHour = 7
    @AppStorage("pulse.brief.minute") private var briefMinute = 30
    @AppStorage("pulse.weekly.summary.enabled") private var weeklySummaryEnabled = true
    @AppStorage("pulse.training.reminder.enabled") private var trainingReminderEnabled = true
    @AppStorage("pulse.pb.reminder.enabled") private var pbReminderEnabled = true
    @AppStorage("pulse.hr.alert.enabled") private var hrAlertEnabled = true
    @AppStorage("pulse.hr.alert.high") private var hrAlertHigh = 120
    @AppStorage("pulse.hr.alert.low") private var hrAlertLow = 40
    @AppStorage("pulse.openclaw.enabled") private var openClawEnabled = false
    @AppStorage("pulse.demo.enabled") private var demoModeEnabled = false
    @AppStorage("pulse.units") private var unitSystem = "metric"
    @AppStorage("pulse.onboarding.completed") private var onboardingCompleted = false
    @AppStorage("pulse.user.birthYear") private var birthYear = 0
    @AppStorage("pulse.user.birthMonth") private var birthMonth = 0
    @AppStorage("pulse.user.heightCm") private var heightCm: Double = 0
    @AppStorage("pulse.user.weightKg") private var weightKg: Double = 0
    @AppStorage("pulse.user.gender") private var gender = "unset"
    @AppStorage("pulse.user.name") private var userName = ""

    // MARK: - State

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    private let healthManager = HealthKitManager.shared
    @State private var showClearHistoryAlert = false
    @State private var showResetOnboardingAlert = false
    @State private var historyClearSuccess = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showExportShare = false
    @State private var exportError: String?
    @State private var showImportPicker = false
    @State private var importResult: ImportResult?
    @State private var showHRAlertDetail = false
    @State private var showMorningBriefDetail = false
    @State private var showProfileDetail = false
    @State private var showOpenClawDetail = false
    @State private var showQRScanner = false
    @State private var showEnableAICoachAlert = false
    @State private var aiCoachActivating = false
    @State private var aiCoachActivationFailed = false
    @State private var showConnectGoogleHealthAlert = false
    @State private var showDisconnectGoogleHealthAlert = false

    @ObservedObject private var googleHealth = GoogleHealthAuth.shared
    private var googleHealthService = GoogleHealthService.shared

    @AppStorage("pulse.openclaw.gatewayURL") private var savedGatewayURL = ""
    @AppStorage("pulse.openclaw.agentID") private var savedAgentID = "openclaw:main"
    @AppStorage("pulse.openclaw.connected") private var isConnected = false

    @FocusState private var isNumberFieldFocused: Bool

    @Query(sort: \DailySummary.date) private var allDailySummaries: [DailySummary]
    @Query(sort: \StrengthRecord.date) private var allStrengthRecords: [StrengthRecord]
    @Query(sort: \HealthGoal.createdAt) private var allGoals: [HealthGoal]
    @Query private var allWorkoutHistory: [WorkoutHistoryEntry]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Clinical header
                    clinicalHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    // ── JSX-aligned groups
                    VStack(spacing: 24) {
                        profileCard
                            .staggered(index: 0)

                        SettingsGroup(label: String(localized: "Measurement")) {
                            unitsRow
                            firstDayRow
                            appearanceRow
                        }
                        .staggered(index: 1)

                        SettingsGroup(label: String(localized: "Notifications")) {
                            notificationStatusRow
                            morningBriefRow
                            weeklyReportRow
                            trainingReminderRow
                            pbReminderRow
                        }
                        .staggered(index: 2)

                        SettingsGroup(label: String(localized: "Data & Privacy")) {
                            healthKitRow
                            dataExportRow
                            jsonBackupRow
                            pdfReportRow
                            importRestoreRow
                            clearHistoryRow
                        }
                        .staggered(index: 3)

                        SettingsGroup(label: String(localized: "About")) {
                            privacyPolicyRow
                            sendFeedbackRow
                            versionRow
                        }
                        .staggered(index: 4)
                    }
                    .padding(.horizontal, 16)

                    // ── "MORE FROM PULSE" divider
                    moreFromPulseDivider
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                    // ── Pulse-only extras (Goals, Coach, Heart-rate alerts, OpenClaw, Developer, Reset)
                    VStack(spacing: 24) {
                        SettingsGroup(label: String(localized: "Coaching")) {
                            goalsRow
                            coachModeRow
                        }
                        .staggered(index: 5)

                        SettingsGroup(label: String(localized: "Heart Rate Alerts")) {
                            hrAlertEnabledRow
                            if hrAlertEnabled {
                                hrAlertHighRow
                                hrAlertLowRow
                            }
                        }
                        .staggered(index: 6)

                        SettingsGroup(label: String(localized: "AI Coach")) {
                            aiCoachRow
                        }
                        .staggered(index: 7)

                        SettingsGroup(label: String(localized: "Google Health")) {
                            googleHealthRow
                        }
                        .staggered(index: 8)

                        SettingsGroup(label: String(localized: "OpenClaw Integration")) {
                            openClawConnectionRow
                            if OpenClawBridge.shared.config != nil {
                                openClawAutoPushRow
                            }
                        }
                        .staggered(index: 9)

                        SettingsGroup(label: String(localized: "Diagnostics")) {
                            #if DEBUG
                            demoModeRow
                            #endif
                            resetOnboardingRow
                        }
                        .staggered(index: 10)
                    }
                    .padding(.horizontal, 16)

                    // ── Footer
                    versionFooter
                        .padding(.top, 24)

                    Spacer(minLength: 60)
                }
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DS.Color.bg.ignoresSafeArea())
            .navigationBarHidden(true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isNumberFieldFocused = false }
                }
            }
            .task {
                await checkNotificationStatus()
                healthManager.checkAuthorizationStatus()
            }
            .sheet(isPresented: $showProfileDetail) {
                profileDetailSheet
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showHRAlertDetail) {
                hrAlertDetailSheet
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showMorningBriefDetail) {
                morningBriefDetailSheet
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showOpenClawDetail) {
                openClawDetailSheet
                    .preferredColorScheme(.dark)
            }
            .alert(String(localized: "Enable AI Coach"), isPresented: $showEnableAICoachAlert) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Enable")) {
                    aiCoachActivating = true
                    Task {
                        let ok = await OpenClawBridge.shared.enableDeepSeek(
                            apiKey: PulseOpenClawConfig.bundledDeepSeekKey
                        )
                        await MainActor.run {
                            aiCoachActivating = false
                            if !ok {
                                aiCoachActivationFailed = true
                            }
                        }
                    }
                }
            } message: {
                Text(String(localized: "Pulse will send a summary of your health data (recovery score, sleep, resting heart rate, HRV, blood oxygen, steps, calories, and recent workout history) to api.deepseek.com over HTTPS every ~30 minutes to generate personalized training advice. You can disable this anytime from Settings."))
            }
            .alert(String(localized: "Connection Failed"), isPresented: $aiCoachActivationFailed) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(String(localized: "Could not reach DeepSeek. Check your internet connection and try again."))
            }
            .alert(String(localized: "Connect Google Health"), isPresented: $showConnectGoogleHealthAlert) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Connect")) {
                    Task { await googleHealth.connect() }
                }
            } message: {
                Text(String(localized: "Pulse will request read-only access to your Google Health data — heart rate, sleep, blood oxygen, and activity from your Fitbit, Pixel Watch, or other connected devices. Data stays on this device and is never uploaded to Pulse's servers."))
            }
            .alert(String(localized: "Disconnect Google Health?"), isPresented: $showDisconnectGoogleHealthAlert) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Disconnect"), role: .destructive) {
                    googleHealth.disconnect()
                }
            } message: {
                Text(String(localized: "Pulse will stop reading from Google Health. You can reconnect anytime."))
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { url, token, agent in
                    Task {
                        let ok = await OpenClawBridge.shared.pair(
                            gatewayURL: url,
                            token: token,
                            agentID: agent
                        )
                        if ok {
                            savedGatewayURL = url
                            savedAgentID = agent
                            isConnected = true
                            Analytics.trackOpenClawPaired()
                            #if os(iOS)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            #endif
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportShare) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        importResult = try DataExportService.shared.importBackup(from: url, modelContext: modelContext)
                    } catch {
                        exportError = error.localizedDescription
                    }
                case .failure(let error):
                    exportError = error.localizedDescription
                }
            }
            .alert(String(localized: "Clear Workout History?"), isPresented: $showClearHistoryAlert) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Clear All"), role: .destructive) {
                    clearWorkoutHistory()
                }
            } message: {
                Text(String(localized: "This will delete all saved workout history from the app. Health data in Apple Health will not be affected."))
            }
            .alert(String(localized: "Reset Onboarding?"), isPresented: $showResetOnboardingAlert) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Reset"), role: .destructive) {
                    onboardingCompleted = false
                }
            } message: {
                Text(String(localized: "The welcome guide will appear next time you open the app."))
            }
        }
        .background(DS.Color.bg.ignoresSafeArea())
    }

    // MARK: - Header

    private var clinicalHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Settings"))
                .font(DS.Typography.title1)
                .foregroundStyle(DS.Color.ink)
                .tracking(-0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moreFromPulseDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(DS.Color.lineSoft)
                .frame(height: DS.Stroke.hairline)
                .frame(maxWidth: .infinity)
            Text(String(localized: "More from Pulse"))
                .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
            Rectangle()
                .fill(DS.Color.lineSoft)
                .frame(height: DS.Stroke.hairline)
                .frame(maxWidth: .infinity)
        }
    }

    private var versionFooter: some View {
        Text(String(format: String(localized: "Pulse %@ · build %@ · on-device"), appVersion, buildNumber))
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Color.inkDim)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Profile card

    private var profileCard: some View {
        Button {
            showProfileDetail = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(DS.Color.ink)
                        .frame(width: DS.Spacing.xxl + DS.Spacing.s, height: DS.Spacing.xxl + DS.Spacing.s)
                    Text(userInitial)
                        .font(DS.Typography.bodyL.weight(.medium))
                        .foregroundStyle(DS.Color.bg)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(DS.Color.ink)
                    Text(profileSubtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.inkDim)
                        .lineLimit(1)
                }
                Spacer()
                Text("→")
                    .font(DS.Typography.mono)
                    .tracking(DS.Tracking.mono)
                    .foregroundStyle(DS.Color.inkDim)
            }
            .dsCard(padding: DS.Spacing.l)
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        userName.isEmpty ? String(localized: "Set up profile") : userName
    }

    private var userInitial: String {
        guard let first = userName.first else { return "P" }
        return String(first).uppercased()
    }

    private var profileSubtitle: String {
        let totalDays = allDailySummaries.count
        let watchSource = allDailySummaries.last(where: { _ in true }).map { _ in "Apple Watch" } ?? "Apple Watch"
        if totalDays > 0 {
            return String(format: String(localized: "Baseline · %d days · %@"), totalDays, watchSource)
        }
        return String(localized: "Tap to complete your profile")
    }

    // MARK: - Measurement group rows

    private var unitsRow: some View {
        SettingsRow(
            label: String(localized: "Units"),
            valueText: unitSystem == "metric" ? String(localized: "Metric") : String(localized: "Imperial"),
            chevron: false
        ) {
            Picker(String(localized: "Units"), selection: $unitSystem) {
                Text(String(localized: "Metric")).tag("metric")
                Text(String(localized: "Imperial")).tag("imperial")
            }
            .pickerStyle(.menu)
            .tint(DS.Color.accent)
            .labelsHidden()
        }
    }

    private var firstDayRow: some View {
        SettingsRow(
            label: String(localized: "First day"),
            valueText: firstDayLabel,
            chevron: true,
            action: {}
        )
    }

    private var firstDayLabel: String {
        // Pulled from system locale; informational only.
        let cal = Calendar.current
        let weekday = cal.firstWeekday  // 1=Sun, 2=Mon...
        let symbols = cal.weekdaySymbols
        return symbols[(weekday - 1) % 7]
    }

    private var appearanceRow: some View {
        SettingsRow(
            label: String(localized: "Appearance"),
            valueText: String(localized: "System"),
            chevron: true,
            action: {}
        )
    }

    // MARK: - Notification group rows

    private var notificationStatusRow: some View {
        SettingsRow(
            label: String(localized: "Status"),
            valueText: notificationStatusText,
            chevron: notificationStatus == .denied,
            action: notificationStatus == .denied ? { openAppSettings() } : nil
        )
    }

    private var morningBriefRow: some View {
        SettingsToggleRow(
            label: String(localized: "Morning readiness"),
            sub: morningBriefEnabled
                ? String(format: String(localized: "Delivered at %02d:%02d"), briefHour, briefMinute)
                : String(localized: "Daily score and training advice"),
            isOn: $morningBriefEnabled,
            onChange: { newVal in
                MorningBriefService.shared.isEnabled = newVal
            },
            tap: { showMorningBriefDetail = true }
        )
    }

    private var weeklyReportRow: some View {
        SettingsToggleRow(
            label: String(localized: "Weekly report"),
            sub: String(localized: "Sunday 9:00 — score, workouts & trends"),
            isOn: $weeklySummaryEnabled,
            onChange: { newVal in
                WeeklySummaryService.shared.isEnabled = newVal
            }
        )
    }

    private var trainingReminderRow: some View {
        SettingsToggleRow(
            label: String(localized: "Training reminders"),
            sub: String(localized: "Remind you when arriving at gym"),
            isOn: $trainingReminderEnabled
        )
    }

    private var pbReminderRow: some View {
        SettingsToggleRow(
            label: String(localized: "Weekly PB reminder"),
            sub: String(localized: "Sunday 8 PM — record your new PRs"),
            isOn: $pbReminderEnabled,
            onChange: { newVal in
                if newVal {
                    AchievementService.shared.scheduleWeeklyPBReminder()
                } else {
                    AchievementService.shared.cancelWeeklyPBReminder()
                }
            }
        )
    }

    // MARK: - Data & Privacy group rows

    private var healthKitRow: some View {
        SettingsRow(
            label: String(localized: "HealthKit permissions"),
            valueText: healthManager.authorizationStatus.description,
            chevron: !healthManager.isFullyAuthorized,
            action: { openAppSettings() }
        )
    }

    private var dataExportRow: some View {
        SettingsRow(
            label: String(localized: "Export health data"),
            valueText: "CSV",
            chevron: !isExporting,
            trailing: isExporting ? AnyView(ProgressView().tint(DS.Color.accent)) : nil,
            action: { exportCSV() }
        )
    }

    private var jsonBackupRow: some View {
        SettingsRow(
            label: String(localized: "Full backup"),
            valueText: "JSON",
            chevron: true,
            action: { exportBackup() }
        )
    }

    private var pdfReportRow: some View {
        SettingsRow(
            label: String(localized: "Monthly report"),
            valueText: "PDF",
            chevron: true,
            action: { exportPDF() }
        )
    }

    private var importRestoreRow: some View {
        SettingsRow(
            label: String(localized: "Restore from backup"),
            valueText: importResult.map { String(format: String(localized: "%d records"), $0.total) } ?? "",
            chevron: true,
            action: { showImportPicker = true }
        )
    }

    private var clearHistoryRow: some View {
        SettingsRow(
            label: String(localized: "Clear workout history"),
            valueText: "\(allWorkoutHistory.count)",
            chevron: true,
            destructive: true,
            action: { showClearHistoryAlert = true }
        )
    }

    // MARK: - About group rows

    private var privacyPolicyRow: some View {
        SettingsRow(
            label: String(localized: "Privacy policy"),
            valueText: "",
            chevron: true,
            action: {
                if let url = URL(string: "https://lfrangt.github.io/pulse-watch/privacy-policy.html") {
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #endif
                }
            }
        )
    }

    private var sendFeedbackRow: some View {
        SettingsRow(
            label: String(localized: "Send feedback"),
            valueText: "",
            chevron: true,
            action: {
                if let url = URL(string: "mailto:abundra.dev@gmail.com?subject=Pulse%20Watch%20Feedback%20v\(appVersion)") {
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #endif
                }
            }
        )
    }

    private var versionRow: some View {
        SettingsRow(
            label: String(localized: "Version"),
            valueText: "\(appVersion) (\(buildNumber))",
            chevron: false
        )
    }

    // MARK: - More from Pulse rows

    private var goalsRow: some View {
        SettingsNavRow(
            label: String(localized: "Health goals"),
            sub: String(localized: "Daily goals for steps, sleep, training")
        ) {
            GoalSettingView().preferredColorScheme(.dark)
        }
    }

    private var coachModeRow: some View {
        SettingsNavRow(
            label: String(localized: "Coach mode"),
            sub: String(localized: "Generate health snapshot to share")
        ) {
            CoachModeView().preferredColorScheme(.dark)
        }
    }

    private var hrAlertEnabledRow: some View {
        SettingsToggleRow(
            label: String(localized: "Heart rate alerts"),
            sub: String(localized: "Alert when resting heart rate is abnormal"),
            isOn: $hrAlertEnabled,
            onChange: { newVal in
                HeartRateAlertService.shared.isEnabled = newVal
            }
        )
    }

    private var hrAlertHighRow: some View {
        SettingsRow(
            label: String(localized: "High threshold"),
            valueText: "\(hrAlertHigh) bpm",
            chevron: true,
            action: { showHRAlertDetail = true }
        )
    }

    private var hrAlertLowRow: some View {
        SettingsRow(
            label: String(localized: "Low threshold"),
            valueText: "\(hrAlertLow) bpm",
            chevron: true,
            action: { showHRAlertDetail = true }
        )
    }

    private var aiCoachIsActive: Bool {
        guard let cfg = OpenClawBridge.shared.config else { return false }
        return cfg.gatewayURL.contains("api.deepseek.com") && OpenClawBridge.shared.isEnabled
    }

    private var aiCoachRow: some View {
        SettingsRow(
            label: aiCoachActivating
                ? String(localized: "Connecting…")
                : (aiCoachIsActive ? String(localized: "AI Coach Active") : String(localized: "Enable AI Coach")),
            valueText: aiCoachIsActive ? "DeepSeek" : "",
            chevron: !aiCoachIsActive && !aiCoachActivating,
            action: {
                if !aiCoachIsActive && !aiCoachActivating {
                    showEnableAICoachAlert = true
                }
            }
        )
    }

    private var googleHealthRow: some View {
        let state = googleHealth.connectionState
        let isConnected = state == .connected
        let isConnecting = state == .connecting
        let isError: Bool = {
            if case .error = state { return true }
            return false
        }()
        let subtitle = googleHealthSubtitle(
            isConnected: isConnected,
            snapshot: googleHealthService.snapshot
        )
        return Button {
            if isConnecting { return }
            if isConnected {
                showDisconnectGoogleHealthAlert = true
            } else {
                showConnectGoogleHealthAlert = true
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isConnecting
                         ? String(localized: "Connecting…")
                         : (isConnected
                            ? String(localized: "Google Health Active")
                            : String(localized: "Connect Google Health")))
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(DS.Color.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.inkDim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isConnected {
                    Text(String(localized: "Fitbit · Pixel"))
                        .font(DS.Typography.monoL)
                        .foregroundStyle(DS.Color.inkDim)
                } else if isError {
                    Text(String(localized: "Retry"))
                        .font(DS.Typography.monoL)
                        .foregroundStyle(DS.Color.inkDim)
                }

                if !isConnecting {
                    Text("→")
                        .font(DS.Typography.mono)
                        .tracking(DS.Tracking.mono)
                        .foregroundStyle(DS.Color.inkDim)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DS.Color.lineSoft)
                    .frame(height: DS.Stroke.hairline)
            }
        }
        .buttonStyle(.plain)
    }

    private func googleHealthSubtitle(isConnected: Bool, snapshot: GoogleHealthSnapshot?) -> String? {
        if isConnected {
            guard let snapshot else {
                return String(localized: "Syncing…")
            }
            var parts: [String] = []
            if let hr = snapshot.heartRate {
                parts.append(String(format: "HR: %d bpm", Int(hr)))
            }
            if let steps = snapshot.steps {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                let formatted = formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
                parts.append(String(format: "Steps: %@", formatted))
            }
            if parts.isEmpty {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.dateStyle = .none
                return String(format: String(localized: "Last sync %@"), formatter.string(from: snapshot.fetchedAt))
            }
            return parts.joined(separator: " · ")
        } else {
            return String(localized: "Connects Pixel Watch / Fitbit Air data")
        }
    }

    private var openClawConnectionRow: some View {
        let isPaired = OpenClawBridge.shared.config != nil
        return SettingsRow(
            label: String(localized: "Gateway"),
            valueText: isPaired ? String(localized: "Connected") : String(localized: "Not paired"),
            chevron: true,
            action: { showOpenClawDetail = true }
        )
    }

    private var openClawAutoPushRow: some View {
        SettingsToggleRow(
            label: String(localized: "Auto-push health data"),
            sub: String(localized: "Every 30 min or on significant changes"),
            isOn: $openClawEnabled,
            onChange: { newVal in
                OpenClawBridge.shared.isEnabled = newVal
            }
        )
    }

    #if DEBUG
    private var demoModeRow: some View {
        SettingsToggleRow(
            label: String(localized: "Demo mode"),
            sub: String(localized: "Show UI with simulated data"),
            isOn: $demoModeEnabled
        )
    }
    #endif

    private var resetOnboardingRow: some View {
        SettingsRow(
            label: String(localized: "Reset onboarding"),
            valueText: "",
            chevron: true,
            action: { showResetOnboardingAlert = true }
        )
    }

    // MARK: - Sheet content

    private var profileDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text(String(localized: "Profile"))
                        .font(DS.Typography.title1)
                        .foregroundStyle(DS.Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    SettingsGroup(label: String(localized: "Identity")) {
                        SettingsRow(
                            label: String(localized: "Name"),
                            valueText: "",
                            chevron: false
                        ) {
                            TextField(String(localized: "Your name"), text: $userName)
                                .multilineTextAlignment(.trailing)
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Color.ink)
                                .frame(maxWidth: 160)
                                .focused($isNumberFieldFocused)
                        }
                        SettingsRow(
                            label: String(localized: "Birth year"),
                            valueText: "",
                            chevron: false
                        ) {
                            Picker("", selection: $birthYear) {
                                Text("—").tag(0)
                                ForEach((1940...2015).reversed(), id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(DS.Color.accent)
                            .labelsHidden()
                            .onChange(of: birthYear) {
                                HealthAgeService.shared.birthYear = birthYear
                            }
                        }
                        SettingsRow(
                            label: String(localized: "Birth month"),
                            valueText: "",
                            chevron: false
                        ) {
                            Picker("", selection: $birthMonth) {
                                Text("—").tag(0)
                                ForEach(1...12, id: \.self) { month in
                                    Text(DateFormatter().monthSymbols[month - 1]).tag(month)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(DS.Color.accent)
                            .labelsHidden()
                            .onChange(of: birthMonth) {
                                HealthAgeService.shared.birthMonth = birthMonth
                            }
                        }
                        SettingsRow(
                            label: String(localized: "Gender"),
                            valueText: "",
                            chevron: false
                        ) {
                            Picker("", selection: $gender) {
                                Text("—").tag("unset")
                                Text(String(localized: "Male")).tag("male")
                                Text(String(localized: "Female")).tag("female")
                            }
                            .pickerStyle(.menu)
                            .tint(DS.Color.accent)
                            .labelsHidden()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    SettingsGroup(label: String(localized: "Body")) {
                        SettingsRow(
                            label: String(localized: "Height"),
                            valueText: "",
                            chevron: false
                        ) {
                            HStack(spacing: 4) {
                                TextField("cm", value: $heightCm, format: .number)
                                    .keyboardType(.decimalPad)
                                    .focused($isNumberFieldFocused)
                                    .multilineTextAlignment(.trailing)
                                    .font(DS.Typography.body.monospacedDigit())
                                    .foregroundStyle(DS.Color.ink)
                                    .frame(width: 60)
                                Text("cm")
                                    .font(DS.Typography.monoL)
                                    .foregroundStyle(DS.Color.inkDim)
                            }
                        }
                        SettingsRow(
                            label: String(localized: "Weight"),
                            valueText: "",
                            chevron: false
                        ) {
                            HStack(spacing: 4) {
                                TextField("kg", value: $weightKg, format: .number)
                                    .keyboardType(.decimalPad)
                                    .focused($isNumberFieldFocused)
                                    .multilineTextAlignment(.trailing)
                                    .font(DS.Typography.body.monospacedDigit())
                                    .foregroundStyle(DS.Color.ink)
                                    .frame(width: 60)
                                Text("kg")
                                    .font(DS.Typography.monoL)
                                    .foregroundStyle(DS.Color.inkDim)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 60)
                }
            }
            .background(DS.Color.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        showProfileDetail = false
                    }
                    .foregroundStyle(DS.Color.accent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isNumberFieldFocused = false }
                }
            }
        }
    }

    private var hrAlertDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(String(localized: "Heart Rate Alerts"))
                        .font(DS.Typography.title1)
                        .foregroundStyle(DS.Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        HStack {
                            Text(String(localized: "High threshold"))
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Color.ink)
                            Spacer()
                            Text("\(hrAlertHigh) bpm")
                                .font(DS.Typography.body.monospacedDigit())
                                .foregroundStyle(DS.Color.bad)
                        }
                        Slider(value: Binding(
                            get: { Double(hrAlertHigh) },
                            set: { hrAlertHigh = Int($0) }
                        ), in: 90...180, step: 5)
                        .tint(DS.Color.bad)
                        .onChange(of: hrAlertHigh) {
                            HeartRateAlertService.shared.highThreshold = hrAlertHigh
                        }
                    }
                    .dsCard(padding: DS.Spacing.l)
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        HStack {
                            Text(String(localized: "Low threshold"))
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Color.ink)
                            Spacer()
                            Text("\(hrAlertLow) bpm")
                                .font(DS.Typography.body.monospacedDigit())
                                .foregroundStyle(DS.Color.accent)
                        }
                        Slider(value: Binding(
                            get: { Double(hrAlertLow) },
                            set: { hrAlertLow = Int($0) }
                        ), in: 30...60, step: 5)
                        .tint(DS.Color.accent)
                        .onChange(of: hrAlertLow) {
                            HeartRateAlertService.shared.lowThreshold = hrAlertLow
                        }
                    }
                    .dsCard(padding: DS.Spacing.l)
                    .padding(.horizontal, 16)

                    Text(String(localized: "Same alert won't repeat within 1 hour"))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.inkDim)
                        .padding(.horizontal, 24)
                }
            }
            .background(DS.Color.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        showHRAlertDetail = false
                    }
                    .foregroundStyle(DS.Color.accent)
                }
            }
        }
    }

    private var morningBriefDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(String(localized: "Morning Brief"))
                        .font(DS.Typography.title1)
                        .foregroundStyle(DS.Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Text(String(localized: "Delivery time"))
                            .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
                        HStack(spacing: DS.Spacing.m) {
                            Picker(String(localized: "hour"), selection: $briefHour) {
                                ForEach(5..<12, id: \.self) { h in
                                    Text("\(h)").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: DS.Spacing.xxl * 2, height: DS.Spacing.xxl * 2 + DS.Spacing.l)
                            .clipped()

                            Text(":")
                                .font(DS.Typography.title1)
                                .foregroundStyle(DS.Color.inkDim)

                            Picker(String(localized: "min"), selection: $briefMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: DS.Spacing.xxl * 2, height: DS.Spacing.xxl * 2 + DS.Spacing.l)
                            .clipped()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onChange(of: briefHour) {
                            MorningBriefService.shared.scheduledHour = briefHour
                        }
                        .onChange(of: briefMinute) {
                            MorningBriefService.shared.scheduledMinute = briefMinute
                        }
                    }
                    .dsCard(padding: DS.Spacing.l)
                    .padding(.horizontal, 16)

                    if !MorningBriefService.shared.isAuthorized {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Notifications disabled"))
                                .font(DS.Typography.body.weight(.medium))
                                .foregroundStyle(DS.Color.bad)
                            Text(String(localized: "Enable in Settings → Notifications → Pulse"))
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Color.inkDim)
                            Button(String(localized: "Open Settings")) {
                                openAppSettings()
                            }
                            .buttonStyle(PulseSecondaryButtonStyle())
                            .padding(.top, 8)
                        }
                        .dsCard(padding: DS.Spacing.l)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .background(DS.Color.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        showMorningBriefDetail = false
                    }
                    .foregroundStyle(DS.Color.accent)
                }
            }
        }
    }

    private var openClawDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(String(localized: "OpenClaw Gateway"))
                        .font(DS.Typography.title1)
                        .foregroundStyle(DS.Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    let bridge = OpenClawBridge.shared
                    let isPaired = bridge.config != nil

                    VStack(alignment: .leading, spacing: 12) {
                        if isPaired, let cfg = bridge.config {
                            HStack(spacing: DS.Spacing.s) {
                                Circle()
                                    .fill(DS.Color.good)
                                    .frame(width: DS.Spacing.s, height: DS.Spacing.s)
                                Text(String(localized: "Connected"))
                                    .font(DS.Typography.body.weight(.medium))
                                    .foregroundStyle(DS.Color.ink)
                            }
                            Text(cfg.gatewayURL)
                                .font(DS.Typography.mono)
                                .foregroundStyle(DS.Color.inkDim)
                                .lineLimit(1)
                        } else {
                            Text(String(localized: "Connect your gateway to push health data to your AI agent"))
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Color.inkMid)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard(padding: DS.Spacing.l)
                    .padding(.horizontal, 16)

                    Button {
                        showOpenClawDetail = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showQRScanner = true
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.s) {
                            Text("[QR]")
                                .font(DS.Typography.mono)
                                .tracking(DS.Tracking.mono)
                            Text(isPaired ? String(localized: "Scan to reconnect") : String(localized: "Scan to connect"))
                                .font(DS.Typography.body)
                        }
                        .foregroundStyle(DS.Color.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
                                .fill(DS.Color.accent.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DS.Spacing.l)

                    HStack(spacing: DS.Spacing.xs) {
                        Text(">_")
                            .font(DS.Typography.mono)
                            .tracking(DS.Tracking.mono)
                        Text("openclaw pair --qr")
                            .font(DS.Typography.monoL)
                    }
                    .foregroundStyle(DS.Color.inkDim)
                }
            }
            .background(DS.Color.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        showOpenClawDetail = false
                    }
                    .foregroundStyle(DS.Color.accent)
                }
            }
        }
    }

    // MARK: - Computed values

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: return String(localized: "Enabled")
        case .denied: return String(localized: "Disabled")
        case .provisional, .ephemeral: return String(localized: "Provisional")
        case .notDetermined: return String(localized: "Not Set")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Actions

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationStatus = settings.authorizationStatus
        }
    }

    private func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func clearWorkoutHistory() {
        for entry in allWorkoutHistory {
            modelContext.delete(entry)
        }
        try? modelContext.save()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            historyClearSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            historyClearSuccess = false
        }
    }

    private func exportPDF() {
        isExporting = true
        exportError = nil
        Task {
            do {
                let url = try PDFReportService.shared.generateMonthlyPDF(
                    summaries: allDailySummaries,
                    workouts: allWorkoutHistory,
                    strengthRecords: allStrengthRecords
                )
                exportURL = url
                showExportShare = true
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }

    private func exportCSV() {
        isExporting = true
        exportError = nil
        Task {
            do {
                let url = try DataExportService.shared.exportDailySummariesCSV(summaries: allDailySummaries)
                exportURL = url
                showExportShare = true
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }

    private func exportBackup() {
        isExporting = true
        exportError = nil
        Task {
            do {
                let url = try DataExportService.shared.exportBackup(
                    summaries: allDailySummaries,
                    workouts: allWorkoutHistory,
                    strengthRecords: allStrengthRecords,
                    goals: allGoals
                )
                exportURL = url
                showExportShare = true
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }
}

// MARK: - SettingsGroup (eyebrow label + flush card)
// Each row draws its own TOP hairline at +0pt offset; the topmost row's hairline
// is occluded by the card's overlay border, producing clean separators that match
// Settings.jsx's `border-top: 1px solid var(--pulse-line-faint)` pattern.

private struct SettingsGroup<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(DS.Typography.mono).tracking(DS.Tracking.mono).textCase(.uppercase).foregroundStyle(DS.Color.inkMid)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(DS.Color.bgElev)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Color.line, lineWidth: DS.Stroke.hairline)
            )
        }
    }
}

// MARK: - SettingsRow (label + value + chevron)

private struct SettingsRow<Trailing: View>: View {
    let label: String
    let valueText: String
    let chevron: Bool
    let destructive: Bool
    let trailing: AnyView?
    let action: (() -> Void)?
    let builder: () -> Trailing

    init(
        label: String,
        valueText: String,
        chevron: Bool,
        destructive: Bool = false,
        trailing: AnyView? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder builder: @escaping () -> Trailing
    ) {
        self.label = label
        self.valueText = valueText
        self.chevron = chevron
        self.destructive = destructive
        self.trailing = trailing
        self.action = action
        self.builder = builder
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(DS.Typography.body.weight(.medium))
                .foregroundStyle(destructive ? DS.Color.bad : DS.Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let trailing {
                trailing
            } else if !valueText.isEmpty {
                Text(valueText)
                    .font(DS.Typography.monoL)
                    .foregroundStyle(DS.Color.inkDim)
            }

            builder()

            if chevron {
                Text("→")
                    .font(DS.Typography.mono)
                    .tracking(DS.Tracking.mono)
                    .foregroundStyle(DS.Color.inkDim)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DS.Color.lineSoft)
                .frame(height: DS.Stroke.hairline)
        }
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(
        label: String,
        valueText: String,
        chevron: Bool,
        destructive: Bool = false,
        trailing: AnyView? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            label: label,
            valueText: valueText,
            chevron: chevron,
            destructive: destructive,
            trailing: trailing,
            action: action,
            builder: { EmptyView() }
        )
    }
}

// MARK: - SettingsToggleRow

private struct SettingsToggleRow: View {
    let label: String
    let sub: String?
    @Binding var isOn: Bool
    var onChange: ((Bool) -> Void)? = nil
    var tap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(DS.Color.ink)
                if let sub, !sub.isEmpty {
                    Text(sub)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.inkDim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                tap?()
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DS.Color.accent)
                .onChange(of: isOn) {
                    onChange?(isOn)
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DS.Color.lineSoft)
                .frame(height: DS.Stroke.hairline)
        }
    }
}

// MARK: - SettingsNavRow

private struct SettingsNavRow<Destination: View>: View {
    let label: String
    let sub: String?
    let destination: () -> Destination

    init(
        label: String,
        sub: String? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.label = label
        self.sub = sub
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(DS.Color.ink)
                    if let sub, !sub.isEmpty {
                        Text(sub)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.inkDim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("→")
                    .font(DS.Typography.mono)
                    .tracking(DS.Tracking.mono)
                    .foregroundStyle(DS.Color.inkDim)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DS.Color.lineSoft)
                    .frame(height: DS.Stroke.hairline)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
