import SwiftUI

/// 训练完成分享屏 — 预览分享卡并选择比例，一键分享到社交平台
struct WorkoutShareScreen: View {

    let workoutName: String
    let workoutIcon: String
    let workoutColorHex: String
    let durationMinutes: Int
    let calories: Int?
    let averageHeartRate: Int?
    let maxHeartRate: Int?
    let distance: Double?
    let heartRateZones: [ShareHRZone]
    let date: Date

    @State private var selectedRatio: ShareCardView.CardRatio = .story
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isRendering = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PulseTheme.background.ignoresSafeArea()

                VStack(spacing: PulseTheme.spacingL) {
                    // Ratio picker
                    ratioPicker

                    // Card preview
                    ScrollView(.vertical, showsIndicators: false) {
                        cardPreview
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 0)

                    // Share button
                    shareButton
                        .padding(.horizontal, PulseTheme.spacingL)
                        .padding(.bottom, PulseTheme.spacingM)
                }
            }
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PulseTheme.textSecondary)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    // MARK: - Ratio Picker

    private var ratioPicker: some View {
        HStack(spacing: PulseTheme.spacingS) {
            ForEach(ShareCardView.CardRatio.allCases) { r in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedRatio = r
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(r.rawValue)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(r.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(selectedRatio == r ? PulseTheme.textPrimary : PulseTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedRatio == r ? Color.white.opacity(0.08) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(r.rawValue) \(r.label)")
                .accessibilityAddTraits(selectedRatio == r ? .isSelected : [])
            }
        }
        .padding(.horizontal, PulseTheme.spacingL)
        .padding(.top, PulseTheme.spacingS)
    }

    // MARK: - Card Preview

    private var card: ShareCardView {
        ShareCardView(
            workoutName: workoutName,
            workoutIcon: workoutIcon,
            workoutColorHex: workoutColorHex,
            durationMinutes: durationMinutes,
            calories: calories,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            distance: distance,
            heartRateZones: heartRateZones,
            date: date,
            ratio: selectedRatio
        )
    }

    private var cardPreview: some View {
        card
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            renderAndShare()
        } label: {
            HStack(spacing: 8) {
                if isRendering {
                    ProgressView()
                        .tint(PulseTheme.background)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                }
                Text(String(localized: "Share"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
        }
        .buttonStyle(PulseButtonStyle())
        .disabled(isRendering)
        .accessibilityLabel(String(localized: "Share"))
        .accessibilityHint(String(localized: "Renders the workout card and opens the share sheet"))
    }

    // MARK: - Render

    @MainActor
    private func renderAndShare() {
        isRendering = true
        shareImage = card.renderImage(for: selectedRatio)
        isRendering = false

        if shareImage != nil {
            showShareSheet = true
        }
    }
}

// MARK: - Convenience init from WorkoutHistoryEntry

extension WorkoutShareScreen {

    init(entry: WorkoutHistoryEntry) {
        self.init(
            workoutName: entry.activityName,
            workoutIcon: entry.activityIcon,
            workoutColorHex: entry.activityColor,
            durationMinutes: entry.durationMinutes,
            calories: entry.totalCalories.map { Int($0) },
            averageHeartRate: entry.averageHeartRate.map { Int($0) },
            maxHeartRate: entry.maxHeartRate.map { Int($0) },
            distance: entry.totalDistance,
            heartRateZones: entry.heartRateZones.map { zone in
                ShareHRZone(
                    name: zone.name,
                    percentage: zone.percentage,
                    colorHex: zone.colorHex
                )
            },
            date: entry.startDate
        )
    }
}

#Preview {
    WorkoutShareScreen(
        workoutName: "Push Day",
        workoutIcon: "dumbbell.fill",
        workoutColorHex: "D4A056",
        durationMinutes: 48,
        calories: 320,
        averageHeartRate: 142,
        maxHeartRate: 175,
        distance: nil,
        heartRateZones: [
            ShareHRZone(name: "Warm-up", percentage: 0.10, colorHex: "7FB069"),
            ShareHRZone(name: "Fat Burn", percentage: 0.15, colorHex: "A8C256"),
            ShareHRZone(name: "Cardio", percentage: 0.40, colorHex: "D4A056"),
            ShareHRZone(name: "Anaerobic", percentage: 0.25, colorHex: "D47456"),
            ShareHRZone(name: "Peak", percentage: 0.10, colorHex: "C75C5C"),
        ],
        date: .now
    )
    .preferredColorScheme(.dark)
}
