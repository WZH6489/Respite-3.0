import SwiftUI
import AppIntents

struct OnboardingView: View {
    @Binding var isPresented: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var nameInput: String = ""
    @State private var selectedProfileType: UserProfileType = UserProfileStore.profileType()
    @FocusState private var isNameFocused: Bool
    @AppStorage("profile.displayName", store: UserDefaults(suiteName: RegulationAppGroup.id)) private var storedProfileName = "there"
    @AppStorage("shortcuts.didOpenShortcutsPage") private var openedShortcutsPage = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerCard
                        .padding(.top, 18)

                    nameCard
                    profileTypeCard
                    featuresCard
                    setupAutomationCard
                    continueButton
                        .padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.top, 32)
                .padding(.bottom, 36)
            }
            .contentShape(Rectangle())
            .onTapGesture { isNameFocused = false }
            .background(RespiteDynamicBackground().ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isNameFocused = false
                    }
                }
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            if UserProfileStore.displayName() != "there" {
                nameInput = UserProfileStore.displayName()
            }
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        VStack(alignment: .center, spacing: 14) {
            Image("RespiteLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 108, height: 108)
                .shadow(color: shadowColor.opacity(0.12), radius: 14, y: 6)
                .accessibilityLabel("Respite")

            Text("Welcome to Respite")
                .font(.system(size: 30, weight: .semibold, design: .default))
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)

            Text("A calm companion for reducing automatic scrolling and building intentional habits.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 22)
        .respiteGlassCard(cornerRadius: 26)
        .shadow(color: shadowColor.opacity(0.10), radius: 22, y: 10)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your name")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryText)

            TextField("How should we greet you?", text: $nameInput)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .focused($isNameFocused)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(inputFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(inputStroke, lineWidth: 1)
                        )
                )

            Text("You can edit this later in Settings.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryText.opacity(0.75))
        }
        .padding(18)
        .respiteGlassCard(cornerRadius: 22)
        .shadow(color: shadowColor.opacity(0.08), radius: 16, y: 6)
    }

    private var profileTypeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Personalize your plan")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryText)

            Text("Choose your primary routine so Respite can preload better defaults.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(primaryText)

            HStack(spacing: 8) {
                ForEach(UserProfileType.allCases, id: \.self) { type in
                    Button(type.title) {
                        selectedProfileType = type
                        InteractionFeedback.tap()
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(selectedProfileType == type ? .white : primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selectedProfileType == type ? RespiteTheme.pine : inputFill)
                    )
                }
            }
        }
        .padding(18)
        .respiteGlassCard(cornerRadius: 22)
        .shadow(color: shadowColor.opacity(0.08), radius: 16, y: 6)
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What Respite does")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryText)

            VStack(alignment: .leading, spacing: 10) {
                featureRow("Dashboard: shows daily time saved, blocked apps, and quick interventions.")
                featureRow("Daily limit + Intent gate: pause access with check-ins and shields.")
                featureRow("Interventions: intent prompt, puzzle break, and breathwork timer.")
                featureRow("Study mode: configurable focus/break timer with fullscreen focus mode.")
                featureRow("Reflections: journal prompts with trend + long-term time impact.")
                featureRow("Stats: weekly app activity breakdown from Family Controls data.")
                featureRow("Blocking supports apps, categories, and websites from the same picker.")
            }
        }
        .padding(18)
        .respiteGlassCard(cornerRadius: 22)
        .shadow(color: shadowColor.opacity(0.08), radius: 16, y: 6)
    }

    private var setupAutomationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick setup")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryText)

            Text("Shortcuts can’t be created silently by iOS, but this opens your Respite shortcuts page so setup is fast.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(primaryText)

            HStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .foregroundStyle(checkmarkColor)
                Text("Open Respite shortcuts page")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryText)
            }

            ShortcutsLink(action: {
                openedShortcutsPage = true
            })
                .shortcutsLinkStyle(.automatic)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(inputFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(inputStroke, lineWidth: 1)
                        )
                )
        }
        .padding(18)
        .respiteGlassCard(cornerRadius: 22)
        .shadow(color: shadowColor.opacity(0.08), radius: 16, y: 6)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(checkmarkColor)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var continueButton: some View {
        Button {
            UserProfileStore.setDisplayName(nameInput)
            UserProfileStore.setProfileType(selectedProfileType)
            UserProfileStore.applyDefaults(for: selectedProfileType)
            storedProfileName = UserProfileStore.displayName()
            UserProfileStore.markOnboardingCompleted()
            isPresented = false
        } label: {
            Text("Continue")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(buttonForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(buttonFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(primaryText.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
                        )
                )
                .shadow(color: shadowColor.opacity(0.15), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Adaptive colors

    private var primaryText: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    private var secondaryText: Color {
        primaryText.opacity(colorScheme == .dark ? 0.72 : 0.62)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black : Color.black
    }

    private var checkmarkColor: Color {
        colorScheme == .dark ? RespiteTheme.sageLight : RespiteTheme.pine
    }

    private var inputFill: Color {
        (colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.10 : 0.05)
    }

    private var inputStroke: Color {
        (colorScheme == .dark ? Color.white : Color.black).opacity(0.16)
    }

    private var buttonFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.92)
            : Color.black.opacity(0.88)
    }

    private var buttonForeground: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
}
