import DeviceActivity
import FamilyControls
import SwiftUI

struct SettingsView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var pauseMinutes = 15
    @State private var graceMinutes = 5
    @State private var idleBreathingMinutes = 30
    @State private var pauseMinutesField = "15"
    @State private var graceMinutesField = "5"
    @State private var idleBreathingField = "30"
    @State private var postGraceIncludeBreathing = true
    @State private var postGraceIncludePuzzle = true
    @FocusState private var focusedTimingField: TimingField?
    @State private var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var scheduleErrorMessage: String?
    @State private var showTikTokShortcutsSetup = false

    private let settings = RegulationSettingsStore()

    private enum TimingField: Hashable {
        case pauseMinutes
        case graceMinutes
        case idleBreathingMinutes
    }

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

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pause after daily use")
                            .font(.subheadline.weight(.semibold))
                        Text("Minutes of monitored app use per day before the shield can appear.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Slider(
                            value: Binding(
                                get: { Double(pauseMinutes) },
                                set: { updatePauseMinutes(Int($0.rounded())) }
                            ),
                            in: 5...120,
                            step: 1
                        )
                        .disabled(authorizationStatus != .approved)

                        HStack(alignment: .firstTextBaseline) {
                            Text("Exact minutes")
                                .font(.subheadline)
                            Spacer()
                            TextField("5–120", text: $pauseMinutesField)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 72)
                                .focused($focusedTimingField, equals: .pauseMinutes)
                                .disabled(authorizationStatus != .approved)
                                .onSubmit { commitPauseMinutesField() }
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Grace period after a challenge")
                            .font(.subheadline.weight(.semibold))
                        Text("How long monitored apps stay unlocked after you complete a regulation flow.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Slider(
                            value: Binding(
                                get: { Double(graceMinutes) },
                                set: { updateGraceMinutes(Int($0.rounded())) }
                            ),
                            in: 1...60,
                            step: 1
                        )

                        HStack(alignment: .firstTextBaseline) {
                            Text("Exact minutes")
                                .font(.subheadline)
                            Spacer()
                            TextField("1–60", text: $graceMinutesField)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 72)
                                .focused($focusedTimingField, equals: .graceMinutes)
                                .onSubmit { commitGraceMinutesField() }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Timing")
                } footer: {
                    Text("Adjust with the slider or type a number, then tap Done on the keyboard. Pause: 5–120 min. Grace: 1–60 min.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Breathing after time away")
                            .font(.subheadline.weight(.semibold))
                        Text("When you return to Respite after this many minutes in the background, you’ll see the same five-breath gate. Set to 0 to turn off.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Slider(
                            value: Binding(
                                get: { Double(idleBreathingMinutes) },
                                set: { updateIdleBreathingMinutes(Int($0.rounded())) }
                            ),
                            in: 0...180,
                            step: 5
                        )

                        HStack(alignment: .firstTextBaseline) {
                            Text("Minutes (0 = off)")
                                .font(.subheadline)
                            Spacer()
                            TextField("0–180", text: $idleBreathingField)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 72)
                                .focused($focusedTimingField, equals: .idleBreathingMinutes)
                                .onSubmit { commitIdleBreathingField() }
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle("Include breathing after grace ends", isOn: Binding(
                        get: { postGraceIncludeBreathing },
                        set: { v in
                            postGraceIncludeBreathing = v
                            settings.postGraceRandomIncludeBreathing = v
                        }
                    ))
                    Toggle("Include puzzle after grace ends", isOn: Binding(
                        get: { postGraceIncludePuzzle },
                        set: { v in
                            postGraceIncludePuzzle = v
                            settings.postGraceRandomIncludePuzzle = v
                        }
                    ))
                } header: {
                    Text("Breathing gate")
                } footer: {
                    Text("When your grace period ends while Respite is open, one random option you enabled above may appear. The Screen Time shield still offers puzzle or breathing; both use the same five-breath flow for breathwork.")
                        .font(.caption)
                }

                Section {
                    Button {
                        showTikTokShortcutsSetup = true
                    } label: {
                        Label("Set up TikTok calm (Shortcuts)", systemImage: "link.circle")
                    }

                    if RespiteTikTokShortcutSetup.hasPrebuiltShareLink {
                        Text("Recommended: tap the button above and choose “Add pre-built automation” to add the template in one step (you’ll still confirm in Shortcuts—iOS requires it).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Recommended: tap the button above for steps. When we ship an iCloud link in the app, you’ll be able to add the automation without building each action by hand.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("TikTok automation (Shortcuts)")
                } footer: {
                    Text("Manual options (two-step, legacy If + regulate://) are inside the setup sheet under “Manual setup.”")
                        .font(.caption)
                }

                if let scheduleErrorMessage {
                    Section {
                        Text(scheduleErrorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text(
                        "When a monitored app hits your daily limit, iOS shows Respite’s pause screen. "
                        + "Choose puzzle or breathing there to open this app, complete the flow, then enjoy your grace period. "
                        + "That path works like other Screen Time–based focus apps—no Shortcuts automation required. "
                        + "If you use Shortcuts (for example when TikTok opens), you can turn off Notify When Run and each action’s Show When Run. If both are already off and a brief “Opening …” style UI still appears, that comes from iOS for App Intent handoff—not something Respite or Shortcuts settings can remove. "
                        + "and note that Respite ignores repeat regulate:// URLs while your grace unlock is active."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("How blocking works")
                }
            }
            .navigationTitle("Settings")
            .task {
                loadFromStore()
            }
            .onReceive(AuthorizationCenter.shared.$authorizationStatus) { authorizationStatus = $0 }
            .onChange(of: focusedTimingField) { oldField, newField in
                if oldField == .pauseMinutes {
                    commitPauseMinutesField()
                }
                if oldField == .graceMinutes {
                    commitGraceMinutesField()
                }
                if oldField == .idleBreathingMinutes {
                    commitIdleBreathingField()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedTimingField = nil
                    }
                }
            }
            .sheet(isPresented: $showTikTokShortcutsSetup) {
                TikTokShortcutsSetupSheet()
            }
        }
    }

    private func loadFromStore() {
        if let stored = settings.loadSelection() {
            selection = stored
        }
        pauseMinutes = settings.pauseThresholdMinutes
        graceMinutes = settings.gracePeriodMinutes
        idleBreathingMinutes = settings.idleBreathingThresholdMinutes
        pauseMinutesField = String(pauseMinutes)
        graceMinutesField = String(graceMinutes)
        idleBreathingField = String(idleBreathingMinutes)
        postGraceIncludeBreathing = settings.postGraceRandomIncludeBreathing
        postGraceIncludePuzzle = settings.postGraceRandomIncludePuzzle
    }

    private func updatePauseMinutes(_ value: Int) {
        let clamped = min(max(value, 5), 120)
        pauseMinutes = clamped
        if focusedTimingField != .pauseMinutes {
            pauseMinutesField = String(clamped)
        }
        settings.pauseThresholdMinutes = clamped
        restartMonitoring()
    }

    private func updateGraceMinutes(_ value: Int) {
        let clamped = min(max(value, 1), 60)
        graceMinutes = clamped
        if focusedTimingField != .graceMinutes {
            graceMinutesField = String(clamped)
        }
        settings.gracePeriodMinutes = clamped
    }

    private func updateIdleBreathingMinutes(_ value: Int) {
        let clamped = min(max(value, 0), 180)
        idleBreathingMinutes = clamped
        if focusedTimingField != .idleBreathingMinutes {
            idleBreathingField = String(clamped)
        }
        settings.idleBreathingThresholdMinutes = clamped
    }

    private func commitIdleBreathingField() {
        let raw = idleBreathingField.filter(\.isNumber)
        guard let parsed = Int(raw), !raw.isEmpty else {
            idleBreathingField = String(idleBreathingMinutes)
            return
        }
        updateIdleBreathingMinutes(parsed)
        idleBreathingField = String(idleBreathingMinutes)
    }

    private func commitPauseMinutesField() {
        let raw = pauseMinutesField.filter(\.isNumber)
        guard let parsed = Int(raw), !raw.isEmpty else {
            pauseMinutesField = String(pauseMinutes)
            return
        }
        updatePauseMinutes(parsed)
        pauseMinutesField = String(pauseMinutes)
    }

    private func commitGraceMinutesField() {
        let raw = graceMinutesField.filter(\.isNumber)
        guard let parsed = Int(raw), !raw.isEmpty else {
            graceMinutesField = String(graceMinutes)
            return
        }
        updateGraceMinutes(parsed)
        graceMinutesField = String(graceMinutes)
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
