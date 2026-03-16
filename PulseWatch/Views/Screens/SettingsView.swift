import SwiftUI
import SwiftData
import UserNotifications
import HealthKit

/// 设置页面 — 控制通知、健身房、数据采集等
struct SettingsView: View {

    // MARK: - 持久化设置

    @AppStorage("pulse.brief.enabled") private var morningBriefEnabled = true
    @AppStorage("pulse.brief.hour") private var briefHour = 7
    @AppStorage("pulse.brief.minute") private var briefMinute = 30
    @AppStorage("pulse.weekly.summary.enabled") private var weeklySummaryEnabled = true
    @AppStorage("pulse.training.reminder.enabled") private var trainingReminderEnabled = true
    @AppStorage("pulse.hr.alert.enabled") private var hrAlertEnabled = true
    @AppStorage("pulse.hr.alert.high") private var hrAlertHigh = 120
    @AppStorage("pulse.hr.alert.low") private var hrAlertLow = 40
    @AppStorage("pulse.collection.frequency") private var collectionFrequency = "normal"
    @AppStorage("pulse.openclaw.enabled") private var openClawEnabled = false
    @AppStorage("pulse.demo.enabled") private var demoModeEnabled = false
    @AppStorage("pulse.units") private var unitSystem = "metric" // "metric" or "imperial"
    @AppStorage("pulse.onboarding.completed") private var onboardingCompleted = false
    @AppStorage("pulse.user.birthYear") private var birthYear = 0

    // MARK: - 状态

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var healthManager = HealthKitManager.shared
    @State private var showLocationSetup = false
    @State private var showAbout = false
    @State private var isSavingGym = false
    @State private var gymSaveSuccess = false
    @State private var showClearHistoryAlert = false
    @State private var showResetOnboardingAlert = false
    @State private var historyClearSuccess = false

