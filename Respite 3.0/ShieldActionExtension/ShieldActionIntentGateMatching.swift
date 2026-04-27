@preconcurrency import FamilyControls
import Foundation
@preconcurrency import ManagedSettings

/// Intent-gate token matching for Shield Action (duplicate of configuration logic; separate type name — main app syncs all `Respite 3.0` Swift files).
enum ShieldActionIntentGateMatching {
    nonisolated static func loadIntentGateSelection() -> FamilyActivitySelection? {
        guard let data = UserDefaults(suiteName: "group.com.stormforge.Respite-3-0")?
            .data(forKey: "regulation.tiktokSelectionData") else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    nonisolated static func matchesApplicationToken(_ token: ApplicationToken) -> Bool {
        guard let selection = loadIntentGateSelection() else { return false }
        if selection.applicationTokens.contains(token) { return true }
        for t in selection.applicationTokens where t == token { return true }
        return false
    }

    nonisolated static func matchesActivityCategory(_ category: ActivityCategoryToken) -> Bool {
        guard let selection = loadIntentGateSelection() else { return false }
        if selection.categoryTokens.contains(category) { return true }
        for c in selection.categoryTokens where c == category { return true }
        return false
    }

    nonisolated static func matchesWebDomain(_ webDomain: WebDomainToken) -> Bool {
        guard let selection = loadIntentGateSelection() else { return false }
        if selection.webDomainTokens.contains(webDomain) { return true }
        for w in selection.webDomainTokens where w == webDomain { return true }
        return false
    }
}
