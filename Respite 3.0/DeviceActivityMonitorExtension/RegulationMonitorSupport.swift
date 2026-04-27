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
    static let dailyLimitTriggered = "regulation.dailyLimitTriggered"
    static let tiktokSelectionData = "regulation.tiktokSelectionData"
    static let tiktokIsUnlocked = "regulation.tiktokIsUnlocked"
    static let tiktokUnlockExpiresAt = "regulation.tiktokUnlockExpiresAt"
    static let lastTikTokUsageAt = "regulation.lastTikTokUsageAt"
    static let lastTikTokUnlockAt = "regulation.lastTikTokUnlockAt"
    static let tiktokIdleMinutesAfterExit = "regulation.tiktokIdleMinutesAfterExit"
}

/// One `ManagedSettingsStore` only — same union logic as `ShieldManager.reapplyAllShields()` in the main app.
enum RegulationMonitorShield {
    private static let store = ManagedSettingsStore()

    private static func isInGraceWindow(_ defaults: UserDefaults) -> Bool {
        guard defaults.bool(forKey: MonitorKeys.isUnlocked) else { return false }
        if let exp = defaults.object(forKey: MonitorKeys.unlockExpiresAt) as? Date {
            return Date() < exp
        }
        return true
    }

    /// Mirrors `TikTokIdleLogic.shouldTikTokStayUnshielded` (extension target cannot import main app).
    private static func shouldTikTokStayUnshielded(_ defaults: UserDefaults) -> Bool {
        guard defaults.bool(forKey: MonitorKeys.tiktokIsUnlocked) else { return false }
        if let exp = defaults.object(forKey: MonitorKeys.tiktokUnlockExpiresAt) as? Date {
            return Date() < exp
        }
        let rawIdle = defaults.integer(forKey: MonitorKeys.tiktokIdleMinutesAfterExit)
        let effectiveIdle = rawIdle > 0 ? rawIdle : 30
        let idleSec = TimeInterval(effectiveIdle * 60)
        let now = Date()
        if let lastUsage = defaults.object(forKey: MonitorKeys.lastTikTokUsageAt) as? Date {
            return now.timeIntervalSince(lastUsage) < idleSec
        }
        if let unlockAt = defaults.object(forKey: MonitorKeys.lastTikTokUnlockAt) as? Date {
            return now.timeIntervalSince(unlockAt) < idleSec
        }
        return false
    }

    private static func clearTikTokUnlockIfIdleExceeded(_ defaults: UserDefaults) {
        guard defaults.bool(forKey: MonitorKeys.tiktokIsUnlocked) else { return }
        if let exp = defaults.object(forKey: MonitorKeys.tiktokUnlockExpiresAt) as? Date, Date() < exp {
            return
        }
        if let exp = defaults.object(forKey: MonitorKeys.tiktokUnlockExpiresAt) as? Date, Date() >= exp {
            defaults.set(false, forKey: MonitorKeys.tiktokIsUnlocked)
            defaults.removeObject(forKey: MonitorKeys.tiktokUnlockExpiresAt)
            defaults.removeObject(forKey: MonitorKeys.lastTikTokUsageAt)
            defaults.removeObject(forKey: MonitorKeys.lastTikTokUnlockAt)
            return
        }
        let rawIdle = defaults.integer(forKey: MonitorKeys.tiktokIdleMinutesAfterExit)
        let effectiveIdle = rawIdle > 0 ? rawIdle : 30
        let idleSec = TimeInterval(effectiveIdle * 60)
        let now = Date()
        var exceeded = false
        if let lastUsage = defaults.object(forKey: MonitorKeys.lastTikTokUsageAt) as? Date {
            exceeded = now.timeIntervalSince(lastUsage) >= idleSec
        } else if let unlockAt = defaults.object(forKey: MonitorKeys.lastTikTokUnlockAt) as? Date {
            exceeded = now.timeIntervalSince(unlockAt) >= idleSec
        } else {
            exceeded = true
        }
        guard exceeded else { return }
        defaults.set(false, forKey: MonitorKeys.tiktokIsUnlocked)
        defaults.removeObject(forKey: MonitorKeys.tiktokUnlockExpiresAt)
        defaults.removeObject(forKey: MonitorKeys.lastTikTokUsageAt)
        defaults.removeObject(forKey: MonitorKeys.lastTikTokUnlockAt)
    }

