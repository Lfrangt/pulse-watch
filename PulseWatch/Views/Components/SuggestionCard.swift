import SwiftUI

// MARK: - SuggestionCard
// Today's Training recommendation card — mirrors Today.jsx SuggestionCard.
// Top row: "Today's Training" eyebrow + intensity chip (accent fill).
// Headline: workout name (20pt headline).
// Caption: subtitle in calloutFont/textTertiary.
// Exercise rows: name (flex) + sets (60pt right) + weight (60pt right), hairline divider between.

struct SuggestionCard: View {
    struct Exercise: Identifiable {
        let id = UUID()
        let name: String
        let sets: String
        let weight: String

        init(name: String, sets: String, weight: String) {
            self.name = name
            self.sets = sets
            self.weight = weight
        }
    }

    let intensity: String
    let intensityColor: Color
    let workoutTitle: String
    let subtitle: String
    let exercises: [Exercise]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: eyebrow + intensity chip
            HStack(alignment: .center) {
                Text("Today's Training")
                    .pulseEyebrow()
                Spacer()
                intensityChip
            }

            // Headline
            Text(workoutTitle)
                .font(PulseTheme.metricSFont)
                .foregroundStyle(PulseTheme.textPrimary)
                .padding(.top, 10)

            // Caption
            Text(subtitle)
                .font(PulseTheme.calloutFont)
                .foregroundStyle(PulseTheme.textTertiary)
                .padding(.top, 4)

            // Exercise list
            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseRow(exercise: exercise)
                        .overlay(alignment: .top) {
                            if index > 0 {
                                Rectangle()
                                    .fill(PulseTheme.border)
                                    .frame(height: PulseTheme.hairline)
                            }
                        }
                }
            }
            .padding(.top, 16)
        }
        .pulseCard()
    }

    // MARK: - Intensity chip (accent fill)

    private var intensityChip: some View {
        Text(intensity)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(intensityColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(PulseTheme.accentSoft)
            )
    }
}

// MARK: - ExerciseRow

private struct ExerciseRow: View {
    let exercise: SuggestionCard.Exercise

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(exercise.name)
                .font(.system(size: 14))
                .foregroundStyle(PulseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(exercise.sets)
                .font(.system(size: 14).monospacedDigit())
                .foregroundStyle(PulseTheme.textSecondary)
                .frame(width: 60, alignment: .trailing)

            Text(exercise.weight)
                .font(.system(size: 14).monospacedDigit())
                .foregroundStyle(PulseTheme.textTertiary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview("Suggestion — Push day") {
    SuggestionCard(
        intensity: "Moderate",
        intensityColor: PulseTheme.accent,
        workoutTitle: "Push — Chest & Triceps",
        subtitle: "Last trained 3 days ago · recovery supports intensity",
        exercises: [
            .init(name: "Flat Bench Press", sets: "4 × 8", weight: "60 kg"),
            .init(name: "Incline DB Press", sets: "3 × 10", weight: "22 kg"),
            .init(name: "Cable Fly", sets: "3 × 12", weight: "15 kg"),
            .init(name: "Tricep Pushdown", sets: "3 × 12", weight: "20 kg")
        ]
    )
    .padding()
    .background(PulseTheme.background)
}

#Preview("Suggestion — Rest") {
    SuggestionCard(
        intensity: "Light",
        intensityColor: PulseTheme.accent,
        workoutTitle: "Active Recovery",
        subtitle: "Strain elevated · prioritize mobility today",
        exercises: [
            .init(name: "Foam Rolling", sets: "10 min", weight: "—"),
            .init(name: "Mobility Flow", sets: "15 min", weight: "—")
        ]
    )
    .padding()
    .background(PulseTheme.background)
}
