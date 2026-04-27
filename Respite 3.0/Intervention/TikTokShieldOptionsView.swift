import SwiftUI

/// Shown when the user taps "Respite - intelligently shuffled" on an intent-gate shield.
/// Lets them choose how to earn temporary access.
struct TikTokShieldOptionsView: View {
    @EnvironmentObject private var interventions: InterventionManager
    @State private var showWhyAdaptive = false
    private let adaptiveSnapshot = RecoveryInsightsStore.currentSnapshot()
    private var adaptiveRecommendation: RegulationChallenge { adaptiveSnapshot.recommendedIntervention }

    private struct UnlockOption: Identifiable {
        enum Kind {
            case checkIn
            case breathwork
            case math
            case tile
        }

        let id = UUID()
        let kind: Kind
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
    }

    private let options: [UnlockOption] = [
        UnlockOption(
            kind: .checkIn,
            title: "Intent check-in",
            subtitle: "Pause, name your intent, then continue with purpose.",
            icon: "hand.raised.fill",
            tint: RespiteTheme.berryAccent
        ),
        UnlockOption(
            kind: .breathwork,
            title: "Breathing exercise",
            subtitle: "Guided 4-7-8 breathing to calm stimulation.",
            icon: "wind",
            tint: RespiteTheme.duskBlue
        ),
        UnlockOption(
            kind: .math,
            title: "Math challenge",
            subtitle: "Solve a short arithmetic challenge to reset focus.",
            icon: "function",
            tint: RespiteTheme.sageDeep
        ),
        UnlockOption(
            kind: .tile,
            title: "Tile puzzle",
            subtitle: "Reorder the tile board to unlock with active focus.",
            icon: "square.grid.3x3.fill",
            tint: RespiteTheme.pine
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard
                    adaptiveCard
                    if showWhyAdaptive { whyAdaptiveCard }

                    ForEach(options) { option in
                        optionRow(option)
                    }

                    Text("Complete any one option to unlock your selected apps for a short grace period.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(RespiteDynamicBackground().ignoresSafeArea())
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Respite - intelligently shuffled")
                .font(.system(size: 28, weight: .semibold, design: .default))
                .foregroundStyle(.primary)

            Text("Choose one focused reset before continuing.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var adaptiveCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                dismissThen {
                    if adaptiveRecommendation == .breathwork {
                        interventions.openRegulationChallenge(.breathwork, unlocksTikTok: true)
                    } else {
                        interventions.openRegulationChallenge(.puzzle, unlocksTikTok: true, puzzleMode: .math)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RespiteTheme.duskBlue)
                        .frame(width: 34, height: 34)
                        .background(RespiteTheme.duskBlue.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended now")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(adaptiveRecommendation == .breathwork ? "Breathwork reset" : "Math challenge")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .respiteGlassCard(cornerRadius: 16)
            }

            Button(showWhyAdaptive ? "Hide recommendation details" : "Why this recommendation?") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showWhyAdaptive.toggle()
                }
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(RespiteTheme.duskBlue)
        }
        .buttonStyle(.plain)
    }

    private var whyAdaptiveCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recommendation logic")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Manual end rate: \(percent(adaptiveSnapshot.manualEndRate)) · Reflection coverage: \(percent(adaptiveSnapshot.reflectionDaysRate)) · Weekly trend: \(signed(adaptiveSnapshot.weeklyTrendMinutes))")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Higher friction moments lean toward breathwork; lower friction moments lean toward challenge-based reset.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .respiteGlassCard(cornerRadius: 14)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func optionRow(_ option: UnlockOption) -> some View {
        Button {
            handle(option.kind)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: option.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(option.tint)
                    .frame(width: 38, height: 38)
                    .background(option.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)

                    Text(option.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .respiteGlassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }

    /// Dismiss the picker first so the next fullScreenCover can present.
    private func dismissThen(_ work: @escaping () -> Void) {
        interventions.showTikTokUnlockPicker = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            work()
        }
    }

    private func handle(_ kind: UnlockOption.Kind) {
        switch kind {
        case .checkIn:
            dismissThen {
                interventions.openRegulationIntentGate()
            }
        case .breathwork:
            dismissThen {
                interventions.openRegulationChallenge(.breathwork, unlocksTikTok: true)
            }
        case .math:
            dismissThen {
                interventions.openRegulationChallenge(.puzzle, unlocksTikTok: true, puzzleMode: .math)
            }
        case .tile:
            dismissThen {
                interventions.openRegulationChallenge(.puzzle, unlocksTikTok: true, puzzleMode: .tile)
            }
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((min(1.0, max(0.0, value)) * 100).rounded()))%"
    }

    private func signed(_ value: Int) -> String {
        if value == 0 { return "0m" }
        return value > 0 ? "+\(value)m" : "\(value)m"
    }
}
