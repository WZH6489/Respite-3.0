import Foundation

enum UserProfileType: String, CaseIterable {
    case student
    case professional
    case creator
    case reset

    var title: String {
        switch self {
        case .student: return "Student"
        case .professional: return "Professional"
        case .creator: return "Creator"
        case .reset: return "Reset"
        }
    }
}

enum UserProfileStore {
    private static let displayNameKey = "profile.displayName"
    private static let birthdayKey = "profile.birthday"
    private static let photoDataKey = "profile.photoData"
    private static let onboardingCompletedKey = "profile.onboardingCompleted"
    private static let lastBirthdayCelebratedYearKey = "profile.lastBirthdayCelebratedYear"
    private static let profileTypeKey = "profile.type"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
    }

    static func displayName() -> String {
        let trimmed = defaults.string(forKey: displayNameKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return "there"
    }

    static func setDisplayName(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed.isEmpty ? "there" : trimmed, forKey: displayNameKey)
    }

    static func birthday() -> Date? {
        defaults.object(forKey: birthdayKey) as? Date
    }

    static func setBirthday(_ value: Date?) {
        if let value {
            defaults.set(value, forKey: birthdayKey)
        } else {
            defaults.removeObject(forKey: birthdayKey)
        }
    }

    static func photoData() -> Data? {
        defaults.data(forKey: photoDataKey)
    }

    static func setPhotoData(_ data: Data?) {
        if let data {
            defaults.set(data, forKey: photoDataKey)
        } else {
            defaults.removeObject(forKey: photoDataKey)
        }
    }

    static func hasCompletedOnboarding() -> Bool {
        defaults.bool(forKey: onboardingCompletedKey)
    }

    static func markOnboardingCompleted() {
        defaults.set(true, forKey: onboardingCompletedKey)
    }

    /// Year (e.g. 2026) in which the user has most recently been shown the
    /// birthday confetti celebration. `nil` if it has never fired. Used by
    /// `DashboardView` to ensure the animation only runs once per birthday.
    static func lastBirthdayCelebratedYear() -> Int? {
        let stored = defaults.integer(forKey: lastBirthdayCelebratedYearKey)
        return stored == 0 ? nil : stored
    }

    static func setLastBirthdayCelebratedYear(_ year: Int) {
        defaults.set(year, forKey: lastBirthdayCelebratedYearKey)
    }

    /// Clears the "already celebrated this year" flag so the next Dashboard
    /// appearance will trigger the confetti again. Used by the Settings dev
    /// helper to replay the celebration on demand.
    static func clearLastBirthdayCelebratedYear() {
        defaults.removeObject(forKey: lastBirthdayCelebratedYearKey)
    }

    static func profileType() -> UserProfileType {
        guard let raw = defaults.string(forKey: profileTypeKey),
              let type = UserProfileType(rawValue: raw) else {
            return .student
        }
        return type
    }

    static func setProfileType(_ type: UserProfileType) {
        defaults.set(type.rawValue, forKey: profileTypeKey)
    }

    static func applyDefaults(for type: UserProfileType) {
        let settings = RegulationSettingsStore()
        switch type {
        case .student:
            settings.streakGoalMinutes = 35
            ReflectionStore.setPromptsPerDay(2)
        case .professional:
            settings.streakGoalMinutes = 45
            ReflectionStore.setPromptsPerDay(1)
        case .creator:
            settings.streakGoalMinutes = 40
            ReflectionStore.setPromptsPerDay(2)
        case .reset:
            settings.streakGoalMinutes = 20
            ReflectionStore.setPromptsPerDay(1)
        }
    }
}
