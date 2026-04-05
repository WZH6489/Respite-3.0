import SwiftUI

/// Shown when the user taps "More options" on an intent-gate shield — pick how to earn a temporary unlock.
struct TikTokShieldOptionsView: View {
    @EnvironmentObject private var interventions: InterventionManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    optionRow(
                        title: "Check in",
                        subtitle: "Why are you opening this app?",
                        icon: "hand.raised.fill",
                        tint: .orange
                    ) {
                        dismissThen {
                            interventions.openRegulationIntentGate()
                        }
                    }

                    optionRow(
                        title: "Puzzle",
                        subtitle: "Solve a quick math problem",
                        icon: "puzzlepiece.extension.fill",
                        tint: .purple
                    ) {
                        dismissThen {
                            interventions.openRegulationChallenge(.puzzle, unlocksTikTok: true)
                        }
                    }

                    optionRow(
                        title: "Breathe",
                        subtitle: "4-7-8 breathing exercise",
                        icon: "wind",
                        tint: .cyan
                    ) {
                        dismissThen {
                            interventions.openRegulationChallenge(.breathwork, unlocksTikTok: true)
                        }
                    }
                } header: {
                    Text("Earn a temporary unlock")
                } footer: {
                    Text("After you finish, the app unlocks for your grace period. If you still see “Restricted,” check Screen Time in Settings — that block is separate from Respite.")
                }
            }
            .navigationTitle("Continue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        interventions.showTikTokUnlockPicker = false
                    }
                }
            }
        }
    }

    private func optionRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    /// Dismiss the picker first so the next fullScreenCover can present (SwiftUI presentation stack).
    private func dismissThen(_ work: @escaping () -> Void) {
        interventions.showTikTokUnlockPicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            work()
        }
    }
}
