import Foundation
import FamilyControls

struct SetupHealthSnapshot {
    let screenTimeAuthorized: Bool
    let hasDailyLimitTargets: Bool
    let hasIntentGateTargets: Bool
    let shortcutsPageOpened: Bool
    let antiRelapseEnabled: Bool
    let reflectionReminderConfigured: Bool

    var completedCount: Int {
        [
            screenTimeAuthorized,
            hasDailyLimitTargets,
            hasIntentGateTargets,
            shortcutsPageOpened,
            reflectionReminderConfigured
        ].filter { $0 }.count
    }

    var totalCount: Int { 5 }

    var score: Int {
        Int((Double(completedCount) / Double(totalCount) * 100.0).rounded())
    }

    var summary: String {
        switch score {
        case 90...100: return "Setup is fully healthy"
        case 70...89: return "Setup is solid"
        case 40...69: return "Setup is partially complete"
        default: return "Setup needs attention"
        }
    }
}

enum SetupHealthStore {
    static func snapshot() -> SetupHealthSnapshot {
        let defaults = UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
        let settings = RegulationSettingsStore()
        let auth = AuthorizationCenter.shared.authorizationStatus == .approved

        let daily = settings.loadSelection()
        let hasDaily = !(daily?.applicationTokens.isEmpty ?? true)
            || !(daily?.categoryTokens.isEmpty ?? true)
            || !(daily?.webDomainTokens.isEmpty ?? true)

        let gate = settings.loadTikTokSelection()
        let hasGate = !(gate?.applicationTokens.isEmpty ?? true)
            || !(gate?.categoryTokens.isEmpty ?? true)
            || !(gate?.webDomainTokens.isEmpty ?? true)

        let openedShortcuts = defaults.bool(forKey: "shortcuts.didOpenShortcutsPage")

        let mode = defaults.integer(forKey: "notifications.reflection.mode")
        let hasReminder: Bool
        if mode == 2 {
            let morningHour = defaults.integer(forKey: "notifications.reflection.morning.hour")
            let eveningHour = defaults.integer(forKey: "notifications.reflection.evening.hour")
            hasReminder = morningHour >= 0 && eveningHour >= 0
        } else {
            let hour = defaults.integer(forKey: "notifications.reflection.hour")
            hasReminder = hour >= 0
        }

        return SetupHealthSnapshot(
            screenTimeAuthorized: auth,
            hasDailyLimitTargets: hasDaily,
            hasIntentGateTargets: hasGate,
            shortcutsPageOpened: openedShortcuts,
            antiRelapseEnabled: RecoveryInsightsStore.antiRelapseEnabled(),
            reflectionReminderConfigured: hasReminder
        )
    }
}
