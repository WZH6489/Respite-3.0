//
//  Respite_3_0App.swift
//  Respite 3.0
//
//  Created by William Huang on 2026-03-15.
//

import SwiftUI

extension Notification.Name {
    /// Posted from Settings ("Replay welcome screen") to force the onboarding
    /// sheet to present again without requiring an app relaunch.
    static let respiteReplayOnboarding = Notification.Name("respite.replayOnboarding")
}

@main
struct Respite_3_0App: App {
    @StateObject private var interventions = InterventionManager()
    @State private var showOnboarding = !UserProfileStore.hasCompletedOnboarding()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(interventions)
                .onOpenURL { url in
                    RespiteShortcutDelivery.clearPendingIfMatches(url)
                    RegulationURLHandler.handle(url, interventions: interventions)
                }
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }
                .onReceive(NotificationCenter.default.publisher(for: .respiteReplayOnboarding)) { _ in
                    showOnboarding = true
                }
        }
    }
}
