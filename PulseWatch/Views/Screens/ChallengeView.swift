import SwiftUI
import SwiftData

/// 训练挑战页 — 创建和追踪训练挑战
struct ChallengeView: View {

    @Query(sort: \TrainingChallenge.startDate, order: .reverse) private var challenges: [TrainingChallenge]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreate = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseTheme.spacingM) {
                headerCard
                    .staggered(index: 0)

                if challenges.isEmpty {
                    emptyCard
                        .staggered(index: 1)
                } else {
                    // 进行中
                    let active = challenges.filter { $0.isActive && !$0.isExpired }
                    if !active.isEmpty {
                        sectionLabel(String(localized: "进行中"))
                        ForEach(Array(active.enumerated()), id: \.element.id) { i, c in
                            challengeCard(c)
                                .staggered(index: i + 1)
                        }
                    }

                    // 已完成/过期
                    let past = challenges.filter { !$0.isActive || $0.isExpired }
                    if !past.isEmpty {
                        sectionLabel(String(localized: "已结束"))
                        ForEach(Array(past.enumerated()), id: \.element.id) { i, c in
                            challengeCard(c)
                                .staggered(index: active.count + i + 1)
                        }
                    }
                }

                createButton
                    .staggered(index: challenges.count + 1)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.spacingM)
            .padding(.top, PulseTheme.spacingS)
        }
        .background(PulseTheme.background)
        .navigationTitle(String(localized: "训练挑战"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showCreate) {
            CreateChallengeSheet { name, type, target, duration in
                let c = TrainingChallenge(
                    name: name, challengeType: type.rawValue,
                    targetPerDay: target, durationDays: duration
                )
                modelContext.insert(c)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.activityCoral.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PulseTheme.activityCoral)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "训练挑战"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "设定挑战，每天打卡，养成习惯"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
            }
            Spacer()
        }
        .pulseCard()
    }

    private var emptyCard: some View {
        VStack(spacing: PulseTheme.spacingM) {
            Image(systemName: "trophy")
                .font(.system(size: 36))
                .foregroundStyle(PulseTheme.textTertiary.opacity(0.5))
            Text(String(localized: "还没有挑战"))
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)
            Text(String(localized: "创建一个训练挑战，坚持打卡"))
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PulseTheme.spacingXL)
        .pulseCard()
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.textTertiary)
            Spacer()
        }
    }

    // MARK: - Challenge Card

    private func challengeCard(_ challenge: TrainingChallenge) -> some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // 顶部信息
            HStack {
                let type = ChallengeType(rawValue: challenge.challengeType)
                Image(systemName: type?.icon ?? "star.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PulseTheme.activityCoral)

                Text(challenge.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)

                Spacer()

                if challenge.isActive && !challenge.isExpired {
                    Text(String(localized: "剩余 \(challenge.daysRemaining) 天"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }

            // 进度条
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(PulseTheme.surface2)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(PulseTheme.accentTeal)
                            .frame(width: geo.size.width * challenge.progressPercent, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(challenge.completedCount) / \(challenge.durationDays) " + String(localized: "天"))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                    Spacer()
                    Text(String(format: "%.0f%%", challenge.progressPercent * 100))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.accentTeal)
                }
            }

            // 日历热力图（最近 30 天）
            calendarGrid(challenge)

            // 今日打卡按钮
            if challenge.isActive && !challenge.isExpired {
                let todayDone = challenge.isCompleted(date: .now)
                Button {
                    if !todayDone {
                        challenge.markCompleted(date: .now)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: todayDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                        Text(todayDone ? String(localized: "今日已打卡") : String(localized: "今日打卡"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(todayDone ? PulseTheme.accentTeal : PulseTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                            .fill(todayDone ? PulseTheme.accentTeal.opacity(0.1) : PulseTheme.surface2)
                    )
                }
                .disabled(todayDone)
            }
        }
        .pulseCard()
    }

    // MARK: - Calendar Grid

    private func calendarGrid(_ challenge: TrainingChallenge) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let start = challenge.startDate
        let days = min(challenge.durationDays, 35)

        let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(0..<days, id: \.self) { offset in
                let date = cal.date(byAdding: .day, value: offset, to: start)!
                let done = challenge.isCompleted(date: date)
                let isFuture = date > today

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        done ? PulseTheme.accentTeal :
                        isFuture ? PulseTheme.surface2.opacity(0.5) :
                        PulseTheme.surface2
                    )
                    .frame(height: 16)
                    .overlay {
                        if cal.isDate(date, inSameDayAs: today) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(PulseTheme.accent, lineWidth: 1)
                        }
                    }
            }
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            showCreate = true
        } label: {
            HStack(spacing: PulseTheme.spacingS) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text(String(localized: "创建挑战"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundStyle(PulseTheme.activityCoral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                    .stroke(PulseTheme.activityCoral.opacity(0.3), lineWidth: 1)
                    .fill(PulseTheme.activityCoral.opacity(0.05))
            )
        }
    }
}

// MARK: - Create Challenge Sheet

struct CreateChallengeSheet: View {

    let onSave: (String, ChallengeType, Int, Int) -> Void

    @State private var name = ""
    @State private var selectedType: ChallengeType = .pushup
    @State private var targetPerDay: Int = 100
    @State private var durationDays: Int = 30
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: PulseTheme.spacingL) {
                // 名称
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "挑战名称"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)
                    TextField(String(localized: "例如：30天俯卧撑"), text: $name)
                        .textFieldStyle(.plain)
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: PulseTheme.radiusS, style: .continuous)
                                .fill(PulseTheme.surface2)
                        )
                }
                .pulseCard()

                // 类型选择
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    Text(String(localized: "挑战类型"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textTertiary)

                    ForEach(ChallengeType.allCases, id: \.rawValue) { type in
                        Button {
                            selectedType = type
                            targetPerDay = type.defaultTarget
                            if name.isEmpty { name = type.label }
                        } label: {
                            HStack(spacing: PulseTheme.spacingM) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(selectedType == type ? PulseTheme.activityCoral : PulseTheme.textTertiary)
                                    .frame(width: 24)
                                Text(type.label)
                                    .font(PulseTheme.bodyFont)
                                    .foregroundStyle(selectedType == type ? PulseTheme.textPrimary : PulseTheme.textSecondary)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PulseTheme.activityCoral)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .pulseCard()

                // 参数
                HStack(spacing: PulseTheme.spacingM) {
                    VStack(spacing: 4) {
                        Text(String(localized: "每日目标"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(PulseTheme.textTertiary)
                        Stepper("\(targetPerDay)", value: $targetPerDay, in: 1...1000, step: selectedType == .steps ? 1000 : 10)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .pulseCard()

                    VStack(spacing: 4) {
                        Text(String(localized: "天数"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(PulseTheme.textTertiary)
                        Stepper("\(durationDays)", value: $durationDays, in: 7...90, step: 7)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .pulseCard()
                }

                Spacer()

                Button {
                    let finalName = name.isEmpty ? selectedType.label : name
                    onSave(finalName, selectedType, targetPerDay, durationDays)
                    dismiss()
                } label: {
                    Text(String(localized: "开始挑战"))
                }
                .buttonStyle(PulseButtonStyle())
            }
            .padding(PulseTheme.spacingM)
            .background(PulseTheme.background)
            .navigationTitle(String(localized: "新挑战"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChallengeView()
    }
    .preferredColorScheme(.dark)
}
