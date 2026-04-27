import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Notification.Name {
    /// Posted once per app launch after the branded launch overlay has fully
    /// finished fading out. `DashboardView` listens so the greeting typewriter
    /// animation doesn't play while the overlay is still covering the screen.
    static let respiteLaunchDidFinish = Notification.Name("respite.launch.didFinish")
}

/// Tiny launch-lifecycle flag shared across views. Gated behind a type so
/// callers never touch `UserDefaults` or Combine publishers for something
/// that's really just "has the splash animation finished yet?".
enum RespiteLaunchState {
    static var didFinish = false
}

struct ContentView: View {
    @EnvironmentObject private var interventions: InterventionManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("dev.ui.interfaceMode") private var interfaceMode = "auto"
    @State private var showLaunchOverlay = !RespiteLaunchState.didFinish
    @State private var selectedTab: RespiteTab = .dashboard
    @StateObject private var bottomBarState = RespiteBottomBarState()

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTabContent
                .environmentObject(bottomBarState)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // Reserves enough vertical space that the floating logo
                    // never occludes the last row of scroll content. The bar
                    // itself is drawn as an overlay below.
                    Color.clear.frame(height: 74)
                }

            RespiteBottomBar(selected: $selectedTab, state: bottomBarState)
                .environmentObject(bottomBarState)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                RespiteShortcutDelivery.consumePending(into: interventions)
                ShieldManager.shared.checkGraceExpired()
                TikTokShieldManager.shared.checkGraceExpired()
                try? RegulationActivityScheduler.restartMonitoring()
                try? RegulationActivityScheduler.restartTikTokUsageMonitoring()
            }
        }
        .task {
            RespiteShortcutDelivery.consumePending(into: interventions)
            ShieldManager.shared.checkGraceExpired()
            TikTokShieldManager.shared.checkGraceExpired()
            TikTokShieldManager.shared.resumeIdlePollingIfNeeded()
            try? RegulationActivityScheduler.restartMonitoring()
            try? RegulationActivityScheduler.restartTikTokUsageMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .respiteOpenRegulateURL)) { notification in
            guard let url = notification.object as? URL else { return }
            RespiteShortcutDelivery.handleNotificationURL(url, interventions: interventions)
        }
        .preferredColorScheme(preferredColorScheme)
        .overlay {
            if showLaunchOverlay {
                RespiteLaunchOverlay()
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                showLaunchOverlay = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                RespiteLaunchState.didFinish = true
                                NotificationCenter.default.post(name: .respiteLaunchDidFinish, object: nil)
                            }
                        }
                    }
            }
        }
        // Intent-gate shield: secondary button → pick puzzle, breathwork, or intent
        .sheet(isPresented: Binding(
            get: { interventions.showTikTokUnlockPicker },
            set: { interventions.showTikTokUnlockPicker = $0 }
        )) {
            TikTokShieldOptionsView()
                .environmentObject(interventions)
        }
        // TikTok Intent Gate — manual trigger from Dashboard
        .fullScreenCover(isPresented: Binding(
            get: { interventions.showTikTokGate },
            set: { interventions.showTikTokGate = $0 }
        )) {
            TikTokIntentGateView(isPresented: Binding(
                get: { interventions.showTikTokGate },
                set: { interventions.showTikTokGate = $0 }
            ))
        }
        // TikTok Intent Gate — regulation deep link (shield action), cannot be dismissed without completing
        .fullScreenCover(isPresented: Binding(
            get: { interventions.regulationIntentGate },
            set: { interventions.regulationIntentGate = $0 }
        )) {
            TikTokIntentGateView(
                isPresented: Binding(
                    get: { interventions.regulationIntentGate },
                    set: { interventions.regulationIntentGate = $0 }
                ),
                isRegulationSession: true,
                onComplete: {
                    TikTokShieldManager.shared.grantUnlockAfterCheckIn()
                    let savedMinutes = max(1, RegulationSettingsStore().gracePeriodMinutes)
                    DailyProgressStore.recordMinutesSaved(savedMinutes)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        returnToPreviousApp()
                    }
                }
            )
            .interactiveDismissDisabled(true)
        }
        // Puzzle Break — sheet popup (dashboard)
        .sheet(isPresented: Binding(
            get: { interventions.showPuzzleBreak },
            set: { interventions.showPuzzleBreak = $0 }
        ), onDismiss: {
            interventions.preferredPuzzleLaunchMode = .tile
        }) {
            PuzzleBreakView(isPresented: Binding(
                get: { interventions.showPuzzleBreak },
                set: { interventions.showPuzzleBreak = $0 }
            ), initialMode: interventions.preferredPuzzleLaunchMode)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Breathwork Timer — sheet popup (dashboard)
        .sheet(isPresented: Binding(
            get: { interventions.showBreathwork },
            set: { interventions.showBreathwork = $0 }
        )) {
            BreathworkTimerView(isPresented: Binding(
                get: { interventions.showBreathwork },
                set: { interventions.showBreathwork = $0 }
            ))
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        // Shield deep link — full-screen (not draggable away like a sheet)
        .fullScreenCover(item: Binding(
            get: { interventions.regulationChallenge },
            set: { interventions.regulationChallenge = $0 }
        )) { challenge in
            Group {
                switch challenge {
                case .puzzle:
                    PuzzleBreakView(
                        isPresented: regulationPresentedBinding,
                        initialMode: interventions.regulationPuzzleLaunchMode,
                        isRegulationSession: true,
                        onSuccessfulSolve: {
                            let unlocksTikTok = interventions.regulationUnlocksTikTokOnly
                            applyRegulationUnlock(unlocksTikTok: unlocksTikTok)
                        }
                    )
                case .breathwork:
                    BreathworkTimerView(
                        isPresented: regulationPresentedBinding,
                        isRegulationSession: true,
                        onRegulationComplete: {
                            let unlocksTikTok = interventions.regulationUnlocksTikTokOnly
                            applyRegulationUnlock(unlocksTikTok: unlocksTikTok)
                        }
                    )
                }
            }
            .interactiveDismissDisabled(true)
        }
    }

    /// Renders the view for the currently selected tab. Wrapped in a
    /// `Group` with a `.id` so SwiftUI disposes the previous tab's view
    /// hierarchy on switch (matching what `TabView` used to do and keeping
    /// per-tab state cleanly isolated).
    @ViewBuilder
    private var selectedTabContent: some View {
        Group {
            switch selectedTab {
            case .dashboard:   DashboardView()
            case .study:       StudyFocusView()
            case .wellness:    WellnessView()
            case .reflections: ReflectionsView()
            case .settings:    SettingsView()
            }
        }
        .id(selectedTab)
    }

    private var regulationPresentedBinding: Binding<Bool> {
        Binding(
            get: { interventions.regulationChallenge != nil },
            set: { isShown in
                if !isShown { interventions.clearRegulationChallenge() }
            }
        )
    }

    /// Puzzle/breathwork from intent-gate apps unlock TikTok; from daily-limit apps unlock monitored selection.
    private func applyRegulationUnlock(unlocksTikTok: Bool) {
        let store = RegulationSettingsStore()
        let effectiveGrace = RecoveryInsightsStore.effectiveGraceMinutes(base: store.gracePeriodMinutes)
        let savedMinutes = max(1, effectiveGrace)
        DailyProgressStore.recordMinutesSaved(savedMinutes)
        if unlocksTikTok {
            TikTokShieldManager.shared.grantUnlockAfterCheckIn()
        } else {
            ShieldManager.shared.grantTemporaryUnlock(graceMinutes: effectiveGrace)
        }
    }

    /// Sends the user back to the app they came from by briefly suspending to the home screen.
    private func returnToPreviousApp() {
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
    }

    private var preferredColorScheme: ColorScheme? {
        switch interfaceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        case "auto":
            return nil
        default:
            return nil
        }
    }
}

