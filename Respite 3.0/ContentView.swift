import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var interventions: InterventionManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("respite.ui.lastWelcomeDay") private var lastWelcomeDay = ""
    @State private var showDailyWelcome = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
                .tag(1)
            FamilyControlsStatsView()
                .tabItem {
                    Label("Stats", systemImage: "shield.lefthalf.filled")
                }
                .tag(2)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            RespiteShortcutCoordinator.shared.attach(interventions)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                RegulationSettingsStore().lastRespiteBackgroundAt = Date()
            }
            if phase == .active {
                _ = ShieldManager.shared.checkGraceExpired(fromScheduledTimer: false)
                evaluateIdleBreathingGate()
                updateDailyWelcomeIfNeeded()
                RespiteStatsStore.shared.reloadFromDisk()
            }
        }
        .onChange(of: interventions.regulationChallenge) { _, newValue in
            if newValue != nil {
                showDailyWelcome = false
            } else {
                updateDailyWelcomeIfNeeded()
            }
        }
        .onChange(of: interventions.presentedBreathingGate) { _, newValue in
            if newValue != nil {
                showDailyWelcome = false
            } else {
                updateDailyWelcomeIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .respiteGraceDidExpire)) { _ in
            interventions.tryPresentPostGraceRandomGate()
        }
        .task {
            RespiteShortcutCoordinator.shared.attach(interventions)
            ShieldManager.shared.checkGraceExpired(fromScheduledTimer: false)
            try? RegulationActivityScheduler.restartMonitoring()
            try? await Task.sleep(for: .milliseconds(150))
            evaluateIdleBreathingGate()
            updateDailyWelcomeIfNeeded()
        }
        .fullScreenCover(isPresented: $showDailyWelcome) {
            DailyWelcomeView(isPresented: $showDailyWelcome) {
                lastWelcomeDay = RespiteStatsStore.dayKey(for: Date(), calendar: .current)
            }
        }
        .fullScreenCover(item: $interventions.presentedBreathingGate) { reason in
            TikTokBreathGateView(
                gateReason: reason,
                isPresented: Binding(
                    get: { interventions.presentedBreathingGate == reason },
                    set: { show in
                        if !show { interventions.presentedBreathingGate = nil }
                    }
                )
            )
            .environmentObject(interventions)
        }
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
                            RespiteStatsStore.shared.recordRegulationSessionCompleted()
                            let store = RegulationSettingsStore()
                            ShieldManager.shared.grantTemporaryUnlock(graceMinutes: store.gracePeriodMinutes)
                        },
                        onRegulationLeaveFlow: { interventions.armRegulationPuzzleDeepLinkQuietPeriod() }
                    )
                case .breathwork:
                    TikTokBreathGateView(
                        gateReason: .regulationShield,
                        isPresented: regulationPresentedBinding,
                        onRegulationComplete: {
                            RespiteStatsStore.shared.recordRegulationSessionCompleted()
                            let store = RegulationSettingsStore()
                            ShieldManager.shared.grantTemporaryUnlock(graceMinutes: store.gracePeriodMinutes)
                        },
                        onRegulationLeaveFlow: { interventions.armRegulationBreathworkDeepLinkQuietPeriod() }
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

    private func evaluateIdleBreathingGate() {
        guard scenePhase == .active else { return }
        guard interventions.regulationChallenge == nil else { return }
        guard interventions.presentedBreathingGate == nil else { return }
        guard !interventions.showPuzzleBreak else { return }

        let settings = RegulationSettingsStore()
        let minutes = settings.idleBreathingThresholdMinutes
        guard minutes > 0, let last = settings.lastRespiteBackgroundAt else { return }
        guard Date().timeIntervalSince(last) >= TimeInterval(minutes * 60) else { return }

        interventions.presentBreathingGate(.idleReturn)
    }

    private func updateDailyWelcomeIfNeeded() {
        let todayKey = RespiteStatsStore.dayKey(for: Date(), calendar: .current)
        guard lastWelcomeDay != todayKey else { return }
        guard interventions.regulationChallenge == nil, interventions.presentedBreathingGate == nil else { return }
        showDailyWelcome = true
    }
}
