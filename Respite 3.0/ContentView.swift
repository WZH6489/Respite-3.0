import SwiftUI

struct ContentView: View {
    @StateObject private var interventions = InterventionManager()

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
        .environmentObject(interventions)
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
        // Puzzle Break — sheet popup
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
        // Breathwork Timer — sheet popup
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
    }
}