private struct RespiteLaunchOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Opaque base so the dashboard never shows through. The dynamic
            // gradient alone uses `< 1.0` alpha stops, which lets content
            // behind the `.overlay` bleed into the splash. Stacking a solid
            // fill underneath keeps the launch screen fully detached.
            (colorScheme == .dark ? Color.black : Color(red: 0.95, green: 0.97, blue: 0.95))
                .ignoresSafeArea()
            RespiteDynamicBackground()
                .opacity(0.98)
            VStack(spacing: 18) {
                Image("RespiteLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 124, height: 124)
                    .shadow(
                        color: (colorScheme == .dark ? Color.white : Color.black).opacity(0.08),
                        radius: 14, y: 6
                    )
                    .accessibilityLabel("Respite")

                Text(welcomeHeadline)
                    .font(.system(size: 30, weight: .semibold, design: .default))
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.center)

                Text(welcomeSubhead)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(primaryText.opacity(0.62))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
    }

    private var primaryText: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    /// Returns "Welcome back, Name" for users who have completed onboarding
    /// and have a saved display name; falls back to a plain "Welcome" so
    /// first launches don't read awkwardly before the user has told us who
    /// they are.
    private var welcomeHeadline: String {
        guard UserProfileStore.hasCompletedOnboarding() else { return "Welcome" }
        let name = UserProfileStore.displayName()
        return name == "there" ? "Welcome back" : "Welcome back, \(name)"
    }

    private var welcomeSubhead: String {
        UserProfileStore.hasCompletedOnboarding()
            ? "Taking a breath before the day."
            : "A calmer rhythm for your day."
    }
}

enum RespiteTheme {
    static let textPrimary = Color(red: 0.13, green: 0.20, blue: 0.17)
    static let textSecondary = Color(red: 0.35, green: 0.45, blue: 0.40)
    static let textMuted = Color(red: 0.46, green: 0.55, blue: 0.50)

    static let sageLight = Color(red: 0.79, green: 0.87, blue: 0.70)
    static let sageMid = Color(red: 0.66, green: 0.78, blue: 0.59)
    static let sageDeep = Color(red: 0.50, green: 0.65, blue: 0.52)
    static let pine = Color(red: 0.42, green: 0.57, blue: 0.45)

    static let mistBlue = Color(red: 0.52, green: 0.72, blue: 0.77)
    static let duskBlue = Color(red: 0.43, green: 0.60, blue: 0.67)
    static let berryAccent = Color(red: 0.69, green: 0.49, blue: 0.62)

    static let surface = Color(red: 0.97, green: 0.98, blue: 0.96)
    static let surfaceSoft = Color(red: 0.95, green: 0.97, blue: 0.94)
    static let border = Color(red: 0.82, green: 0.88, blue: 0.84)

    static var appBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.91, green: 0.94, blue: 0.90),
                Color(red: 0.95, green: 0.97, blue: 0.94),
                Color(red: 0.94, green: 0.97, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var quoteGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.97, blue: 0.92),
                Color(red: 0.89, green: 0.95, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
