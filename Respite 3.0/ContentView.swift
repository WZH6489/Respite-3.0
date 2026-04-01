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
                ShieldManager.shared.checkGraceExpired()
            }
        }
        .task {
            ShieldManager.shared.checkGraceExpired()
            try? RegulationActivityScheduler.restartMonitoring()
        }
        // TikTok Intent Gate — full-screen cover so it can't be swiped away accidentally
        .fullScreenCover(isPresented: Binding(
            get: { interventions.showTikTokGate },
            set: { interventions.showTikTokGate = $0 }
        )) {
            TikTokIntentGateView(isPresented: Binding(
                get: { interventions.showTikTokGate },
                set: { interventions.showTikTokGate = $0 }
            ))
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
                            let store = RegulationSettingsStore()
                            ShieldManager.shared.grantTemporaryUnlock(graceMinutes: store.gracePeriodMinutes)
                        }
                    )
                case .breathwork:
                    BreathworkTimerView(
                        isPresented: regulationPresentedBinding,
                        isRegulationSession: true,
                        onRegulationComplete: {
                            let store = RegulationSettingsStore()
                            ShieldManager.shared.grantTemporaryUnlock(graceMinutes: store.gracePeriodMinutes)
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
}
