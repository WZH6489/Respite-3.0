import Foundation

enum DailyProgressStore {
    private static let dayStampKey = "dashboard.dailyProgress.dayStamp"
    private static let minutesSavedKey = "dashboard.dailyProgress.minutesSaved"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
    }

    static func minutesSavedToday() -> Int {
        resetIfNeeded()
        return defaults.integer(forKey: minutesSavedKey)
    }

    static func recordMinutesSaved(_ minutes: Int) {
        guard minutes > 0 else { return }
        resetIfNeeded()
        let updated = defaults.integer(forKey: minutesSavedKey) + minutes
        defaults.set(updated, forKey: minutesSavedKey)
    }

    private static func resetIfNeeded(referenceDate: Date = .now) {
        let today = Calendar.current.startOfDay(for: referenceDate)
        let savedDay = defaults.object(forKey: dayStampKey) as? Date
        let savedDayStart = savedDay.map { Calendar.current.startOfDay(for: $0) }
        guard savedDayStart != today else { return }
        defaults.set(today, forKey: dayStampKey)
        defaults.set(0, forKey: minutesSavedKey)
    }
}
