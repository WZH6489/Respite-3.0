import Foundation

/// Idle-based re-shield for intent-gate apps: after check-in, TikTok stays unshielded until
/// there has been no reported usage for `tiktokIdleMinutesAfterExit` (proxy for “exited long enough ago”).
/// Screen Time does not expose “user left the app”; we use last usage timestamps from Device Activity.
enum TikTokIdleLogic {
    /// Whether TikTok tokens should be removed from the shield set (user may open without check-in).
    static func shouldTikTokStayUnshielded(settings: RegulationSettingsStore) -> Bool {
        guard settings.tiktokIsUnlocked else { return false }

        // Legacy: fixed grace window from older builds
        if let exp = settings.tiktokUnlockExpiresAt {
            return Date() < exp
        }

        return !idleExceeded(settings: settings)
    }

    /// True when user must check in again (idle exceeded or legacy expiry passed).
    static func idleExceeded(settings: RegulationSettingsStore) -> Bool {
        let idleSec = TimeInterval(settings.tiktokIdleMinutesAfterExit * 60)
        let now = Date()
        if let lastUsage = settings.lastTikTokUsageAt {
            return now.timeIntervalSince(lastUsage) >= idleSec
        }
        if let unlockAt = settings.lastTikTokUnlockAt {
            return now.timeIntervalSince(unlockAt) >= idleSec
        }
        return true
    }

    /// Clears TikTok unlock when idle or legacy expiry demands it. Returns true if state changed.
    @discardableResult
    static func clearTikTokUnlockIfNeeded(settings: RegulationSettingsStore) -> Bool {
        guard settings.tiktokIsUnlocked else { return false }

        if let exp = settings.tiktokUnlockExpiresAt {
            if Date() < exp { return false }
            clearTikTokUnlockState(settings: settings)
            return true
        }

        guard idleExceeded(settings: settings) else { return false }
        clearTikTokUnlockState(settings: settings)
        return true
    }

    static func clearTikTokUnlockState(settings: RegulationSettingsStore) {
        settings.tiktokIsUnlocked = false
        settings.tiktokUnlockExpiresAt = nil
        settings.lastTikTokUsageAt = nil
        settings.lastTikTokUnlockAt = nil
    }
}