    static func recordTikTokUsageNow() {
        let defaults = UserDefaults(suiteName: MonitorKeys.suite) ?? .standard
        defaults.set(Date(), forKey: MonitorKeys.lastTikTokUsageAt)
    }

    /// Stops and restarts TikTok usage monitoring so the 1-minute threshold can fire again,
    /// giving us a heartbeat that keeps `lastTikTokUsageAt` fresh while the app is in use.
    static func restartTikTokUsageMonitoring() {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName("com.stormforge.Respite.tiktokUsage")
        center.stopMonitoring([activityName])

        let defaults = UserDefaults(suiteName: MonitorKeys.suite) ?? .standard
        guard defaults.bool(forKey: MonitorKeys.tiktokIsUnlocked) else { return }
        guard let data = defaults.data(forKey: MonitorKeys.tiktokSelectionData),
              let tiktok = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        let hasTargets =
            !tiktok.applicationTokens.isEmpty
            || !tiktok.categoryTokens.isEmpty
            || !tiktok.webDomainTokens.isEmpty
        guard hasTargets else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: tiktok.applicationTokens,
            categories: tiktok.categoryTokens,
            webDomains: tiktok.webDomainTokens,
            threshold: DateComponents(minute: 1)
        )
        try? center.startMonitoring(
            activityName,
            during: schedule,
            events: [DeviceActivityEvent.Name("tiktokUsageThreshold"): event]
        )
    }

    static func applyShieldIfLocked() {
        let defaults = UserDefaults(suiteName: MonitorKeys.suite) ?? .standard
        if isInGraceWindow(defaults) {
            clearStore()
            return
        }
        clearTikTokUnlockIfIdleExceeded(defaults)
        applyMergedShield(defaults)
    }

    static func resetDailyLimitForNewInterval() {
        let defaults = UserDefaults(suiteName: MonitorKeys.suite) ?? .standard
        defaults.set(false, forKey: MonitorKeys.dailyLimitTriggered)
        if !defaults.bool(forKey: MonitorKeys.tiktokIsUnlocked) {
            clearStore()
        }
    }

    static func applyShieldAfterThreshold() {
        let defaults = UserDefaults(suiteName: MonitorKeys.suite) ?? .standard
        defaults.set(true, forKey: MonitorKeys.dailyLimitTriggered)
        if isInGraceWindow(defaults) { return }
        clearTikTokUnlockIfIdleExceeded(defaults)
        applyMergedShield(defaults)
    }

    private static func clearStore() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    private static func applyMergedShield(_ defaults: UserDefaults) {
        let monitored: FamilyActivitySelection? = {
            guard let data = defaults.data(forKey: MonitorKeys.familySelectionData) else { return nil }
            return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        }()
        let tiktok: FamilyActivitySelection? = {
            guard let data = defaults.data(forKey: MonitorKeys.tiktokSelectionData) else { return nil }
            return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        }()

        let dailyLimitTriggered = defaults.bool(forKey: MonitorKeys.dailyLimitTriggered)

        let monitoredApps = dailyLimitTriggered ? (monitored?.applicationTokens ?? []) : []
        let intentApps = tiktok?.applicationTokens ?? []
        var apps = monitoredApps.union(intentApps)

        let monitoredCategories = dailyLimitTriggered ? (monitored?.categoryTokens ?? []) : []
        let intentCategories = tiktok?.categoryTokens ?? []
        var categories = monitoredCategories.union(intentCategories)

        let monitoredWeb = dailyLimitTriggered ? (monitored?.webDomainTokens ?? []) : []
        let intentWeb = tiktok?.webDomainTokens ?? []
        var webDomains = monitoredWeb.union(intentWeb)

        let hasCategories = !categories.isEmpty
        let hasWeb = !webDomains.isEmpty
        if apps.isEmpty && !hasCategories && !hasWeb {
            clearStore()
            return
        }

        if shouldTikTokStayUnshielded(defaults) {
            apps = apps.subtracting(intentApps)
            categories = categories.subtracting(intentCategories)
            webDomains = webDomains.subtracting(intentWeb)
        }

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
    }
}
