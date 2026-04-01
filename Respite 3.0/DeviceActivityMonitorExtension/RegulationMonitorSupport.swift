import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Mirrors main-app keys in `RegulationSettings` / `RegulationUserDefaultsKey`.
private enum MonitorKeys {
    static let suite = "group.com.stormforge.Respite-3-0"
    static let familySelectionData = "regulation.familySelectionData"
    static let isUnlocked = "regulation.isUnlocked"
    static let unlockExpiresAt = "regulation.unlockExpiresAt"
}

enum RegulationMonitorShield {
    private static let store = ManagedSettingsStore()

    private static func isInGraceWindow(_ defaults: UserDefaults) -> Bool {
        guard defaults.bool(forKey: MonitorKeys.isUnlocked) else { return false }
        if let exp = defaults.object(forKey: MonitorKeys.unlockExpiresAt) as? Date {
            return Date() < exp
        }
        return true
    }

    static func applyShieldIfLocked() {
        let defaults = UserDefaults(suiteName: MonitorKeys.suite) ?? .standard
        if isInGraceWindow(defaults) { return }
        applyShieldFromDefaults(defaults)
    }

    /// Usage threshold reached — still skip if grace unlock is active.
    static func applyShieldAfterThreshold() {
        let defaults = UserDefaults(suiteName: MonitorKeys.suite) ?? .standard
        if isInGraceWindow(defaults) { return }
        applyShieldFromDefaults(defaults)
    }

    static func applyShieldFromDefaults(_ defaults: UserDefaults = UserDefaults(suiteName: MonitorKeys.suite) ?? .standard) {
        guard let data = defaults.data(forKey: MonitorKeys.familySelectionData),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }
}
