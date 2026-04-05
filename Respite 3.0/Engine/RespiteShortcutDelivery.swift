import Foundation

extension Notification.Name {
    /// Posted when an App Shortcut or pending URL should open a `regulate://` flow.
    static let respiteOpenRegulateURL = Notification.Name("RespiteOpenRegulateURL")
}

/// Delivers `regulate://` URLs from App Intents (cold launch uses UserDefaults; warm launch uses notification).
enum RespiteShortcutDelivery {
    private static let pendingKey = "respite.pendingRegulateURLString"

    private static var suite: UserDefaults {
        UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
    }

    static func enqueue(_ url: URL) {
        suite.set(url.absoluteString, forKey: pendingKey)
    }

    /// Cold launch / scene activation: deliver if a shortcut left a pending URL.
    static func consumePending(into interventions: InterventionManager) {
        guard let s = suite.string(forKey: pendingKey), let url = URL(string: s) else { return }
        suite.removeObject(forKey: pendingKey)
        RegulationURLHandler.handle(url, interventions: interventions)
    }

    /// Warm launch: only handle if pending matches (avoids duplicate after `consumePending`).
    static func handleNotificationURL(_ url: URL, interventions: InterventionManager) {
        guard suite.string(forKey: pendingKey) == url.absoluteString else { return }
        suite.removeObject(forKey: pendingKey)
        RegulationURLHandler.handle(url, interventions: interventions)
    }

    /// Avoid double-handling when `onOpenURL` also receives the same URL.
    static func clearPendingIfMatches(_ url: URL) {
        guard let s = suite.string(forKey: pendingKey), s == url.absoluteString else { return }
        suite.removeObject(forKey: pendingKey)
    }
}
