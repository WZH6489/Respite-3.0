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
    static let deepLinkBreathworkQuietUntil = "regulation.deepLink.breathworkQuietUntil"
    static let deepLinkPuzzleQuietUntil = "regulation.deepLink.puzzleQuietUntil"
    static let deepLinkTikTokBreathQuietUntil = "regulation.deepLink.tiktokBreathQuietUntil"
    static let idleBreathingThresholdMinutes = "regulation.idleBreathingThresholdMinutes"
    static let lastRespiteBackgroundAt = "regulation.lastRespiteBackgroundAt"
    static let postGraceRandomIncludeBreathing = "regulation.postGraceRandomIncludeBreathing"
    static let postGraceRandomIncludePuzzle = "regulation.postGraceRandomIncludePuzzle"
    static let tiktokHandoffSuppressUntil = "regulation.tiktokHandoffSuppressUntil"
}

/// Names shared with `DeviceActivityMonitorExtension` (must match exactly).
enum RegulationActivity {
    static let name = DeviceActivityName("com.stormforge.Respite.regulation")
    static let usageThreshold = DeviceActivityEvent.Name("usageThreshold")
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

    var isUnlocked: Bool {
        get { defaults.bool(forKey: RegulationUserDefaultsKey.isUnlocked) }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.isUnlocked) }
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

    /// True while a regulation challenge has granted a temporary unlock and grace has not expired.
    var isGraceUnlockActive: Bool {
        guard isUnlocked else { return false }
        guard let exp = unlockExpiresAt else { return false }
        return Date() < exp
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

    /// Minutes away from Respite before the unified breathing gate appears on return. `0` disables.
    var idleBreathingThresholdMinutes: Int {
        get {
            if defaults.object(forKey: RegulationUserDefaultsKey.idleBreathingThresholdMinutes) == nil { return 30 }
            return defaults.integer(forKey: RegulationUserDefaultsKey.idleBreathingThresholdMinutes)
        }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.idleBreathingThresholdMinutes) }
    }

    var lastRespiteBackgroundAt: Date? {
        get { defaults.object(forKey: RegulationUserDefaultsKey.lastRespiteBackgroundAt) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: RegulationUserDefaultsKey.lastRespiteBackgroundAt)
            } else {
                defaults.removeObject(forKey: RegulationUserDefaultsKey.lastRespiteBackgroundAt)
            }
        }
    }

    var postGraceRandomIncludeBreathing: Bool {
        get {
            if defaults.object(forKey: RegulationUserDefaultsKey.postGraceRandomIncludeBreathing) == nil { return true }
            return defaults.bool(forKey: RegulationUserDefaultsKey.postGraceRandomIncludeBreathing)
        }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.postGraceRandomIncludeBreathing) }
    }

    var postGraceRandomIncludePuzzle: Bool {
        get {
            if defaults.object(forKey: RegulationUserDefaultsKey.postGraceRandomIncludePuzzle) == nil { return true }
            return defaults.bool(forKey: RegulationUserDefaultsKey.postGraceRandomIncludePuzzle)
        }
        set { defaults.set(newValue, forKey: RegulationUserDefaultsKey.postGraceRandomIncludePuzzle) }
    }

    /// After Respite opens TikTok, automations should skip reopening Respite until this time.
    var tiktokHandoffSuppressUntil: Date? {
        get { defaults.object(forKey: RegulationUserDefaultsKey.tiktokHandoffSuppressUntil) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: RegulationUserDefaultsKey.tiktokHandoffSuppressUntil)
            } else {
                defaults.removeObject(forKey: RegulationUserDefaultsKey.tiktokHandoffSuppressUntil)
            }
        }
    }

    /// Call immediately before `UIApplication.shared.open(tiktok://)` from Respite (default 120s).
    func armTikTokHandoffSuppressWindow(duration: TimeInterval = 120) {
        tiktokHandoffSuppressUntil = Date().addingTimeInterval(duration)
    }

    /// `true` while a Respite-initiated TikTok handoff window is active (for Shortcuts If / deep link guards).
    var isTikTokHandoffSuppressActive: Bool {
        guard let until = tiktokHandoffSuppressUntil else { return false }
        return Date() < until
    }
}
