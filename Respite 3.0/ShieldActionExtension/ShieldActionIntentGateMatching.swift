@preconcurrency import FamilyControls
import Foundation
@preconcurrency import ManagedSettings

/// Intent-gate token matching for Shield Action (duplicate of configuration logic; separate type name — main app syncs all `Respite 3.0` Swift files).
enum ShieldActionIntentGateMatching {
    nonisolated static func matchesApplicationToken(_ token: ApplicationToken) -> Bool {
        guard let data = UserDefaults(suiteName: "group.com.stormforge.Respite-3-0")?
                .data(forKey: "regulation.tiktokSelectionData"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return false }
        if selection.applicationTokens.contains(token) { return true }
        for t in selection.applicationTokens where t == token { return true }
        return false
    }
}
