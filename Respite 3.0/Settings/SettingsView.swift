import DeviceActivity
import FamilyControls
import SwiftUI

struct SettingsView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var tiktokSelection = FamilyActivitySelection()
    @State private var pauseMinutes = 15
    @State private var graceMinutes = 5
    @State private var tiktokIdleMinutes = 30
    @State private var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var scheduleErrorMessage: String?

    @State private var showMonitoredPicker = false
    @State private var showIntentGatePicker = false

    private let settings = RegulationSettingsStore()

    var body: some View {
        NavigationStack {
            Form {
                authSection

                if authorizationStatus == .approved {
                    monitoredAppsSection
                    intentGateSection
                }

                shortcutsSection

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
            .sheet(isPresented: $showMonitoredPicker) {
                monitoredPickerSheet
            }
            .sheet(isPresented: $showIntentGatePicker) {
                intentGatePickerSheet
            }
        }
    }

    // MARK: - Authorization

    @ViewBuilder
    private var authSection: some View {
        Section {
            switch authorizationStatus {
            case .approved:
                Label("Screen Time access is on", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            case .notDetermined:
                Text("Approve Screen Time access to choose apps and use shields.")
                    .foregroundStyle(.secondary)
                Button("Request authorization") {
                    Task { await requestAuthorization() }
                }
            default:
                Text("Family Controls must be approved. Check Screen Time in Settings.")
                    .foregroundStyle(.secondary)
                Button("Try again") {
                    Task { await requestAuthorization() }
                }
            }
        } header: {
            Text("Access")
        }
    }

    // MARK: - Shortcuts

    private var shortcutsSection: some View {
        Section {
            Text("Run Respite when you open an app: Shortcuts → Automation → Personal Automation → App → Is Opened → choose the app → Run Immediately → Add Action → search for “Respite” → use “Activate Respite (check-in)” (or another Respite action). Create one automation per app. Re-select the app in the shortcut if it doesn’t run.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } header: {
            Text("Shortcuts")
        } footer: {
            Text("Shortcuts open Respite’s flows; they don’t replace Family Controls shields. Use both together if you want.")
        }
    }

    // MARK: - Monitored apps

    private var monitoredAppsSection: some View {
        Section {
            pickerTriggerRow(
                title: "Apps to monitor",
                subtitle: selectionSummary(selection),
                icon: "chart.bar.doc.horizontal",
                tint: .blue
            ) {
                showMonitoredPicker = true
            }
        } header: {
            Text("Daily limit")
        } footer: {
            Text("After \(pauseMinutes) minutes of use in a day, Respite shows a pause shield. The same app can appear here and in Intent gate — Respite merges them into one shield so iOS does not glitch.")
        }
    }

    // MARK: - Intent gate

    private var intentGateSection: some View {
        Section {
            pickerTriggerRow(
                title: "Apps that need a check-in",
                subtitle: selectionSummary(tiktokSelection),
                icon: "hand.raised.fill",
                tint: .orange
            ) {
                showIntentGatePicker = true
            }

            Stepper(
                "Check-in again after \(tiktokIdleMinutes) min without use",
                value: $tiktokIdleMinutes,
                in: 5...180,
                step: 5
            )
            .onChange(of: tiktokIdleMinutes) { _, newValue in
                settings.tiktokIdleMinutesAfterExit = newValue
                Task { @MainActor in
                    ShieldManager.shared.reapplyAllShields()
                }
            }
        } header: {
            Text("Intent gate")
        } footer: {
            Text("After you complete a check-in, those apps stay open until there has been no Screen Time usage for the time above (proxy for “left the app long enough”). Then the shield returns. Tokens merge with Daily limit in one shield.")
        }
    }

    // MARK: - Picker sheets (one FamilyActivityPicker at a time — avoids Form conflicts)

    private var monitoredPickerSheet: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Monitored apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            loadFromStore()
                            showMonitoredPicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            persistSelectionAndRestart(selection)
                            showMonitoredPicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var intentGatePickerSheet: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $tiktokSelection)
                .navigationTitle("Intent gate")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            loadFromStore()
                            showIntentGatePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            settings.saveTikTokSelection(tiktokSelection)
                            restartTikTokUsageMonitoring()
                            Task { @MainActor in
                                ShieldManager.shared.reapplyAllShields()
                            }
                            showIntentGatePicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Rows

    private func pickerTriggerRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("Choose")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func selectionSummary(_ s: FamilyActivitySelection) -> String {
        let apps = s.applicationTokens.count
        let cats = s.categoryTokens.count
        let web = s.webDomainTokens.count
        let total = apps + cats + web
        if total == 0 {
            return "Tap Choose to pick apps"
        }
        var parts: [String] = []
        if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
        if cats > 0 { parts.append(cats == 1 ? "1 category" : "\(cats) categories") }
        if web > 0 { parts.append(web == 1 ? "1 site" : "\(web) sites") }
        return parts.joined(separator: " · ")
    }

    private func loadFromStore() {
        if let stored = settings.loadSelection() {
            selection = stored
        }
        if let storedTikTok = settings.loadTikTokSelection() {
            tiktokSelection = storedTikTok
        }
        pauseMinutes = settings.pauseThresholdMinutes
        graceMinutes = settings.gracePeriodMinutes
        tiktokIdleMinutes = settings.tiktokIdleMinutesAfterExit
    }

    private func persistSelectionAndRestart(_ newValue: FamilyActivitySelection) {
        settings.saveSelection(newValue)
        restartMonitoring()
        Task { @MainActor in
            ShieldManager.shared.reapplyAllShields()
        }
    }

    private func restartMonitoring() {
        scheduleErrorMessage = nil
        do {
            try RegulationActivityScheduler.restartMonitoring(settings: settings)
        } catch {
            scheduleErrorMessage = error.localizedDescription
        }
    }

    private func restartTikTokUsageMonitoring() {
        scheduleErrorMessage = nil
        do {
            try RegulationActivityScheduler.restartTikTokUsageMonitoring(settings: settings)
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
