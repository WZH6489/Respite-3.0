import SwiftUI

struct TikTokIntentGateView: View {
    @Binding var isPresented: Bool
    /// When true, triggered from a shield deep link — grants TikTok grace unlock on completion.
    var isRegulationSession: Bool = false
    /// Called after the user completes the intent check (before dismissal).
    var onComplete: (() -> Void)? = nil

    @State private var selectedReason: IntentReason? = nil

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
            RespiteTheme.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        headerCard
                        reasonPicker
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
            Text("🤔")
                .font(.system(size: 40))
            Text("Hold on a second")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(RespiteTheme.textPrimary)
            Text("Before you open TikTok, take a moment to check in with yourself.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }

    private var reasonPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why are you opening TikTok right now?")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
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
        .background(cardBackground)
    }

    private func reflectionCard(for reason: IntentReason) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Respite reflection", systemImage: "lightbulb.fill")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(RespiteTheme.berryAccent)

            Text(reason.reflection)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textPrimary)
                .lineSpacing(3)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var continueButton: some View {
        Button {
            onComplete?()
            isPresented = false
        } label: {
            Text("Continue")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedReason != nil ? RespiteTheme.duskBlue : RespiteTheme.textMuted.opacity(0.4))
                )
        }
        .disabled(selectedReason == nil)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(RespiteTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(RespiteTheme.border, lineWidth: 1)
            )
    }
}

private struct ReasonRow: View {
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
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(RespiteTheme.textPrimary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? RespiteTheme.duskBlue : RespiteTheme.textMuted.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? RespiteTheme.mistBlue.opacity(0.16) : RespiteTheme.surfaceSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? RespiteTheme.duskBlue.opacity(0.5) : RespiteTheme.border.opacity(0.7), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
