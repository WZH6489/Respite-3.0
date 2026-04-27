import SwiftUI

struct TikTokIntentGateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    /// When true, triggered from a shield deep link — grants TikTok grace unlock on completion.
    var isRegulationSession: Bool = false
    /// Called after the user completes the intent check (before dismissal).
    var onComplete: (() -> Void)? = nil

    @State private var selectedReason: IntentReason? = nil
    @State private var futurePlan: String = ""

    enum IntentReason: String, CaseIterable, Identifiable {
        case bored = "I'm just bored"
        case procrastinate = "Procrastinating something"
        case quickBreak = "Taking a quick break"
        case specific = "Looking for something specific"
        case catchUp = "Checking in with friends"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .bored: return "moon.zzz"
            case .procrastinate: return "clock.badge.xmark"
            case .quickBreak: return "cup.and.saucer"
            case .specific: return "magnifyingglass"
            case .catchUp: return "person.2"
            }
        }

        var reflection: String {
            switch self {
            case .bored:
                return "Boredom can be a signal to create, not just consume."
            case .procrastinate:
                return "Name one task you can do for five minutes first."
            case .quickBreak:
                return "A short walk or breath reset often works better than endless scroll."
            case .specific:
                return "Find what you need, then close the app with intention."
            case .catchUp:
                return "A direct message can feel better than passive checking."
            }
        }
    }

    var body: some View {
        ZStack {
            RespiteDynamicBackground()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        headerCard
                        reasonPicker
                        planCard
                        if let reason = selectedReason {
                            reflectionCard(for: reason)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }

                continueButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: selectedReason)
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
            Text("Pause and check in")
                .font(.system(size: 30, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)
            Text("Before you open this app, take a moment to name your intent.")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var reasonPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why are you opening this app right now?")
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundStyle(textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                ForEach(IntentReason.allCases) { reason in
                    ReasonRow(
                        reason: reason,
                        isSelected: selectedReason == reason
                    ) {
                        withAnimation { selectedReason = reason }
                    }
                }
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What will you do after this?")
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundStyle(textSecondary)
                .textCase(.uppercase)

            TextField("Example: After 10 minutes, I will start math homework.", text: $futurePlan)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.08 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke((colorScheme == .dark ? Color.white : Color.black).opacity(0.16), lineWidth: 1)
                        )
                )
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func reflectionCard(for reason: IntentReason) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Respite reflection", systemImage: "lightbulb.fill")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(RespiteTheme.berryAccent)

            Text(reason.reflection)
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundStyle(textPrimary)
                .lineSpacing(3)
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var continueButton: some View {
        VStack(spacing: 10) {
            Button("Return to planned work") {
                InteractionFeedback.tap()
                isPresented = false
            }
            .font(.system(size: 14, weight: .semibold, design: .default))
            .foregroundStyle(textSecondary)

            Button {
                InteractionFeedback.success()
                Task {
                    try? await HealthKitMindfulnessStore.writeMindfulness(minutes: 1)
                }
                onComplete?()
                isPresented = false
            } label: {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selectedReason != nil ? RespiteTheme.duskBlue.opacity(0.8) : RespiteTheme.textMuted.opacity(0.4))
                    )
            }
            .disabled(selectedReason == nil)
        }
    }

    private var textPrimary: Color { .primary }
    private var textSecondary: Color { .secondary }
}

private struct ReasonRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let reason: TikTokIntentGateView.IntentReason
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: reason.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? RespiteTheme.duskBlue : RespiteTheme.textMuted)
                    .frame(width: 24)

                Text(reason.rawValue)
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.88))

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? RespiteTheme.duskBlue : RespiteTheme.textMuted.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? RespiteTheme.mistBlue.opacity(0.16) : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? RespiteTheme.duskBlue.opacity(0.5) : (colorScheme == .dark ? Color.white : Color.black).opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
