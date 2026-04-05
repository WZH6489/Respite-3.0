import SwiftUI

struct TikTokIntentGateView: View {
    @Binding var isPresented: Bool
    /// When true, triggered from a shield deep link — grants TikTok grace unlock on completion.
    var isRegulationSession: Bool = false
    /// Called after the user completes the intent check (before dismissal).
    var onComplete: (() -> Void)? = nil

    @State private var selectedReason: IntentReason? = nil
    @State private var showingContinue = false

    enum IntentReason: String, CaseIterable, Identifiable {
        case bored         = "I'm just bored"
        case procrastinate = "Procrastinating something"
        case quickBreak    = "Taking a quick break"
        case specific      = "Looking for something specific"
        case catchUp       = "Checking in with friends"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .bored:         return "moon.zzz"
            case .procrastinate: return "clock.badge.xmark"
            case .quickBreak:    return "cup.and.saucer"
            case .specific:      return "magnifyingglass"
            case .catchUp:       return "person.2"
            }
        }

        var reflection: String {
            switch self {
            case .bored:
                return "Boredom is actually a superpower — your brain is ready to create. Maybe try something active instead?"
            case .procrastinate:
                return "TikTok makes procrastination worse. What's the one thing you could do for just 5 minutes?"
            case .quickBreak:
                return "A real break recharges you. Scrolling actually drains your focus. 60 seconds of fresh air > 30 min of TikTok."
            case .specific:
                return "Great — find what you're looking for, then close the app. Set a mental timer."
            case .catchUp:
                return "DM them directly instead — it's more meaningful than passively watching their posts."
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        headerSection
                        reasonPicker
                        if let reason = selectedReason {
                            reflectionCard(for: reason)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 56)
                    .padding(.bottom, 24)
                }

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedReason)
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)
                Text("🤔")
                    .font(.system(size: 40))
            }

            Text("Hold on a second")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Before you open TikTok, take a moment\nto check in with yourself.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var reasonPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why are you opening TikTok right now?")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)

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
    }

    private func reflectionCard(for reason: IntentReason) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Respite says", systemImage: "lightbulb.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)

            Text(reason.reflection)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var continueButton: some View {
        VStack(spacing: 10) {
            Button {
                onComplete?()
                isPresented = false
            } label: {
                Text("Continue to TikTok")
                    .font(.headline)
                    .foregroundStyle(selectedReason != nil ? .white : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selectedReason != nil ? Color.orange : Color.white.opacity(0.08))
                    )
            }
            .disabled(selectedReason == nil)

            Text("Select a reason above to continue")
                .font(.caption)
                .foregroundStyle(.white.opacity(selectedReason == nil ? 0.4 : 0))
                .animation(.easeInOut(duration: 0.2), value: selectedReason)
        }
    }
}

private struct ReasonRow: View {
    let reason: TikTokIntentGateView.IntentReason
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: reason.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .orange : .white.opacity(0.5))
                    .frame(width: 24)

                Text(reason.rawValue)
                    .font(.body)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.75))

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .orange : .white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.12) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

