import SwiftUI
import SwiftData
import UserNotifications

/// 设置页面 — 控制通知、健身房、数据采集等
struct SettingsView: View {

    // MARK: - 持久化设置

    @AppStorage("pulse.brief.enabled") private var morningBriefEnabled = true
    @AppStorage("pulse.brief.hour") private var briefHour = 7
    @AppStorage("pulse.brief.minute") private var briefMinute = 30
    @AppStorage("pulse.collection.frequency") private var collectionFrequency = "normal"
    @AppStorage("pulse.openclaw.enabled") private var openClawEnabled = false

    // MARK: - 状态

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showLocationSetup = false
    @State private var showAbout = false
    @State private var gymAddress = ""
    @State private var gymLatitude = ""
    @State private var gymLongitude = ""
    @State private var showManualCoordEntry = false
    @State private var isSavingGym = false
    @State private var gymSaveSuccess = false

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

                    // 数据采集频率
                    collectionSection
                        .staggered(index: 3)

                    // OpenClaw（预留）
                    openClawSection
                        .staggered(index: 4)

                    // 关于
                    aboutSection
                        .staggered(index: 5)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, PulseTheme.spacingM)
                .padding(.top, PulseTheme.spacingS)
            }
            .background(PulseTheme.background)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await checkNotificationStatus()
            }
        }
    }

    // MARK: - Morning Brief 设置

    private var morningBriefSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "sun.horizon.fill", title: "Morning Brief")

            // 开关
            settingRow {
                Toggle(isOn: $morningBriefEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("每日健康摘要")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text("每天定时推送恢复评分和训练建议")
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
                        Text("推送时间")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)

                        HStack(spacing: PulseTheme.spacingM) {
                            // 小时
                            HStack(spacing: 4) {
                                Text("时")
                                    .font(PulseTheme.captionFont)
                                    .foregroundStyle(PulseTheme.textTertiary)
                                Picker("小时", selection: $briefHour) {
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
                                Text("分")
                                    .font(PulseTheme.captionFont)
                                    .foregroundStyle(PulseTheme.textTertiary)
                                Picker("分钟", selection: $briefMinute) {
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
        }
        .pulseCard()
    }

    // MARK: - 健身房位置设置

    private var gymSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "dumbbell.fill", title: "健身房位置")

            // 当前已保存的健身房
            if let gym = gymLocations.first {
                settingRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gym.name)
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text(String(format: "%.4f, %.4f", gym.latitude, gym.longitude))
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                            Text("半径 \(Int(gym.radiusMeters))m")
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseTheme.statusGood)
                    }
                }

                // 删除按钮
                Button {
                    removeGymLocation(gym)
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                        Text("移除健身房")
                            .font(PulseTheme.captionFont)
                    }
                    .foregroundStyle(PulseTheme.statusPoor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PulseTheme.spacingS)
                }
            } else {
                // 使用当前位置
                Button {
                    saveCurrentLocationAsGym()
                } label: {
                    HStack(spacing: PulseTheme.spacingS) {
                        if isSavingGym {
                            ProgressView()
                                .tint(PulseTheme.accent)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                        }
                        Text("使用当前位置")
                            .font(PulseTheme.bodyFont)
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
                .disabled(isSavingGym)

                // 手动输入坐标
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showManualCoordEntry.toggle()
                    }
                } label: {
                    HStack(spacing: PulseTheme.spacingS) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 14))
                        Text("手动输入坐标")
                            .font(PulseTheme.bodyFont)
                    }
                    .foregroundStyle(PulseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if showManualCoordEntry {
                    manualCoordInputView
                }

                if gymSaveSuccess {
                    HStack(spacing: PulseTheme.spacingXS) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("已保存")
                    }
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.statusGood)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .pulseCard()
    }

    /// 手动坐标输入
    private var manualCoordInputView: some View {
        VStack(spacing: PulseTheme.spacingS) {
            HStack(spacing: PulseTheme.spacingS) {
                coordField(title: "纬度", text: $gymLatitude, placeholder: "31.2304")
                coordField(title: "经度", text: $gymLongitude, placeholder: "121.4737")
            }

            Button {
                saveManualGymLocation()
            } label: {
                Text("保存")
                    .font(PulseTheme.bodyFont.weight(.medium))
                    .foregroundStyle(PulseTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                            .fill(PulseTheme.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(gymLatitude.isEmpty || gymLongitude.isEmpty)
            .opacity(gymLatitude.isEmpty || gymLongitude.isEmpty ? 0.5 : 1)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func coordField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
            TextField(placeholder, text: text)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .keyboardType(.decimalPad)
                .padding(PulseTheme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                        .fill(PulseTheme.surface)
                )
        }
    }

    // MARK: - 通知权限

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "bell.badge.fill", title: "通知权限")

            settingRow {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("通知状态")
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
                    Text("前往系统设置开启")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PulseTheme.spacingS)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 数据采集频率

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "waveform.path.ecg", title: "数据采集")

            settingRow {
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    Text("采集频率")
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)

                    Picker("频率", selection: $collectionFrequency) {
                        Text("省电模式").tag("low")
                        Text("标准").tag("normal")
                        Text("高频").tag("high")
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

    // MARK: - OpenClaw 集成（预留）

    private var openClawSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "cpu", title: "OpenClaw 集成")

            settingRow {
                Toggle(isOn: $openClawEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: PulseTheme.spacingXS) {
                            Text("OpenClaw AI 分析")
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Text("即将推出")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(PulseTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(PulseTheme.accent.opacity(0.15))
                                )
                        }
                        Text("使用本地 AI 模型进行深度健康分析")
                            .font(PulseTheme.captionFont)
                            .foregroundStyle(PulseTheme.textTertiary)
                    }
                }
                .tint(PulseTheme.accent)
                .disabled(true)
            }
        }
        .pulseCard()
        .opacity(0.6)
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            sectionHeader(icon: "info.circle.fill", title: "关于")

            settingRow {
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    aboutRow(label: "版本", value: appVersion)
                    Divider().overlay(PulseTheme.border)
                    aboutRow(label: "构建", value: buildNumber)
                }
            }

            // 隐私说明
            settingRow {
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    HStack(spacing: PulseTheme.spacingS) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PulseTheme.statusGood)
                        Text("隐私说明")
                            .font(PulseTheme.bodyFont)
                            .foregroundStyle(PulseTheme.textPrimary)
                    }

                    Text("Pulse Watch 所有数据均存储在你的设备上，不会上传到任何服务器。健康数据仅从 Apple HealthKit 读取，用于生成本地分析和训练建议。我们不收集任何个人信息。")
                        .font(PulseTheme.captionFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                        .lineSpacing(3)
                }
            }
        }
        .pulseCard()
    }

    // MARK: - 通用组件

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: PulseTheme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PulseTheme.accent)
            Text(title)
                .font(PulseTheme.headlineFont)
                .foregroundStyle(PulseTheme.textPrimary)
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
        case .authorized: return "已开启"
        case .denied: return "已关闭"
        case .provisional: return "临时授权"
        case .ephemeral: return "临时授权"
        case .notDetermined: return "未设置"
        @unknown default: return "未知"
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
        case "low": return "每 30 分钟采集一次，更省电"
        case "high": return "每 5 分钟采集一次，更精确但耗电更多"
        default: return "每 15 分钟采集一次，平衡精度和电量"
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
                name: "健身房",
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

    private func saveManualGymLocation() {
        guard let lat = Double(gymLatitude),
              let lon = Double(gymLongitude),
              (-90...90).contains(lat),
              (-180...180).contains(lon) else { return }

        let location = SavedLocation(
            name: "健身房",
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
            showManualCoordEntry = false
            gymLatitude = ""
            gymLongitude = ""
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            gymSaveSuccess = false
        }
    }

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
