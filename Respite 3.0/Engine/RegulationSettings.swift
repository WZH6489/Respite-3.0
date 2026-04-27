import Foundation
import DeviceActivity
import FamilyControls

enum RegulationAppGroup {
    static let id = "group.com.stormforge.Respite-3-0"
}

enum RegulationUserDefaultsKey {
    static let familySelectionData = "regulation.familySelectionData"
    static let isUnlocked = "regulation.isUnlocked"
    static let unlockExpiresAt = "regulation.unlockExpiresAt"
    static let pauseThresholdMinutes = "regulation.pauseThresholdMinutes"
    static let gracePeriodMinutes = "regulation.gracePeriodMinutes"
    static let streakGoalMinutes = "regulation.streakGoalMinutes"
    static let dailyLimitTriggered = "regulation.dailyLimitTriggered"
    // TikTok intent gate
    static let tiktokSelectionData = "regulation.tiktokSelectionData"
    static let tiktokIsUnlocked = "regulation.tiktokIsUnlocked"
    static let tiktokUnlockExpiresAt = "regulation.tiktokUnlockExpiresAt"
    /// Last time Screen Time reported usage for intent-gate apps (proxy for “still in session”).
    static let lastTikTokUsageAt = "regulation.lastTikTokUsageAt"
    /// When the user last completed a check-in and TikTok was unshielded (before first usage sample).
    static let lastTikTokUnlockAt = "regulation.lastTikTokUnlockAt"
    /// Minutes with no TikTok usage before check-in is required again (default 30).
    static let tiktokIdleMinutesAfterExit = "regulation.tiktokIdleMinutesAfterExit"
}

/// Names shared with `DeviceActivityMonitorExtension` (must match exactly).
enum RegulationActivity {
    static let name = DeviceActivityName("com.stormforge.Respite.regulation")
    static let usageThreshold = DeviceActivityEvent.Name("usageThreshold")
}

/// Tracks TikTok / intent-gate usage so we can re-shield after idle (proxy for “exited long enough ago”).
enum TikTokUsageActivity {
    static let name = DeviceActivityName("com.stormforge.Respite.tiktokUsage")
    static let usageThreshold = DeviceActivityEvent.Name("tiktokUsageThreshold")
}

final class RegulationSettingsStore {
    private let defaults: UserDefaults

    init(suiteName: String = RegulationAppGroup.id) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    var pauseThresholdMinutes: Int {
        get {
            let v = defaults.integer(forKey: RegulationUserDefaultsKey.pauseThresholdMinutes)
            return v > 0 ? v : 15
        }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.pauseThresholdMinutes) }
    }

    var gracePeriodMinutes: Int {
        get {
            let v = defaults.integer(forKey: RegulationUserDefaultsKey.gracePeriodMinutes)
            return v > 0 ? v : 5
        }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.gracePeriodMinutes) }
    }

    var streakGoalMinutes: Int {
        get {
            let v = defaults.integer(forKey: RegulationUserDefaultsKey.streakGoalMinutes)
            return v > 0 ? v : 30
        }
        set { defaults.set(max(1, newValue), forKey: RegulationUserDefaultsKey.streakGoalMinutes) }
    }

    var isUnlocked: Bool {
        get { defaults.bool(forKey: RegulationUserDefaultsKey.isUnlocked) }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.isUnlocked) }
    }

    var dailyLimitTriggered: Bool {
        get { defaults.bool(forKey: RegulationUserDefaultsKey.dailyLimitTriggered) }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.dailyLimitTriggered) }
    }

    var unlockExpiresAt: Date? {
        get { defaults.object(forKey: RegulationUserDefaultsKey.unlockExpiresAt) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: RegulationUserDefaultsKey.unlockExpiresAt)
            } else {
                defaults.removeObject(forKey: RegulationUserDefaultsKey.unlockExpiresAt)
            }
        }
    }

    func loadSelection() -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: RegulationUserDefaultsKey.familySelectionData) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func saveSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: RegulationUserDefaultsKey.familySelectionData)
        }
    }

    // MARK: - TikTok Intent Gate

    var tiktokIsUnlocked: Bool {
        get { defaults.bool(forKey: RegulationUserDefaultsKey.tiktokIsUnlocked) }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.tiktokIsUnlocked) }
    }

    var tiktokUnlockExpiresAt: Date? {
        get { defaults.object(forKey: RegulationUserDefaultsKey.tiktokUnlockExpiresAt) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: RegulationUserDefaultsKey.tiktokUnlockExpiresAt)
            } else {
                defaults.removeObject(forKey: RegulationUserDefaultsKey.tiktokUnlockExpiresAt)
            }
        }
    }

    var lastTikTokUsageAt: Date? {
        get { defaults.object(forKey: RegulationUserDefaultsKey.lastTikTokUsageAt) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: RegulationUserDefaultsKey.lastTikTokUsageAt)
            } else {
                defaults.removeObject(forKey: RegulationUserDefaultsKey.lastTikTokUsageAt)
            }
        }
    }

    var lastTikTokUnlockAt: Date? {
        get { defaults.object(forKey: RegulationUserDefaultsKey.lastTikTokUnlockAt) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: RegulationUserDefaultsKey.lastTikTokUnlockAt)
            } else {
                defaults.removeObject(forKey: RegulationUserDefaultsKey.lastTikTokUnlockAt)
            }
        }
    }

    var tiktokIdleMinutesAfterExit: Int {
        get {
            let v = defaults.integer(forKey: RegulationUserDefaultsKey.tiktokIdleMinutesAfterExit)
            return v > 0 ? v : 30
        }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.tiktokIdleMinutesAfterExit) }
    }

    func loadTikTokSelection() -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: RegulationUserDefaultsKey.tiktokSelectionData) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func saveTikTokSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: RegulationUserDefaultsKey.tiktokSelectionData)
        }
    }

}
