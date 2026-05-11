import SwiftUI
import SwiftData

/// 训练挑战页 — 创建和追踪训练挑战
struct ChallengeView: View {

    @Query(sort: \TrainingChallenge.startDate, order: .reverse) private var challenges: [TrainingChallenge]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreate = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.m) {
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
            .padding(.horizontal, DS.Spacing.m)
            .padding(.top, DS.Spacing.s)
        }
        .background(DS.Color.bg)
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
        HStack(spacing: DS.Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PulseTheme.activityCoral.opacity(0.12))
                    .frame(width: DS.Spacing.xl + DS.Spacing.xs, height: DS.Spacing.xl + DS.Spacing.xs)
                Image(systemName: "flame.fill")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(PulseTheme.activityCoral)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "训练挑战"))
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(DS.Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "设定挑战，每天打卡，养成习惯"))
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(DS.Color.inkDim)
            }
            Spacer()
        }
        .pulseCard()
    }

    private var emptyCard: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: "trophy")
                .font(DS.Typography.title1)
                .foregroundStyle(DS.Color.inkDim.opacity(0.5))
            Text(String(localized: "还没有挑战"))
                .font(PulseTheme.bodyFont)
                .foregroundStyle(DS.Color.inkMid)
            Text(String(localized: "创建一个训练挑战，坚持打卡"))
                .font(PulseTheme.captionFont)
                .foregroundStyle(DS.Color.inkDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .pulseCard()
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(DS.Typography.bodyS.weight(.semibold))
                .foregroundStyle(DS.Color.inkDim)
            Spacer()
        }
    }

    // MARK: - Challenge Card

    private func challengeCard(_ challenge: TrainingChallenge) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            // 顶部信息
            HStack {
                let type = ChallengeType(rawValue: challenge.challengeType)
                Image(systemName: type?.icon ?? "star.fill")
                    .font(DS.Typography.bodyS.weight(.medium))
                    .foregroundStyle(PulseTheme.activityCoral)

                Text(challenge.name)
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(DS.Color.ink)

                Spacer()

                if challenge.isActive && !challenge.isExpired {
                    Text(String(localized: "剩余 \(challenge.daysRemaining) 天"))
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Color.inkDim)
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
                            .fill(DS.Color.accent)
                            .frame(width: geo.size.width * challenge.progressPercent, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(challenge.completedCount) / \(challenge.durationDays) " + String(localized: "天"))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.inkDim)
                    Spacer()
                    Text(String(format: "%.0f%%", challenge.progressPercent * 100))
                        .font(DS.Typography.caption.weight(.bold))
                        .foregroundStyle(DS.Color.accent)
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
                            .font(DS.Typography.bodyS)
                        Text(todayDone ? String(localized: "今日已打卡") : String(localized: "今日打卡"))
                            .font(DS.Typography.bodyS.weight(.medium))
                    }
                    .foregroundStyle(todayDone ? DS.Color.accent : DS.Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                            .fill(todayDone ? DS.Color.accent.opacity(0.1) : PulseTheme.surface2)
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
                        done ? DS.Color.accent :
                        isFuture ? PulseTheme.surface2.opacity(0.5) :
                        PulseTheme.surface2
                    )
                    .frame(height: 16)
                    .overlay {
                        if cal.isDate(date, inSameDayAs: today) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(DS.Color.accent, lineWidth: 1)
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
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "plus.circle.fill")
                    .font(DS.Typography.body)
                Text(String(localized: "创建挑战"))
                    .font(DS.Typography.body.weight(.medium))
            }
            .foregroundStyle(PulseTheme.activityCoral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.card)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous)
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
            VStack(spacing: DS.Spacing.l) {
                // 名称
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "挑战名称"))
                        .font(DS.Typography.bodyS.weight(.medium))
                        .foregroundStyle(DS.Color.inkDim)
                    TextField(String(localized: "例如：30天俯卧撑"), text: $name)
                        .textFieldStyle(.plain)
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(DS.Color.ink)
                        .padding(DS.Spacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                                .fill(PulseTheme.surface2)
                        )
                }
                .pulseCard()

                // 类型选择
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    Text(String(localized: "挑战类型"))
                        .font(DS.Typography.bodyS.weight(.medium))
                        .foregroundStyle(DS.Color.inkDim)

                    ForEach(ChallengeType.allCases, id: \.rawValue) { type in
                        Button {
                            selectedType = type
                            targetPerDay = type.defaultTarget
                            if name.isEmpty { name = type.label }
                        } label: {
                            HStack(spacing: DS.Spacing.m) {
                                Image(systemName: type.icon)
                                    .font(DS.Typography.bodyS)
                                    .foregroundStyle(selectedType == type ? PulseTheme.activityCoral : DS.Color.inkDim)
                                    .frame(width: 24)
                                Text(type.label)
                                    .font(PulseTheme.bodyFont)
                                    .foregroundStyle(selectedType == type ? DS.Color.ink : DS.Color.inkMid)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PulseTheme.activityCoral)
                                }
                            }
                            .padding(.vertical, DS.Spacing.s)
                        }
                    }
                }
                .pulseCard()

                // 参数
                HStack(spacing: DS.Spacing.m) {
                    VStack(spacing: 4) {
                        Text(String(localized: "每日目标"))
                            .font(DS.Typography.caption.weight(.medium))
                            .foregroundStyle(DS.Color.inkDim)
                        Stepper("\(targetPerDay)", value: $targetPerDay, in: 1...1000, step: selectedType == .steps ? 1000 : 10)
                            .font(DS.Typography.body.weight(.semibold))
                            .foregroundStyle(DS.Color.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .pulseCard()

                    VStack(spacing: 4) {
                        Text(String(localized: "天数"))
                            .font(DS.Typography.caption.weight(.medium))
                            .foregroundStyle(DS.Color.inkDim)
                        Stepper("\(durationDays)", value: $durationDays, in: 7...90, step: 7)
                            .font(DS.Typography.body.weight(.semibold))
                            .foregroundStyle(DS.Color.ink)
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
            .padding(DS.Spacing.m)
            .background(DS.Color.bg)
            .navigationTitle(String(localized: "新挑战"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                        .foregroundStyle(DS.Color.inkMid)
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
