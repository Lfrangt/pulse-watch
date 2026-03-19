import SwiftUI

// MARK: - Hero Status Card

/// The hero card — daily score with warm, organic feel and glow
struct StatusCard: View {
    let score: Int
    let headline: String
    let insight: String

    @State private var animatedScore: Int = 0
    @State private var ringProgress: CGFloat = 0
    @State private var appeared = false

    private var statusColor: Color { PulseTheme.statusColor(for: score) }

    var body: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack(alignment: .center, spacing: PulseTheme.spacingL) {
                // Score ring with glow
                ZStack {
                    // Ambient glow behind ring
                    Circle()
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)

                    // Track
                    Circle()
                        .stroke(PulseTheme.border, lineWidth: 5)
                        .frame(width: 88, height: 88)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            statusColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(-90))

                    // Score number
                    Text("\(animatedScore)")
                        .font(PulseTheme.scoreFont)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                    Text(headline)
                        .font(PulseTheme.headlineFont)
                        .foregroundStyle(statusColor)

                    Text(insight)
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Recovery Score"))
        .accessibilityValue(String(localized: "\(score) out of 100, \(headline). \(insight)"))
        .padding(PulseTheme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .fill(PulseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                        .fill(PulseTheme.statusGradient(for: score))
                )
                .shadow(color: PulseTheme.cardShadow, radius: 20, y: 8)
                .shadow(color: statusColor.opacity(0.08), radius: 30, y: 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL, style: .continuous)
                .stroke(statusColor.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                ringProgress = CGFloat(score) / 100.0
                appeared = true
            }
            animateScoreCount(to: score)
        }
    }

    private func animateScoreCount(to target: Int) {
        let steps = 35
        let interval = 0.9 / Double(steps)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.none) {
                    animatedScore = Int(Double(target) * Double(i) / Double(steps))
                }
            }
        }
    }
}

// MARK: - Metrics Card

struct MetricsCard: View {
    let heartRate: Double?
    let hrv: Double?
    let bloodOxygen: Double?
    let steps: Int
    let calories: Double
    let sleepSummary: String?

    var body: some View {
        VStack(spacing: 0) {
            if let hr = heartRate {
                MetricRow(icon: "heart.fill", label: String(localized: "Heart Rate"), value: "\(Int(hr))", unit: "bpm", color: PulseTheme.activityAccent)
                metricDivider
            }

            if let hrv {
                MetricRow(icon: "waveform.path.ecg", label: "HRV", value: "\(Int(hrv))", unit: "ms", color: PulseTheme.accent)
                metricDivider
            }

            if let spo2 = bloodOxygen {
                MetricRow(icon: "lungs.fill", label: String(localized: "Blood Oxygen"), value: "\(Int(spo2))%", color: PulseTheme.statusGood)
                metricDivider
            }

            MetricRow(icon: "figure.walk", label: String(localized: "Steps"), value: formatSteps(steps), color: PulseTheme.statusGood)
            metricDivider

            MetricRow(icon: "flame.fill", label: String(localized: "Active Calories"), value: "\(Int(calories))", unit: "kcal", color: PulseTheme.sleepAccent)

            if let sleep = sleepSummary {
                metricDivider
                MetricRow(icon: "moon.fill", label: String(localized: "Sleep"), value: sleep, color: PulseTheme.sleepAccent)
            }
        }
        .pulseCard(padding: PulseTheme.spacingM)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(PulseTheme.border.opacity(0.5))
            .frame(height: 0.5)
            .padding(.horizontal, PulseTheme.spacingS)
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 10000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        } else if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    var unit: String? = nil
    var color: Color = PulseTheme.accent

    var body: some View {
        HStack(spacing: PulseTheme.spacingM) {
            // Icon with colored badge
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

            // Label
            Text(label)
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Spacer()

            // Value + unit
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(PulseTheme.metricFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if let unit {
                    Text(unit)
                        .font(PulseTheme.metricLabelFont)
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, PulseTheme.spacingS)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)
    }
}

// MARK: - Training Card

struct TrainingCard: View {
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // Header
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PulseTheme.accent.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PulseTheme.accent)
                }

                Text("Today's Training")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                Spacer()

                // Intensity badge
                Text(plan.intensity.rawValue)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(intensityColor.opacity(0.15))
                    )
                    .foregroundStyle(intensityColor)
            }

            // Reason
            Text(plan.reason)
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)

            // Exercise list
            if !plan.suggestedExercises.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(plan.suggestedExercises.enumerated()), id: \.element.name) { index, exercise in
                        HStack {
                            Text(exercise.name)
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)

                            Spacer()

                            HStack(spacing: PulseTheme.spacingXS) {
                                Text("\(exercise.sets)×\(exercise.reps)")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(PulseTheme.textSecondary)

                                if let weight = exercise.suggestedWeight {
                                    Text("\(Int(weight))kg")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(PulseTheme.textTertiary)
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        if index < plan.suggestedExercises.count - 1 {
                            Rectangle()
                                .fill(PulseTheme.border.opacity(0.3))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .pulseCard()
        // Subtle left accent bar
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: PulseTheme.radiusL,
                bottomLeadingRadius: PulseTheme.radiusL
            )
            .fill(intensityColor.opacity(0.3))
            .frame(width: 3)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Today's Training Plan"))
        .accessibilityHint(String(localized: "Shows your recommended exercises for today based on recovery data"))
    }

    private var intensityColor: Color {
        switch plan.intensity {
        case .light: return PulseTheme.statusGood
        case .moderate: return PulseTheme.sleepAccent
        case .heavy: return PulseTheme.activityAccent
        }
    }
}

// MARK: - Recovery Card

struct RecoveryCard: View {
    let note: String

    var body: some View {
        HStack(spacing: PulseTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PulseTheme.sleepAccent.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PulseTheme.sleepAccent)
            }

            Text(note)
                .font(PulseTheme.bodyFont)
                .foregroundStyle(PulseTheme.textSecondary)

            Spacer()
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .fill(PulseTheme.sleepAccent.opacity(0.06))
                .shadow(color: PulseTheme.cardShadow.opacity(0.3), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.radiusM, style: .continuous)
                .stroke(PulseTheme.sleepAccent.opacity(0.12), lineWidth: 0.5)
        )
    }
}

// MARK: - Previews

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            StatusCard(score: 78, headline: String(localized: "Good"), insight: String(localized: "Great recovery — go hard today"))

            MetricsCard(
                heartRate: 72,
                hrv: 55,
                bloodOxygen: 97,
                steps: 6420,
                calories: 280,
                sleepSummary: "7h12m"
            )

            TrainingCard(plan: TrainingPlan(
                targetMuscleGroup: "chest",
                daysSinceLastTrained: 3,
                suggestedExercises: [
                    SuggestedExercise(name: String(localized: "Flat Bench Press"), sets: 4, reps: 8, suggestedWeight: 60),
                    SuggestedExercise(name: String(localized: "Incline Dumbbell Press"), sets: 3, reps: 10, suggestedWeight: 22),
                    SuggestedExercise(name: String(localized: "Cable Fly"), sets: 3, reps: 12, suggestedWeight: 15),
                ],
                intensity: .heavy,
                reason: String(localized: "Last chest day was 3 days ago")
            ))

            RecoveryCard(note: String(localized: "HRV low (28ms), resting HR elevated (78bpm)"))
        }
        .padding()
    }
    .background(PulseTheme.background)
    .preferredColorScheme(.dark)
}
