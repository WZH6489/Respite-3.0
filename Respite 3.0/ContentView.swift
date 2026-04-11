import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var interventions: InterventionManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
            FamilyControlsStatsView()
                .tabItem {
                    Label("Stats", systemImage: "shield.lefthalf.filled")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                RespiteShortcutDelivery.consumePending(into: interventions)
                ShieldManager.shared.checkGraceExpired()
                TikTokShieldManager.shared.checkGraceExpired()
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
        )) {
            PuzzleBreakView(isPresented: Binding(
                get: { interventions.showPuzzleBreak },
                set: { interventions.showPuzzleBreak = $0 }
            ))
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
        let savedMinutes = max(1, store.gracePeriodMinutes)
        DailyProgressStore.recordMinutesSaved(savedMinutes)
        if unlocksTikTok {
            TikTokShieldManager.shared.grantUnlockAfterCheckIn()
        } else {
            ShieldManager.shared.grantTemporaryUnlock(graceMinutes: store.gracePeriodMinutes)
        }
    }

    /// Sends the user back to the app they came from by briefly suspending to the home screen.
    private func returnToPreviousApp() {
        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
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
