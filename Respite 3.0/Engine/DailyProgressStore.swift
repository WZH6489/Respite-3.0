import Foundation

enum DailyProgressStore {
    private static let dayStampKey = "dashboard.dailyProgress.dayStamp"
    private static let minutesSavedKey = "dashboard.dailyProgress.minutesSaved"
    private static let historyKey = "dashboard.dailyProgress.history"

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
        persistTodayToHistory(minutes: updated)
    }

    static func averageDailyMinutes(days: Int = 7) -> Double {
        let cappedDays = max(1, days)
        let today = Calendar.current.startOfDay(for: .now)
        var total = 0
        for dayOffset in 0..<cappedDays {
            guard let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            total += minutesSaved(on: date)
        }
        return Double(total) / Double(cappedDays)
    }

    static func projectedYearMinutes() -> Int {
        Int((averageDailyMinutes(days: 14) * 365.0).rounded())
    }

    static func projectedLifetimeMinutes(lifespanYears: Int = 80) -> Int {
        Int((averageDailyMinutes(days: 30) * Double(max(1, lifespanYears)) * 365.0).rounded())
    }

    static func weeklyTrendDeltaMinutes() -> Int {
        let recent = averageDailyMinutes(days: 3)
        let baseline = averageDailyMinutes(days: 10)
        return Int((recent - baseline).rounded())
    }

    static func minutesSaved(on date: Date) -> Int {
        resetIfNeeded()
        let dayKey = key(for: date)
        if dayKey == key(for: .now) {
            return defaults.integer(forKey: minutesSavedKey)
        }
        return history()[dayKey] ?? 0
    }

    static func recentHistory(days: Int = 14) -> [(date: Date, minutes: Int)] {
        let cappedDays = max(1, days)
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<cappedDays).compactMap { dayOffset in
            guard let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
            return (date: date, minutes: minutesSaved(on: date))
        }
        .reversed()
    }

    static func currentStreak(goalMinutes: Int) -> Int {
        let goal = max(1, goalMinutes)
        resetIfNeeded()

        var streak = 0
        var cursor = Calendar.current.startOfDay(for: .now)

        while minutesSaved(on: cursor) >= goal {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    static func hasMetGoalToday(goalMinutes: Int) -> Bool {
        minutesSavedToday() >= max(1, goalMinutes)
    }

    private static func resetIfNeeded(referenceDate: Date = .now) {
        let today = Calendar.current.startOfDay(for: referenceDate)
        let savedDay = defaults.object(forKey: dayStampKey) as? Date
        let savedDayStart = savedDay.map { Calendar.current.startOfDay(for: $0) }
        guard savedDayStart != today else { return }

        if let savedDay, savedDayStart != nil {
            let oldKey = key(for: savedDay)
            var map = history()
            map[oldKey] = defaults.integer(forKey: minutesSavedKey)
            saveHistory(map)
        }

        defaults.set(today, forKey: dayStampKey)
        defaults.set(0, forKey: minutesSavedKey)
    }

    private static func persistTodayToHistory(minutes: Int) {
        var map = history()
        map[key(for: .now)] = minutes
        saveHistory(map)
    }

    private static func history() -> [String: Int] {
        defaults.dictionary(forKey: historyKey) as? [String: Int] ?? [:]
    }

    private static func saveHistory(_ value: [String: Int]) {
        defaults.set(value, forKey: historyKey)
    }

    private static func key(for date: Date) -> String {
        let start = Calendar.current.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: start)
    }
}
