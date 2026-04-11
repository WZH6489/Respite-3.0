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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    accessCard

                    if authorizationStatus == .approved {
                        monitoredAppsCard
                        intentGateCard
                    }

                    timingCard
                    shortcutsCard

                    if let scheduleErrorMessage {
                        errorCard(scheduleErrorMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(RespiteTheme.appBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Adjust your boundaries")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(RespiteTheme.textPrimary)
            Text("Simple controls for a calmer daily flow.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)
        }
    }

    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Access")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)

            switch authorizationStatus {
            case .approved:
                Label("Screen Time access is on", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(RespiteTheme.pine)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

            case .notDetermined:
                Text("Approve Screen Time access to choose apps and use shields.")
                    .foregroundStyle(RespiteTheme.textSecondary)
                actionButton(title: "Request authorization") {
                    Task { await requestAuthorization() }
                }

            default:
                Text("Family Controls must be approved. Check Screen Time in Settings.")
                    .foregroundStyle(RespiteTheme.textSecondary)
                actionButton(title: "Try again") {
                    Task { await requestAuthorization() }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var monitoredAppsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily limit")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)

            pickerTriggerRow(
                title: "Apps to monitor",
                subtitle: selectionSummary(selection),
                icon: "chart.bar.doc.horizontal",
                tint: RespiteTheme.duskBlue
            ) {
                showMonitoredPicker = true
            }

            Text("After \(pauseMinutes) minutes in a day, Respite shows a pause shield.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textMuted)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var intentGateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Intent gate")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)

            pickerTriggerRow(
                title: "Apps that need a check-in",
                subtitle: selectionSummary(tiktokSelection),
                icon: "hand.raised.fill",
                tint: RespiteTheme.berryAccent
            ) {
                showIntentGatePicker = true
            }

            stepperRow(
                title: "Check-in again after",
                valueText: "\(tiktokIdleMinutes) min",
                canDecrease: tiktokIdleMinutes > 5,
                canIncrease: tiktokIdleMinutes < 180,
                decrease: {
                    guard tiktokIdleMinutes > 5 else { return }
                    tiktokIdleMinutes -= 5
                    settings.tiktokIdleMinutesAfterExit = tiktokIdleMinutes
                    Task { @MainActor in ShieldManager.shared.reapplyAllShields() }
                },
                increase: {
                    guard tiktokIdleMinutes < 180 else { return }
                    tiktokIdleMinutes += 5
                    settings.tiktokIdleMinutesAfterExit = tiktokIdleMinutes
                    Task { @MainActor in ShieldManager.shared.reapplyAllShields() }
                }
            )

            Text("Apps stay open until no Screen Time usage is seen for that period.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textMuted)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timing")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)

            stepperRow(
                title: "Pause after",
                valueText: "\(pauseMinutes) min",
                canDecrease: pauseMinutes > 5 && authorizationStatus == .approved,
                canIncrease: pauseMinutes < 120 && authorizationStatus == .approved,
                decrease: {
                    guard authorizationStatus == .approved, pauseMinutes > 5 else { return }
                    pauseMinutes -= 5
                    settings.pauseThresholdMinutes = pauseMinutes
                    restartMonitoring()
                },
                increase: {
                    guard authorizationStatus == .approved, pauseMinutes < 120 else { return }
                    pauseMinutes += 5
                    settings.pauseThresholdMinutes = pauseMinutes
                    restartMonitoring()
                }
            )

            stepperRow(
                title: "Grace period",
                valueText: "\(graceMinutes) min",
                canDecrease: graceMinutes > 1,
                canIncrease: graceMinutes < 60,
                decrease: {
                    guard graceMinutes > 1 else { return }
                    graceMinutes -= 1
                    settings.gracePeriodMinutes = graceMinutes
                },
                increase: {
                    guard graceMinutes < 60 else { return }
                    graceMinutes += 1
                    settings.gracePeriodMinutes = graceMinutes
                }
            )
        }
        .padding(16)
        .background(cardBackground)
    }

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shortcuts")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)

            Text("Shortcuts → Automation → Personal Automation → App → Is Opened → choose app → Run Immediately → Add Action → search “Respite” → use “Activate Respite (check-in)”.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textSecondary)

            Text("Create one automation per app.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(RespiteTheme.textMuted)
        }
        .padding(16)
        .background(cardBackground)
    }

    private func errorCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.red)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
    }

    private func stepperRow(
        title: String,
        valueText: String,
        canDecrease: Bool,
        canIncrease: Bool,
        decrease: @escaping () -> Void,
        increase: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(RespiteTheme.textPrimary)
                Text(valueText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(RespiteTheme.textMuted)
            }
            Spacer()
            HStack(spacing: 0) {
                Button(action: decrease) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 38, height: 30)
                }
                .disabled(!canDecrease)

                Divider()
                    .frame(height: 18)

                Button(action: increase) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 38, height: 30)
                }
                .disabled(!canIncrease)
            }
            .foregroundStyle(RespiteTheme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(RespiteTheme.surfaceSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(RespiteTheme.border, lineWidth: 1)
                    )
            )
        }
        .padding(.vertical, 2)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(RespiteTheme.duskBlue)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(RespiteTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(RespiteTheme.border, lineWidth: 1)
            )
    }

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
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(RespiteTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(RespiteTheme.textMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("Choose")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(RespiteTheme.duskBlue)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RespiteTheme.textMuted)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

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
