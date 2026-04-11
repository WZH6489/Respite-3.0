import SwiftUI

/// Shown when the user taps "More options" on an intent-gate shield — pick how to earn a temporary unlock.
struct TikTokShieldOptionsView: View {
    @EnvironmentObject private var interventions: InterventionManager

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose your pause")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(RespiteTheme.textPrimary)

                    Text("Earn a temporary unlock with one mindful action.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(RespiteTheme.textSecondary)

                    optionRow(
                        title: "Check in",
                        subtitle: "Why are you opening this app?",
                        icon: "hand.raised.fill",
                        tint: RespiteTheme.berryAccent
                    ) {
                        dismissThen {
                            interventions.openRegulationIntentGate()
                        }
                    }

                    optionRow(
                        title: "Puzzle",
                        subtitle: "Solve a quick math problem",
                        icon: "puzzlepiece.extension.fill",
                        tint: RespiteTheme.sageDeep
                    ) {
                        dismissThen {
                            interventions.openRegulationChallenge(.puzzle, unlocksTikTok: true)
                        }
                    }

                    optionRow(
                        title: "Breathe",
                        subtitle: "4-7-8 breathing exercise",
                        icon: "wind",
                        tint: RespiteTheme.duskBlue
                    ) {
                        dismissThen {
                            interventions.openRegulationChallenge(.breathwork, unlocksTikTok: true)
                        }
                    }

                    Text("After you finish, the app unlocks for your grace period.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(RespiteTheme.textMuted)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(RespiteTheme.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        interventions.showTikTokUnlockPicker = false
                    }
                    .foregroundStyle(RespiteTheme.duskBlue)
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
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(RespiteTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(RespiteTheme.textMuted)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RespiteTheme.textMuted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RespiteTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(RespiteTheme.border, lineWidth: 1)
                    )
            )
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
