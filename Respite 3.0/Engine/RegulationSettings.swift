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

    func loadSelection() -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: RegulationUserDefaultsKey.familySelectionData) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func saveSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: RegulationUserDefaultsKey.familySelectionData)
        }
    }
}
