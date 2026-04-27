@preconcurrency import FamilyControls
import Foundation
@preconcurrency import ManagedSettings

/// Intent-gate matching for shield extensions (app group + defensive token/category checks).
/// All methods are nonisolated so they can be called from extension callbacks
/// without MainActor deadlocks.
enum IntentGateShieldMatching {
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

    nonisolated static func matchesActivityCategory(_ category: ActivityCategory) -> Bool {
        guard let selection = loadIntentGateSelection(),
              let categoryToken = category.token else { return false }
        if selection.categoryTokens.contains(categoryToken) { return true }
        for c in selection.categoryTokens where c == categoryToken { return true }
        return false
    }

    nonisolated static func matchesApplication(_ application: Application, category: ActivityCategory?) -> Bool {
        if let token = application.token, matchesApplicationToken(token) { return true }
        if let category, matchesActivityCategory(category) { return true }
        return false
    }

    nonisolated static func matchesWebDomainToken(_ token: WebDomainToken) -> Bool {
        guard let selection = loadIntentGateSelection() else { return false }
        if selection.webDomainTokens.contains(token) { return true }
        for t in selection.webDomainTokens where t == token { return true }
        return false
    }

    nonisolated static func matchesWebDomain(_ webDomain: WebDomain, category: ActivityCategory?) -> Bool {
        if let token = webDomain.token, matchesWebDomainToken(token) { return true }
        if let category, matchesActivityCategory(category) { return true }
        return false
    }
}
