import SwiftUI

/// 训练计划推荐视图
/// 基于 HealthAnalyzer 恢复评分 + Push/Pull/Legs 轮换
struct TrainingPlanView: View {

    @State private var healthManager = HealthKitManager.shared
    @State private var connectivity = WatchConnectivityManager.shared
    @State private var appeared = false
    @State private var showWorkout = false
    @State private var selectedType: WorkoutSessionManager.WorkoutType = .strength

    /// 推荐的肌群轮换（Push / Pull / Legs 周期）
    private let rotations: [(group: String, label: String, icon: String, exercises: [String])] = [
        ("push", String(localized: "Push"), "arrow.up.circle.fill", [String(localized: "Bench Press"), String(localized: "Shoulder Press"), String(localized: "Tricep Pushdown")]),
        ("pull", String(localized: "Pull"), "arrow.down.circle.fill", [String(localized: "Deadlift"), String(localized: "Row"), String(localized: "Bicep Curl")]),
        ("legs", String(localized: "Legs"), "figure.walk.circle.fill", [String(localized: "Squat"), String(localized: "Leg Press"), String(localized: "Calf Raise")]),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 恢复评分
                recoveryHeader
                    .staggered(index: 0)

                // 今日推荐
                todayRecommendation
                    .staggered(index: 1)

                // PPL 轮换
                pplSection
                    .staggered(index: 2)

                // 渐进超载提示
                progressionTip
                    .staggered(index: 3)
            }
            .padding(.horizontal, 4)
        }
        .containerBackground(
            LinearGradient(
                colors: [Color(hex: "0D0C0B"), Color(hex: "111010")],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigation
        )
        .navigationTitle("Training Plan")
        .sheet(isPresented: $showWorkout) {
            WorkoutTrackingView(
                initialType: selectedType,
                onClose: { showWorkout = false }
            )
        }
    }

    // MARK: - 恢复评分头部

    private var recoveryHeader: some View {
        let score = recoveryScore

        return HStack(spacing: 10) {
            // 迷你评分环
            ZStack {
                Circle()
                    .stroke(PulseTheme.border, lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(PulseTheme.statusColor(for: score), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery Score")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
                Text(trainingAdviceLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.statusColor(for: score))
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
    }

    // MARK: - 今日推荐

    private var todayRecommendation: some View {
        let rec = recommendedRotation

        return VStack(alignment: .leading, spacing: 8) {
            Text("Today's Pick")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)

            HStack(spacing: 8) {
                Image(systemName: rec.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(PulseTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)

                    Text(rec.exercises.joined(separator: " · "))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }

            // 一键开始按钮
            Button {
                selectedType = .strength
                showWorkout = true
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "0D0C0B"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(PulseTheme.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
    }

    // MARK: - PPL 轮换

    private var pplSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Training Rotation")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textSecondary)

            ForEach(rotations, id: \.group) { rotation in
                let isRecommended = rotation.group == recommendedRotation.group

                HStack(spacing: 8) {
                    Image(systemName: rotation.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(isRecommended ? PulseTheme.accent : PulseTheme.textTertiary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(rotation.label)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(isRecommended ? PulseTheme.textPrimary : PulseTheme.textSecondary)

                        Text(rotation.exercises.joined(separator: " · "))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(PulseTheme.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isRecommended {
                        Text("Recommended")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(PulseTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(PulseTheme.accent.opacity(0.15))
                            )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PulseTheme.cardBackground)
        )
    }

    // MARK: - 渐进超载

    private var progressionTip: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(PulseTheme.statusGood)

            VStack(alignment: .leading, spacing: 1) {
                Text("Progressive Overload")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text("Try +2.5kg this week")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(PulseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PulseTheme.statusGood.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PulseTheme.statusGood.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - 数据计算

    /// 恢复评分（优先用 WC 同步值，否则用本地 HealthKit 计算）
    private var recoveryScore: Int {
        connectivity.receivedScore ?? healthManager.calculateDailyScore()
    }

    /// 训练建议标签
    private var trainingAdviceLabel: String {
        let score = recoveryScore
        switch score {
        case 80...:  return String(localized: "High intensity")
        case 60..<80: return String(localized: "Moderate intensity")
        case 40..<60: return String(localized: "Light recovery suggested")
        default:      return String(localized: "Rest recommended")
        }
    }

    /// 推荐的轮换（基于星期简单轮换，实际可结合上次训练类型）
    private var recommendedRotation: (group: String, label: String, icon: String, exercises: [String]) {
        // 基于上次训练组推算，简单用星期 mod 3
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let index = (dayOfWeek - 1) % 3
        return rotations[index]
    }
}

#Preview {
    NavigationStack {
        TrainingPlanView()
    }
}
