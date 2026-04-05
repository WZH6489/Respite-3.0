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
