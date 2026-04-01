import DeviceActivity
import FamilyControls
import SwiftUI

struct SettingsView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var pauseMinutes = 15
    @State private var graceMinutes = 5
    @State private var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var scheduleErrorMessage: String?

    private let settings = RegulationSettingsStore()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch authorizationStatus {
                    case .approved:
                        FamilyActivityPicker(selection: $selection)
                            .onChange(of: selection) { _, newValue in
                                persistSelectionAndRestart(newValue)
                            }
                    case .notDetermined:
                        Text("Approve Screen Time access to choose apps to regulate.")
                            .foregroundStyle(.secondary)
                        Button("Request authorization") {
                            Task { await requestAuthorization() }
                        }
                    default:
                        Text("Family Controls must be approved to use shields and monitoring. Check Screen Time in Settings.")
                            .foregroundStyle(.secondary)
                        Button("Try again") {
                            Task { await requestAuthorization() }
                        }
                    }
                } header: {
                    Text("Monitored apps")
                } footer: {
                    Text("After \(pauseMinutes) minutes of use in a day, Respite can show a pause shield. Complete a challenge in the app for a temporary unlock.")
                }

                Section("Timing") {
                    Stepper("Pause after \(pauseMinutes) minutes", value: $pauseMinutes, in: 5...120, step: 5)
                        .disabled(authorizationStatus != .approved)
                        .onChange(of: pauseMinutes) { _, newValue in
                            settings.pauseThresholdMinutes = newValue
                            restartMonitoring()
                        }

                    Stepper("Grace period \(graceMinutes) minutes", value: $graceMinutes, in: 1...60, step: 1)
                        .onChange(of: graceMinutes) { _, newValue in
                            settings.gracePeriodMinutes = newValue
                        }
                }

                if let scheduleErrorMessage {
                    Section {
                        Text(scheduleErrorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                loadFromStore()
            }
            .onReceive(AuthorizationCenter.shared.$authorizationStatus) { authorizationStatus = $0 }
        }
    }

    private func loadFromStore() {
        if let stored = settings.loadSelection() {
            selection = stored
        }
        pauseMinutes = settings.pauseThresholdMinutes
        graceMinutes = settings.gracePeriodMinutes
    }

    private func persistSelectionAndRestart(_ newValue: FamilyActivitySelection) {
        settings.saveSelection(newValue)
        restartMonitoring()
    }

    private func restartMonitoring() {
        scheduleErrorMessage = nil
        do {
            try RegulationActivityScheduler.restartMonitoring(settings: settings)
        } catch {
            scheduleErrorMessage = error.localizedDescription
        }
    }

    private func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            scheduleErrorMessage = error.localizedDescription
        }
    }
}
