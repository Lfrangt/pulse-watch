import SwiftUI

/// The hero card — shows daily score with organic, textured feel
struct StatusCard: View {
    let score: Int
    let headline: String
    let insight: String
    
    @State private var animatedScore: Int = 0
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            // Score ring + number
            HStack(alignment: .center, spacing: PulseTheme.spacingL) {
                // Circular score indicator
                ZStack {
                    // Track
                    Circle()
                        .stroke(PulseTheme.border, lineWidth: 6)
                        .frame(width: 88, height: 88)
                    
                    // Progress
                    Circle()
                        .trim(from: 0, to: appeared ? CGFloat(score) / 100 : 0)
                        .stroke(
                            PulseTheme.statusColor(for: score),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.2), value: appeared)
                    
                    // Score number
                    Text("\(animatedScore)")
                        .font(PulseTheme.scoreFont)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .contentTransition(.numericText())
                }
                
                VStack(alignment: .leading, spacing: PulseTheme.spacingXS) {
                    Text(headline)
                        .font(PulseTheme.headlineFont)
                        .foregroundStyle(PulseTheme.statusColor(for: score))
                    
                    Text(insight)
                        .font(PulseTheme.bodyFont)
                        .foregroundStyle(PulseTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
        }
        .padding(PulseTheme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL)
                .fill(PulseTheme.cardBackground)
                .overlay(
                    // Subtle gradient overlay for depth
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL)
                        .fill(PulseTheme.statusGradient(for: score))
                )
                .overlay(
                    // Thin border for definition
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL)
                        .stroke(PulseTheme.border, lineWidth: 0.5)
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                appeared = true
            }
            // Animate score counting up
            animateScore(to: score)
        }
    }
    
    private func animateScore(to target: Int) {
        let steps = 30
        let interval = 1.0 / Double(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.none) {
                    animatedScore = Int(Double(target) * Double(i) / Double(steps))
                }
            }
        }
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let sublabel: String?
    
    init(icon: String, label: String, value: String, sublabel: String? = nil) {
        self.icon = icon
        self.label = label
        self.value = value
        self.sublabel = sublabel
    }
    
    var body: some View {
        HStack(spacing: PulseTheme.spacingM) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 28)
            
            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(PulseTheme.captionFont)
                    .foregroundStyle(PulseTheme.textTertiary)
                if let sublabel {
                    Text(sublabel)
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.textTertiary)
                }
            }
            
            Spacer()
            
            // Value
            Text(value)
                .font(PulseTheme.metricFont)
                .foregroundStyle(PulseTheme.textPrimary)
        }
        .padding(.vertical, PulseTheme.spacingS)
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
                MetricRow(icon: "heart.fill", label: "心率", value: "\(Int(hr))", sublabel: "bpm")
                Divider().background(PulseTheme.border)
            }
            
            if let hrv {
                MetricRow(icon: "waveform.path.ecg", label: "HRV", value: "\(Int(hrv))", sublabel: "ms")
                Divider().background(PulseTheme.border)
            }
            
            if let spo2 = bloodOxygen {
                MetricRow(icon: "lungs.fill", label: "血氧", value: "\(Int(spo2))%")
                Divider().background(PulseTheme.border)
            }
            
            MetricRow(icon: "figure.walk", label: "步数", value: "\(steps)")
            Divider().background(PulseTheme.border)
            
            MetricRow(icon: "flame.fill", label: "活动消耗", value: "\(Int(calories))", sublabel: "kcal")
            
            if let sleep = sleepSummary {
                Divider().background(PulseTheme.border)
                MetricRow(icon: "moon.fill", label: "睡眠", value: sleep)
            }
        }
        .padding(PulseTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL)
                .fill(PulseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL)
                        .stroke(PulseTheme.border, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Training Card

struct TrainingCard: View {
    let plan: TrainingPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: PulseTheme.spacingM) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(PulseTheme.accent)
                Text("今日训练")
                    .font(PulseTheme.headlineFont)
                    .foregroundStyle(PulseTheme.textPrimary)
                Spacer()
                Text(plan.intensity.rawValue)
                    .font(PulseTheme.captionFont)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(intensityColor.opacity(0.2))
                    )
                    .foregroundStyle(intensityColor)
            }
            
            Text(plan.reason)
                .font(PulseTheme.captionFont)
                .foregroundStyle(PulseTheme.textSecondary)
            
            if !plan.suggestedExercises.isEmpty {
                VStack(alignment: .leading, spacing: PulseTheme.spacingS) {
                    ForEach(plan.suggestedExercises, id: \.name) { exercise in
                        HStack {
                            Text(exercise.name)
                                .font(PulseTheme.bodyFont)
                                .foregroundStyle(PulseTheme.textPrimary)
                            Spacer()
                            Text("\(exercise.sets)×\(exercise.reps)")
                                .font(PulseTheme.captionFont)
                                .foregroundStyle(PulseTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(PulseTheme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.radiusL)
                .fill(PulseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.radiusL)
                        .stroke(PulseTheme.border, lineWidth: 0.5)
                )
        )
    }
    
    private var intensityColor: Color {
        switch plan.intensity {
        case .light: return PulseTheme.statusGood
        case .moderate: return PulseTheme.statusModerate
        case .heavy: return PulseTheme.statusPoor
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            StatusCard(score: 78, headline: "状态良好", insight: "身体恢复很好，适合高强度训练")
            
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
                    SuggestedExercise(name: "平板卧推", sets: 4, reps: 8, suggestedWeight: 60),
                    SuggestedExercise(name: "上斜哑铃卧推", sets: 3, reps: 10, suggestedWeight: 22),
                    SuggestedExercise(name: "绳索飞鸟", sets: 3, reps: 12, suggestedWeight: 15),
                ],
                intensity: .heavy,
                reason: "上次练胸是3天前"
            ))
        }
        .padding()
    }
    .background(PulseTheme.background)
}
