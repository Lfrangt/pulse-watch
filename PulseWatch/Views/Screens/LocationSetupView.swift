import SwiftUI
import SwiftData

// Extracted from the deleted HomeView.swift during Phase 2-S01 rebuild.
// Visual styling intentionally unchanged (still PulseTheme) — full v2 restyle
// happens when this screen joins the Phase 2 backlog as its own sub-task.

struct LocationSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var locationManager = LocationManager.shared
    @State private var isSaving = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            VStack(spacing: PulseTheme.spacingL) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(PulseTheme.accent.opacity(0.1))
                        .frame(width: DS.Spacing.xxl * 2, height: DS.Spacing.xxl * 2)

                    Image(systemName: "location.circle.fill")
                        .font(.system(size: DS.Spacing.xxl))
                        .foregroundStyle(PulseTheme.accent)
                }

                Text(String(localized: "Set Frequent Location"))
                    .font(PulseTheme.titleFont)
                    .foregroundStyle(PulseTheme.textPrimary)

                Text(String(localized: "Add gym location\nPulse will remind you when you arrive"))
                    .font(PulseTheme.bodyFont)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                if saved {
                    HStack(spacing: PulseTheme.spacingS) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseTheme.statusGood)
                        Text(String(localized: "Saved"))
                            .foregroundStyle(PulseTheme.statusGood)
                    }
                    .font(PulseTheme.bodyFont)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        saveGymLocation()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(PulseTheme.background)
                        } else {
                            Text(String(localized: "Add gym using current location"))
                        }
                    }
                    .buttonStyle(PulseButtonStyle())
                    .disabled(isSaving)
                }

                Button(String(localized: "Set Up Later")) {
                    dismiss()
                }
                .foregroundStyle(PulseTheme.textTertiary)
                .padding(.bottom, PulseTheme.spacingL)
            }
            .padding(.horizontal, PulseTheme.spacingL)
            .background(PulseTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Close")) { dismiss() }
                        .foregroundStyle(PulseTheme.textSecondary)
                }
            }
        }
    }

    private func saveGymLocation() {
        isSaving = true
        locationManager.requestAuthorization()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let location = locationManager.saveCurrentAsLocation(
                name: String(localized: "Gym"),
                type: "gym",
                radius: 100
            ) {
                modelContext.insert(location)
                locationManager.registerGeofence(for: location)

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    saved = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
            isSaving = false
        }
    }
}
