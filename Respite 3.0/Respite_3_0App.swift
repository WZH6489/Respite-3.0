//
//  Respite_3_0App.swift
//  Respite 3.0
//
//  Created by William Huang on 2026-03-15.
//

import SwiftUI

@main
struct Respite_3_0App: App {
    @StateObject private var interventions = InterventionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(interventions)
                .onOpenURL { url in
                    RegulationURLHandler.handle(url, interventions: interventions)
                }
        }
    }
}