    @Query(filter: #Predicate<SavedLocation> { $0.locationType == "gym" && $0.isActive })
    private var gymLocations: [SavedLocation]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PulseTheme.spacingM) {

                    // Morning Brief
                    morningBriefSection
                        .staggered(index: 0)

                    // 健身房位置
                    gymSection
                        .staggered(index: 1)

                    // 通知权限
                    notificationSection
                        .staggered(index: 2)

                    // 心率异常提醒
                    heartRateAlertSection
                        .staggered(index: 3)

                    // HealthKit 数据权限
                    healthDataSection
                        .staggered(index: 4)

                    // 单位设置
                    unitSection
                        .staggered(index: 5)

                    // 数据采集频率
                    collectionSection
                        .staggered(index: 6)

                    // 数据管理
                    dataManagementSection
                        .staggered(index: 7)

                    // OpenClaw（预留）
                    openClawSection
                        .staggered(index: 8)

                    // 开发者选项（仅 Debug 构建）
                    #if DEBUG
                    developerSection
                        .staggered(index: 9)
                    #endif

                    // 个人信息
                    profileSection
                        .staggered(index: 10)

                    // 关于
                    aboutSection
                        .staggered(index: 11)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingS)
            }
            .background(PulseTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await checkNotificationStatus()
                healthManager.checkAuthorizationStatus()
            }
        }
    }

    // MARK: - Morning Brief 设置

    private var morningBriefSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "sun.horizon.fill", title: "Morning Brief")

            // 权限未授权提示
            if !MorningBriefService.shared.isAuthorized {
                settingRow {
                    HStack(spacing: PulseTheme.spacingM) {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(PulseTheme.statusPoor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications Disabled")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text("Enable in Settings → Notifications → Pulse")
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                        Spacer()
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open")
                                .font(PulseTheme.captionFont.weight(.semibold))
                                .foregroundStyle(PulseTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 开关
            settingRow {
                Toggle(isOn: $morningBriefEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Health Summary")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("Daily recovery score and training advice")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .tint(PulseTheme.accent)
                .onChange(of: morningBriefEnabled) {
                    MorningBriefService.shared.isEnabled = morningBriefEnabled
                }
            }

            // 时间选择
            if morningBriefEnabled {
                settingRow {
                    VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                        Text("Notification Time")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)

                        HStack(spacing: PulseTheme.spacingM) {
                            // 小时
                            HStack(spacing: 4) {
                                Text("h")
                                    .font(PulseTheme.captionFont)
                                    .foregroundStyle(PulseTheme.textTertiary)
                                Picker(String(localized: "hour"), selection: $briefHour) {
                                    ForEach(5..<12, id: \.self) { h in
                                        Text("\(h)").tag(h)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60, height: 100)
                                .clipped()
                            }

                            // 分钟
                            HStack(spacing: 4) {
                                Text("pts")
                                    .font(PulseTheme.captionFont)
                                    .foregroundStyle(PulseTheme.textTertiary)
                                Picker(String(localized: "min"), selection: $briefMinute) {
                                    ForEach([0, 15, 30, 45], id: \.self) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 60, height: 100)
                                .clipped()
                            }
                        }
                        .onChange(of: briefHour) {
                            MorningBriefService.shared.scheduledHour = briefHour
                        }
                        .onChange(of: briefMinute) {
                            MorningBriefService.shared.scheduledMinute = briefMinute
                        }
                    }
                }
            }

            // Streak — best (read-only)
            settingRow {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All-Time Best Streak")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("Your longest consecutive health tracking streak")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 14))
                        Text(String(format: String(localized: "%d days"), StreakService.shared.bestStreak))
                            .font(PulseTheme.bodyFont.weight(.semibold))
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
                }
            }

            // Weekly Summary
            settingRow {
                Toggle(isOn: $weeklySummaryEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly Health Summary")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("Every Sunday 9:00 AM — score, workouts & trends")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .tint(PulseTheme.accent)
                .onChange(of: weeklySummaryEnabled) {
                    WeeklySummaryService.shared.isEnabled = weeklySummaryEnabled
                }
            }

            // 训练提醒
            settingRow {
                Toggle(isOn: $trainingReminderEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Training Reminders")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("Remind you when arriving at gym")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .tint(PulseTheme.accent)
            }
        }
        .pulseCard()
    }

    @State private var showGymSearch = false

    // MARK: - 健身房位置设置

    private var gymSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "dumbbell.fill", title: String(localized: "Gym Location"))

            if let gym = gymLocations.first {
                // 已保存 — 显示地点信息
                settingRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gym.name)
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text("Auto-remind when you arrive")
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(PulseTheme.statusGood)
                    }
                }

                // 更换 / 移除
                HStack(spacing: PulseTheme.spacingM) {
                    Button {
                        showGymSearch = true
                    } label: {
                        Text("Change")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.accent)
                    }

                    Button {
                        removeGymLocation(gym)
                    } label: {
                        Text("Remove")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.statusPoor)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                // 未设置 — 搜索按钮
                Button {
                    showGymSearch = true
                } label: {
                    HStack(spacing: PulseTheme.spacingS) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                        Text("Search Gym")
                            .font(PulseTheme.bodyFont.weight(.medium))
                    }
                    .foregroundStyle(PulseTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                            .fill(PulseTheme.accent.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)

                // 或使用当前位置
                Button {
                    saveCurrentLocationAsGym()
                } label: {
                    HStack(spacing: PulseTheme.spacingS) {
                        if isSavingGym {
                            ProgressView()
                                .tint(PulseTheme.accent)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 13))
                        }
                        Text("Use Current Location")
                            .font(PulseTheme.captionFont)
                    }
                    .foregroundStyle(PulseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PulseTheme.spacingS)
                }
                .buttonStyle(.plain)
                .disabled(isSavingGym)

                if gymSaveSuccess {
                    HStack(spacing: PulseTheme.spacingXS) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Saved")
                    }
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.statusGood)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .pulseCard()
        .sheet(isPresented: $showGymSearch) {
            GymSearchView { name, lat, lon in
                // 先移除旧的
                for old in gymLocations {
                    removeGymLocation(old)
                }
                // 保存新的
                let location = SavedLocation(
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    radiusMeters: 100,
                    locationType: "gym"
                )
                modelContext.insert(location)
                #if os(iOS)
                LocationManager.shared.registerGeofence(for: location)
                #endif
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    gymSaveSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    gymSaveSuccess = false
                }
            }
        }
    }

    // 手动坐标输入已移除 — 使用 GymSearchView 地址搜索代替

    // MARK: - 心率异常提醒

    private var heartRateAlertSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "heart.circle.fill", title: String(localized: "Heart Rate Alerts"))

            // 总开关
            settingRow {
                Toggle(isOn: $hrAlertEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Heart Rate Alerts")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("Alert when resting heart rate is abnormal")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .tint(PulseTheme.accent)
                .onChange(of: hrAlertEnabled) {
                    HeartRateAlertService.shared.isEnabled = hrAlertEnabled
                }
            }

            if hrAlertEnabled {
                // 高心率阈值
                settingRow {
                    VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                        HStack {
                            Text("High Threshold")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Spacer()
                            Text("\(hrAlertHigh) bpm")
                                .font(PulseTheme.bodyFont.monospacedDigit())
                                .foregroundStyle(PulseTheme.statusPoor)
                        }
                        Slider(value: Binding(
                            get: { Double(hrAlertHigh) },
                            set: { hrAlertHigh = Int($0) }
                        ), in: 90...180, step: 5)
                        .tint(PulseTheme.statusPoor)
                        .onChange(of: hrAlertHigh) {
                            HeartRateAlertService.shared.highThreshold = hrAlertHigh
                        }
                    }
                }

                // 低心率阈值
                settingRow {
                    VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                        HStack {
                            Text("Low Threshold")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Spacer()
                            Text("\(hrAlertLow) bpm")
                                .font(PulseTheme.bodyFont.monospacedDigit())
                                .foregroundStyle(PulseTheme.accent)
                        }
                        Slider(value: Binding(
                            get: { Double(hrAlertLow) },
                            set: { hrAlertLow = Int($0) }
                        ), in: 30...60, step: 5)
                        .tint(PulseTheme.accent)
                        .onChange(of: hrAlertLow) {
                            HeartRateAlertService.shared.lowThreshold = hrAlertLow
                        }
                    }
                }

                // 说明
                HStack(spacing: PulseTheme.spacingS) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.textTertiary)
                    Text("Same alert won't repeat within 1 hour")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .lineSpacing(2)
                }
                .padding(.horizontal, PulseTheme.spacingXS)
            }
        }
        .pulseCard()
    }

    // MARK: - 通知权限

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "bell.badge.fill", title: String(localized: "Notifications"))

            settingRow {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Status")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(notificationStatusText)
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(notificationStatusColor)
                    }

                    Spacer()

                    Image(systemName: notificationStatusIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(notificationStatusColor)
                }
            }

            if notificationStatus == .denied {
                Button {
                    openAppSettings()
                } label: {
                    Text("Open System Settings")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PulseTheme.spacingS)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - HealthKit 数据权限

    private var healthDataSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "heart.text.square.fill", title: String(localized: "Health Data"))

            // 权限状态
            settingRow {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Authorization Status"))
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(healthManager.authorizationStatus.description)
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(healthManager.authorizationStatus.color)
                    }

                    Spacer()

                    Image(systemName: healthManager.authorizationStatus.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(healthManager.authorizationStatus.color)
                }
            }

            // 如果未完全授权，显示设置按钮
            if !healthManager.isFullyAuthorized {
                Button {
                    openAppSettings()
                } label: {
                    Text(String(localized: "Open Settings"))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PulseTheme.spacingS)
                }
            }

            // 数据类型访问状态
            settingRow {
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    Text(String(localized: "Data Access"))
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)

                    VStack(spacing: PulseTheme.spacingXS) {
                        dataAccessRow(icon: "heart.fill", name: String(localized: "Heart Rate"), isAuthorized: checkDataTypeAuthorization(HKQuantityType(.heartRate)))
                        dataAccessRow(icon: "waveform.path.ecg", name: String(localized: "HRV"), isAuthorized: checkDataTypeAuthorization(HKQuantityType(.heartRateVariabilitySDNN)))
                        dataAccessRow(icon: "figure.walk", name: String(localized: "Steps"), isAuthorized: checkDataTypeAuthorization(HKQuantityType(.stepCount)))
                        dataAccessRow(icon: "moon.fill", name: String(localized: "Sleep"), isAuthorized: checkDataTypeAuthorization(HKCategoryType(.sleepAnalysis)))
                        dataAccessRow(icon: "lungs.fill", name: String(localized: "Blood Oxygen"), isAuthorized: checkDataTypeAuthorization(HKQuantityType(.oxygenSaturation)))
                    }
                }
            }
        }
        .pulseCard()
    }

    private func dataAccessRow(icon: String, name: String, isAuthorized: Bool) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(name)
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)

            Spacer()

            Image(systemName: isAuthorized ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 14))
                .foregroundStyle(isAuthorized ? PulseTheme.statusGood : PulseTheme.textTertiary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(isAuthorized ? String(localized: "Authorized") : String(localized: "Not authorized"))
    }

    private func checkDataTypeAuthorization(_ type: HKObjectType) -> Bool {
        let status = HKHealthStore().authorizationStatus(for: type)
        return status == .sharingAuthorized
    }

    // MARK: - 数据采集频率

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "waveform.path.ecg", title: String(localized: "Data Collection"))

            settingRow {
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    Text("Collection Frequency")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)

                    Picker(String(localized: "Frequency"), selection: $collectionFrequency) {
                        Text("Power Saving").tag("low")
                        Text("Standard").tag("normal")
                        Text("High Frequency").tag("high")
                    }
                    .pickerStyle(.segmented)

                    Text(frequencyDescription)
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - OpenClaw 集成

    @AppStorage("pulse.openclaw.gatewayURL") private var savedGatewayURL = ""
    @AppStorage("pulse.openclaw.agentID") private var savedAgentID = "openclaw:main"
    @AppStorage("pulse.openclaw.connected") private var isConnected = false

    @State private var gatewayURL = ""
    @State private var gatewayToken = ""
    @State private var gatewayAgentID = ""
    @State private var isPairing = false
    @State private var pairResult: Bool?
    @State private var showGatewayConfig = false
    @State private var showQRScanner = false

    private var openClawSection: some View {
        let bridge = OpenClawBridge.shared
        let isPaired = bridge.config != nil

        return VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "cpu", title: String(localized: "Connect OpenClaw"))

            // 说明
            settingRow {
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    Text("Connect your OpenClaw Gateway")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)

                    Text("Push health data to your AI Agent for personalized training advice")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                        .lineSpacing(3)
                }
            }

            // Gateway 配置
            if isPaired {
                // 已配对 — 显示状态
                settingRow {
                    VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(PulseTheme.statusGood)
                            Text("Gateway Connected")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                        }
                        if let cfg = bridge.config {
                            Text(cfg.gatewayURL)
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                // 重新配置按钮
                Button {
                    if let cfg = bridge.config {
                        gatewayURL = cfg.gatewayURL
                        gatewayAgentID = cfg.agentID
                        gatewayToken = ""
                    }
                    withAnimation(.spring(response: 0.3)) {
                        showGatewayConfig.toggle()
                    }
                } label: {
                    Text(showGatewayConfig ? String(localized: "Cancel") : String(localized: "Reconfigure"))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PulseTheme.spacingS)
                }
                .buttonStyle(.plain)
            }

            if !isPaired && !showGatewayConfig {
                // 扫码配对（主入口）
                Button {
                    showQRScanner = true
                } label: {
                    HStack(spacing: PulseTheme.spacingS) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 16, weight: .medium))
                        Text("Scan to Connect")
                            .font(PulseTheme.bodyFont.weight(.medium))
                    }
                    .foregroundStyle(PulseTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                            .fill(PulseTheme.accent.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)

                // CLI 提示
                HStack(spacing: PulseTheme.spacingXS) {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                    Text("Run openclaw pair --qr in terminal")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                }
                .foregroundStyle(PulseTheme.textTertiary)
                .padding(.horizontal, PulseTheme.spacingXS)

                // 手动输入 fallback
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showGatewayConfig = true
                    }
                } label: {
                    Text("Manual Input")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PulseTheme.spacingS)
                }
                .buttonStyle(.plain)
            }

            if showGatewayConfig {
                gatewayConfigView
            }

            // 数据共享开关（需要先配对）
            if isPaired {
                settingRow {
                    Toggle(isOn: $openClawEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-push Health Data")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text("Auto-push every 30 min or on significant changes")
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                    }
                    .tint(PulseTheme.accent)
                    .onChange(of: openClawEnabled) {
                        bridge.isEnabled = openClawEnabled
                    }
                }
            }

            if openClawEnabled && isPaired {
                // 连接状态 + 最后同步
                settingRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connection Status")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text("\(bridge.connectionStatus.rawValue) · \(bridge.lastSyncDisplay)")
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(Color(hex: bridge.connectionStatus.color))
                        }
                        Spacer()
                        // 手动同步按钮
                        Button {
                            Task { @MainActor in
                                await bridge.pushHealthStatus()
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PulseTheme.accent)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(PulseTheme.accent.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 数据说明
                HStack(spacing: PulseTheme.spacingS) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PulseTheme.statusGood)
                    Text("Data sent directly to your OpenClaw Gateway, no third parties")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .lineSpacing(2)
                }
                .padding(.horizontal, PulseTheme.spacingXS)
            }
        }
        .pulseCard()
        .onAppear {
            // 从持久化存储加载已保存的配置
            gatewayURL = savedGatewayURL
            gatewayAgentID = savedAgentID
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { url, token, agent in
                // QR 扫码成功 — 自动配对
                Task {
                    isPairing = true
                    pairResult = nil
                    let ok = await OpenClawBridge.shared.pair(
                        gatewayURL: url,
                        token: token,
                        agentID: agent
                    )
                    isPairing = false
                    pairResult = ok
                    if ok {
                        savedGatewayURL = url
                        savedAgentID = agent
                        isConnected = true
                        Analytics.trackOpenClawPaired()
                        #if os(iOS)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        #endif
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            pairResult = nil
                        }
                    }
                }
            }
        }
    }

    /// Gateway 配置输入区域（手动 fallback）
    private var gatewayConfigView: some View {
        VStack(spacing: PulseTheme.spacingS) {
            // Gateway URL
            VStack(alignment: .leading, spacing: 4) {
                Text("Gateway URL")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
                TextField("https://your-gateway.example.com", text: $gatewayURL)
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .padding(PulseTheme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                            .fill(PulseTheme.surface)
                    )
            }

            // Token（安全输入）
            VStack(alignment: .leading, spacing: 4) {
                Text("Token")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
                SecureField("Bearer token", text: $gatewayToken)
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .padding(PulseTheme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                            .fill(PulseTheme.surface)
                    )
            }

            // Agent ID
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent ID")
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
                TextField(PulseOpenClawConfig.defaultAgentID, text: $gatewayAgentID)
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(PulseTheme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                            .fill(PulseTheme.surface)
                    )
            }

            // 验证并连接按钮
            Button {
                Task {
                    isPairing = true
                    pairResult = nil
                    let agent = gatewayAgentID.isEmpty ? PulseOpenClawConfig.defaultAgentID : gatewayAgentID
                    let ok = await OpenClawBridge.shared.pair(
                        gatewayURL: gatewayURL,
                        token: gatewayToken,
                        agentID: agent
                    )
                    isPairing = false
                    pairResult = ok
                    if ok {
                        // 持久化到 @AppStorage
                        savedGatewayURL = gatewayURL
                        savedAgentID = agent
                        isConnected = true
                        Analytics.trackOpenClawPaired()
                        withAnimation(.spring(response: 0.3)) {
                            showGatewayConfig = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            pairResult = nil
                        }
                    } else {
                        isConnected = false
                    }
                }
            } label: {
                HStack(spacing: PulseTheme.spacingS) {
                    if isPairing {
                        ProgressView()
                            .tint(PulseTheme.accent)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .medium))
                    }
                    Text(isPairing ? String(localized: "Verifying...") : String(localized: "Verify & Connect"))
                        .font(PulseTheme.bodyFont.weight(.medium))
                }
                .foregroundStyle(PulseTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                        .fill(PulseTheme.accent.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .disabled(gatewayURL.isEmpty || gatewayToken.isEmpty || isPairing)
            .opacity(gatewayURL.isEmpty || gatewayToken.isEmpty ? 0.5 : 1)

            // 验证结果
            if let result = pairResult {
                HStack(spacing: PulseTheme.spacingXS) {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(result ? String(localized: "Connected") : String(localized: "Connection failed. Check URL and Token"))
                }
                .font(PulseTheme.captionFont)
                .foregroundStyle(result ? PulseTheme.statusGood : PulseTheme.statusPoor)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - 单位设置

    private var unitSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "ruler.fill", title: String(localized: "Units"))

            settingRow {
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    Text("Measurement System")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)

                    Picker(String(localized: "Units"), selection: $unitSystem) {
                        Text("Metric (km, kg)").tag("metric")
                        Text("Imperial (mi, lb)").tag("imperial")
                    }
                    .pickerStyle(.segmented)

                    Text(unitSystem == "metric"
                         ? String(localized: "Distances in kilometers, weight in kilograms")
                         : String(localized: "Distances in miles, weight in pounds"))
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 数据管理

    @Query private var allWorkoutHistory: [WorkoutHistoryEntry]

    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "externaldrive.fill", title: String(localized: "Data Management"))

            // 清除训练历史
            settingRow {
                Button {
                    showClearHistoryAlert = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear Workout History")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text("\(allWorkoutHistory.count) records stored")
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                        Spacer()
                        if historyClearSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(PulseTheme.statusGood)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(PulseTheme.statusPoor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            // 重置 Onboarding
            settingRow {
                Button {
                    showResetOnboardingAlert = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset Onboarding")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text("Show welcome guide again on next launch")
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(PulseTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .pulseCard()
        .alert("Clear Workout History?", isPresented: $showClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearWorkoutHistory()
            }
        } message: {
            Text("This will delete all saved workout history from the app. Health data in Apple Health will not be affected.")
        }
        .alert("Reset Onboarding?", isPresented: $showResetOnboardingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                onboardingCompleted = false
            }
        } message: {
            Text("The welcome guide will appear next time you open the app.")
        }
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

    // MARK: - 开发者选项

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "hammer.fill", title: String(localized: "Developer"))

            settingRow {
                Toggle(isOn: $demoModeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Demo Mode")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("Show UI with simulated data")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .tint(PulseTheme.accent)
            }
        }
        .pulseCard()
    }

    // MARK: - 个人信息 (Profile)

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "person.fill", title: String(localized: "Profile"))

            settingRow {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Birth Year")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("Used to calculate your Health Age")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                    Spacer()
                    Picker("", selection: $birthYear) {
                        Text("—").tag(0)
                        ForEach((1940...2010).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(PulseTheme.accent)
                    .onChange(of: birthYear) {
                        HealthAgeService.shared.birthYear = birthYear
                    }
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "info.circle.fill", title: String(localized: "About"))

            settingRow {
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    aboutRow(label: String(localized: "Version"), value: appVersion)
                    Divider().overlay(PulseTheme.border)
                    aboutRow(label: String(localized: "Build"), value: buildNumber)
                }
            }

            // 隐私政策链接
            settingRow {
                Button {
                    if let url = URL(string: "https://lfrangt.github.io/pulse-watch/privacy-policy.html") {
                        #if os(iOS)
                        UIApplication.shared.open(url)
                        #endif
                    }
                } label: {
                    HStack {
                        HStack(spacing: PulseTheme.spacingS) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(PulseTheme.statusGood)
                            Text("Privacy Policy")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            // 反馈邮件
            settingRow {
                Button {
                    if let url = URL(string: "mailto:abundra.dev@gmail.com?subject=Pulse%20Watch%20Feedback%20v\(appVersion)") {
                        #if os(iOS)
                        UIApplication.shared.open(url)
                        #endif
                    }
                } label: {
                    HStack {
                        HStack(spacing: PulseTheme.spacingS) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(PulseTheme.accent)
                            Text("Send Feedback")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            // 隐私说明
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(PulseTheme.textTertiary)
                Text("All data stays on your device. We never collect personal information.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(PulseTheme.textTertiary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, PulseTheme.spacingXS)
        }
        .pulseCard()
    }

    // MARK: - 通用组件

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PulseTheme.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func settingRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(PulseTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .fill(PulseTheme.surface)
            )
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
            Spacer()
            Text(value)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textPrimary)
        }
    }

    // MARK: - 计算属性

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: return "Enabled"
        case .denied: return "Disabled"
        case .provisional: return "Provisional"
        case .ephemeral: return "Provisional"
        case .notDetermined: return "Not Set"
        @unknown default: return String(localized: "Unknown")
        }
    }

    private var notificationStatusIcon: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle"
        @unknown default: return "questionmark.circle"
        }
    }

    private var notificationStatusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return PulseTheme.statusGood
        case .denied: return PulseTheme.statusPoor
        case .notDetermined: return PulseTheme.textTertiary
        @unknown default: return PulseTheme.textTertiary
        }
    }

    private var frequencyDescription: String {
        switch collectionFrequency {
        case "low": return String(localized: "Every 30 minutes, saves battery")
        case "high": return String(localized: "Every 5 minutes, more accurate but uses more battery")
        default: return String(localized: "Every 15 minutes, balanced")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - 操作

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

    private func saveCurrentLocationAsGym() {
        isSavingGym = true
        let locationManager = LocationManager.shared
        locationManager.requestAuthorization()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let location = locationManager.saveCurrentAsLocation(
                name: String(localized: "Gym"),
                type: "gym",
                radius: 100
            ) {
                modelContext.insert(location)
                #if os(iOS)
                locationManager.registerGeofence(for: location)
                #endif

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    gymSaveSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    gymSaveSuccess = false
                }
            }
            isSavingGym = false
        }
    }

    // saveManualGymLocation 已移除 — 使用 GymSearchView

    private func removeGymLocation(_ location: SavedLocation) {
        #if os(iOS)
        LocationManager.shared.removeGeofence(for: location.id)
        #endif
        modelContext.delete(location)
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
