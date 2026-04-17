import AppIntents
import Foundation

/// Runs the in-app five-breath gate and completes when the user taps Continue (continuable in Shortcuts).
/// Uses `IntentModes.foreground(.dynamic)` — the iOS 26 replacement for deprecated `ForegroundContinuableIntent` / `openAppWhenRun` continuations.
@available(iOS 26.0, *)
struct RunTikTokBreathingGateIntent: AppIntent {
    static var title: LocalizedStringResource = "Calm breathing before TikTok"
    static var description = IntentDescription(
        "Opens Respite for a short breathing exercise, then continues to TikTok when you’re done—similar idea to One Sec. Turn off “Open TikTok when done” if you prefer a separate Shortcuts action that opens tiktok:// instead. Respite arms handoff suppress on Continue so TikTok’s open does not loop the automation."
    )

    /// When `false`, add a separate Open URL `tiktok://` step in Shortcuts. When `true`, Respite opens TikTok after the gate (single-step).
    @Parameter(title: "Open TikTok when done", default: false)
    var openTikTokWhenDone: Bool

    /// Background first so `perform` can read handoff suppress before any foreground transition; dynamic foreground for the breathing UI.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @MainActor
    func perform() async throws -> some IntentResult {
        if RegulationSettingsStore().isTikTokHandoffSuppressActive {
            return .result()
        }
        // Match dynamic-foreground App Intent pattern: explicit handoff with alwaysConfirm false (see Apple / community notes for [.background, .foreground(.dynamic)]).
        do {
            try await continueInForeground(alwaysConfirm: false)
        } catch {
            // Foreground transition not available or declined — still try to present the gate from current context.
        }
        await RespiteShortcutCoordinator.shared.runBreathingGateForShortcut(openTikTokWhenDone: openTikTokWhenDone)
        return .result()
    }
}

/// Shortcuts / Personal Automation can branch on this so “When TikTok opens” does not reopen Respite right after a handoff from Respite.
@available(iOS 26.0, *)
struct IsTikTokHandoffSuppressActiveIntent: AppIntent {
    static var title: LocalizedStringResource = "Is TikTok handoff suppress active"
    static var description = IntentDescription(
        "Returns true for about two minutes after Respite opens TikTok. In a Personal Automation, use If with this action: if true, do nothing; otherwise open your regulate:// URL."
    )

    /// Replaces deprecated `openAppWhenRun = false` (iOS 26): never bring Respite forward for this read-only intent.
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: RegulationSettingsStore().isTikTokHandoffSuppressActive)
    }
}

@available(iOS 26.0, *)
struct RespiteAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: RunTikTokBreathingGateIntent(openTikTokWhenDone: true),
                phrases: [
                    "Calm breathing then TikTok in \(.applicationName)",
                    "Pause TikTok with breathing in \(.applicationName)",
                ],
                shortTitle: "Calm breathing → TikTok",
                systemImageName: "wind"
            ),
            AppShortcut(
                intent: RunTikTokBreathingGateIntent(),
                phrases: [
                    "TikTok breathing in \(.applicationName)",
                    "Run TikTok breathing gate in \(.applicationName)",
                ],
                shortTitle: "TikTok breathing gate",
                systemImageName: "wind"
            ),
            AppShortcut(
                intent: IsTikTokHandoffSuppressActiveIntent(),
                phrases: [
                    "TikTok handoff suppress in \(.applicationName)",
                ],
                shortTitle: "TikTok handoff suppress?",
                systemImageName: "arrow.triangle.2.circlepath"
            ),
        ]
    }
}
