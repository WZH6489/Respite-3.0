import AppIntents
import UIKit

// MARK: - Shared helpers

private enum RespiteShortcutRunner {
    static func deliver(urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        RespiteShortcutDelivery.enqueue(url)
        await MainActor.run {
            NotificationCenter.default.post(name: .respiteOpenRegulateURL, object: url)
        }
    }

    static func isSessionActive() -> Bool {
        let settings = RegulationSettingsStore()
        return TikTokIdleLogic.shouldTikTokStayUnshielded(settings: settings)
    }
}

// MARK: - Intents (One Sec–style: use in Shortcuts → Automation → App → Is Opened)

struct RespiteActivateCheckInIntent: AppIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Activate Respite (check-in)"
    static var description = IntentDescription(
        "Opens Respite's check-in flow. Add this to Shortcuts → Automation → App → Is Opened for each app you want to pause before using."
    )
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if RespiteShortcutRunner.isSessionActive() {
            return .result(dialog: IntentDialog("Session active — enjoy your session."))
        }
        throw needsToContinueInForegroundError("Opening Respite check-in…") {
            let url = URL(string: "regulate://intent")!
            RespiteShortcutDelivery.enqueue(url)
            NotificationCenter.default.post(name: .respiteOpenRegulateURL, object: url)
        }
    }
}

struct RespiteShowMoreOptionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Respite — more options"
    static var description = IntentDescription("Opens puzzle, breathwork, or check-in for intent-gate apps.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await RespiteShortcutRunner.deliver(urlString: "regulate://tiktok/options")
        return .result(dialog: IntentDialog("Opening options."))
    }
}

struct RespiteIntentGatePuzzleIntent: AppIntent {
    static var title: LocalizedStringResource = "Respite — puzzle (intent gate)"
    static var description = IntentDescription("Starts the puzzle for apps in Intent gate (unlocks after success).")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await RespiteShortcutRunner.deliver(urlString: "regulate://tiktok/puzzle")
        return .result(dialog: IntentDialog("Opening puzzle."))
    }
}

struct RespiteIntentGateBreathworkIntent: AppIntent {
    static var title: LocalizedStringResource = "Respite — breathwork (intent gate)"
    static var description = IntentDescription("Starts breathwork for apps in Intent gate (unlocks after completion).")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await RespiteShortcutRunner.deliver(urlString: "regulate://tiktok/breathwork")
        return .result(dialog: IntentDialog("Opening breathwork."))
    }
}

struct RespiteDailyLimitPuzzleIntent: AppIntent {
    static var title: LocalizedStringResource = "Respite — puzzle (daily limit)"
    static var description = IntentDescription("Starts the puzzle for daily-limit regulation (not intent-gate unlock).")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await RespiteShortcutRunner.deliver(urlString: "regulate://puzzle")
        return .result(dialog: IntentDialog("Opening puzzle."))
    }
}

struct RespiteDailyLimitBreathworkIntent: AppIntent {
    static var title: LocalizedStringResource = "Respite — breathwork (daily limit)"
    static var description = IntentDescription("Starts breathwork for daily-limit regulation.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await RespiteShortcutRunner.deliver(urlString: "regulate://breathwork")
        return .result(dialog: IntentDialog("Opening breathwork."))
    }
}

// MARK: - Siri & Shortcuts gallery

struct RespiteShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RespiteActivateCheckInIntent(),
            phrases: [
                "Activate Respite in \(.applicationName)",
                "Start Respite check-in in \(.applicationName)",
                "Respite check-in in \(.applicationName)"
            ],
            shortTitle: "Activate Respite (check-in)",
            systemImageName: "hand.raised.fill"
        )
        AppShortcut(
            intent: RespiteShowMoreOptionsIntent(),
            phrases: [
                "Respite options in \(.applicationName)",
                "More Respite options in \(.applicationName)"
            ],
            shortTitle: "Respite — more options",
            systemImageName: "ellipsis.circle"
        )
        AppShortcut(
            intent: RespiteIntentGatePuzzleIntent(),
            phrases: ["Respite puzzle in \(.applicationName)"],
            shortTitle: "Intent gate puzzle",
            systemImageName: "puzzlepiece.extension"
        )
        AppShortcut(
            intent: RespiteIntentGateBreathworkIntent(),
            phrases: ["Respite breathwork in \(.applicationName)"],
            shortTitle: "Intent gate breathwork",
            systemImageName: "wind"
        )
        AppShortcut(
            intent: RespiteDailyLimitPuzzleIntent(),
            phrases: ["Respite daily puzzle in \(.applicationName)"],
            shortTitle: "Daily limit puzzle",
            systemImageName: "chart.bar.doc.horizontal"
        )
        AppShortcut(
            intent: RespiteDailyLimitBreathworkIntent(),
            phrases: ["Respite daily breathwork in \(.applicationName)"],
            shortTitle: "Daily limit breathwork",
            systemImageName: "lungs.fill"
        )
    }
}
