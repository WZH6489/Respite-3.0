import Foundation
import Combine

// MARK: - Persistence keys (keep in sync with ShieldActionExtension recording)

enum RespiteStatsUserDefaultsKey {
    static let dailyAggregatesJSON = "respite.stats.dailyAggregates"
    static let todayHourlyJSON = "respite.stats.todayHourly"
}

/// Per-calendar-day totals stored in the app group (local timezone).
struct RespiteDayAggregate: Codable, Equatable {
    var shieldInteractions: Int
    var regulationSessions: Int
    var tikTokIntentPasses: Int

    init(shieldInteractions: Int = 0, regulationSessions: Int = 0, tikTokIntentPasses: Int = 0) {
        self.shieldInteractions = shieldInteractions
        self.regulationSessions = regulationSessions
        self.tikTokIntentPasses = tikTokIntentPasses
    }
}

/// Hourly shield taps for the chart “today” view; resets when `dayKey` changes.
struct RespiteTodayHourly: Codable, Equatable {
    var dayKey: String
    /// Index 0 = midnight–1am, …, 23 = 11pm–midnight.
    var shieldCounts: [Int]
}

/// Heuristic “time saved” — surfaced in UI as an estimate, not measured screen time.
enum RespiteStatsEstimates {
    static let minutesPerShieldInteraction: Int = 3
    static let minutesPerRegulationSession: Int = 12
    static let minutesPerTikTokIntentPass: Int = 2
}

struct RespiteChartPoint: Identifiable {
    let date: Date
    let interruptions: Int
    let estimatedMinutesSaved: Int

    var id: Date { date }
}

enum RespiteStatsChartRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case quarter

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .today: return "Today"
        case .week: return "7D"
        case .month: return "30D"
        case .quarter: return "90D"
        }
    }

    /// Number of calendar days ending today (inclusive).
    var inclusiveDayCount: Int {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

@MainActor
final class RespiteStatsStore: ObservableObject {
    static let shared = RespiteStatsStore()

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let calendar = Calendar.current

    private init() {
        defaults = UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
    }

    // MARK: - Recording (main app)

    func recordRegulationSessionCompleted() {
        mutateDay { aggregate in
            aggregate.regulationSessions += 1
        }
    }

    func recordTikTokIntentPass() {
        mutateDay { aggregate in
            aggregate.tikTokIntentPasses += 1
        }
    }

    // MARK: - Reads

    func todaySummary(now: Date = .now) -> (interruptions: Int, sessions: Int, estimatedMinutesSaved: Int) {
        let key = Self.dayKey(for: now, calendar: calendar)
        let agg = loadAggregatesLocked()[key] ?? RespiteDayAggregate()
        let minutes = estimatedMinutes(for: agg)
        return (agg.shieldInteractions, agg.regulationSessions, minutes)
    }

    func aggregate(forDayContaining date: Date) -> RespiteDayAggregate {
        let key = Self.dayKey(for: date, calendar: calendar)
        return loadAggregatesLocked()[key] ?? RespiteDayAggregate()
    }

    func chartPoints(for range: RespiteStatsChartRange, now: Date = .now) -> [RespiteChartPoint] {
        switch range {
        case .today:
            return hourlyChartPoints(now: now)
        case .week, .month, .quarter:
            return dailyChartPoints(inclusiveDayCount: range.inclusiveDayCount, now: now)
        }
    }

    /// Call when returning to foreground so UI refreshes after extension writes.
    func reloadFromDisk() {
        objectWillChange.send()
    }

    // MARK: - Private

    private func mutateDay(_ body: (inout RespiteDayAggregate) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var map = loadAggregatesUnsafe()
        let key = Self.dayKey(for: Date(), calendar: calendar)
        var aggregate = map[key] ?? RespiteDayAggregate()
        body(&aggregate)
        map[key] = aggregate
        saveAggregatesUnsafe(map)
        objectWillChange.send()
    }

    private func loadAggregatesLocked() -> [String: RespiteDayAggregate] {
        lock.lock()
        defer { lock.unlock() }
        return loadAggregatesUnsafe()
    }

    private func loadAggregatesUnsafe() -> [String: RespiteDayAggregate] {
        guard let data = defaults.data(forKey: RespiteStatsUserDefaultsKey.dailyAggregatesJSON),
              let decoded = try? decoder.decode([String: RespiteDayAggregate].self, from: data)
        else { return [:] }
        return decoded
    }

    private func saveAggregatesUnsafe(_ map: [String: RespiteDayAggregate]) {
        guard let data = try? encoder.encode(map) else { return }
        defaults.set(data, forKey: RespiteStatsUserDefaultsKey.dailyAggregatesJSON)
    }

    private func loadTodayHourlyUnsafe() -> RespiteTodayHourly {
        guard let data = defaults.data(forKey: RespiteStatsUserDefaultsKey.todayHourlyJSON),
              let decoded = try? decoder.decode(RespiteTodayHourly.self, from: data)
        else {
            return RespiteTodayHourly(dayKey: "", shieldCounts: Array(repeating: 0, count: 24))
        }
        if decoded.shieldCounts.count != 24 {
            return RespiteTodayHourly(dayKey: decoded.dayKey, shieldCounts: Array(repeating: 0, count: 24))
        }
        return decoded
    }

    private func hourlyChartPoints(now: Date) -> [RespiteChartPoint] {
        lock.lock()
        defer { lock.unlock() }
        let todayKey = Self.dayKey(for: now, calendar: calendar)
        var hourly = loadTodayHourlyUnsafe()
        if hourly.dayKey != todayKey {
            hourly = RespiteTodayHourly(dayKey: todayKey, shieldCounts: Array(repeating: 0, count: 24))
        }
        let map = loadAggregatesUnsafe()
        let todayAgg = map[todayKey] ?? RespiteDayAggregate()
        let hourlyTotal = hourly.shieldCounts.reduce(0, +)
        let minutesPerShield = RespiteStatsEstimates.minutesPerShieldInteraction
        let flatExtras = todayAgg.regulationSessions * RespiteStatsEstimates.minutesPerRegulationSession
            + todayAgg.tikTokIntentPasses * RespiteStatsEstimates.minutesPerTikTokIntentPass

        var cumulativeInterruptions = 0
        var points: [RespiteChartPoint] = []
        for hour in 0 ..< 24 {
            let count = hourly.shieldCounts[hour]
            cumulativeInterruptions += count
            let shieldMinutesSoFar = cumulativeInterruptions * minutesPerShield
            let cumulativeMinutes = shieldMinutesSoFar + flatExtras
            guard let bucketDate = calendar.date(bySettingHour: hour, minute: 59, second: 0, of: now) else { continue }
            points.append(RespiteChartPoint(date: bucketDate, interruptions: cumulativeInterruptions, estimatedMinutesSaved: cumulativeMinutes))
        }
        if hourlyTotal == 0, todayAgg.shieldInteractions > 0 {
            return syntheticTodayPointsFromDailyAggregate(todayAgg: todayAgg, now: now)
        }
        return points
    }

    /// When hourly buckets are empty but the daily aggregate has shield events (e.g. before hourly sync), draw a flat cumulative line.
    private func syntheticTodayPointsFromDailyAggregate(todayAgg: RespiteDayAggregate, now: Date) -> [RespiteChartPoint] {
        let total = todayAgg.shieldInteractions
        let shieldMinutes = total * RespiteStatsEstimates.minutesPerShieldInteraction
        let flatExtras = todayAgg.regulationSessions * RespiteStatsEstimates.minutesPerRegulationSession
            + todayAgg.tikTokIntentPasses * RespiteStatsEstimates.minutesPerTikTokIntentPass
        let cumulativeMinutes = shieldMinutes + flatExtras
        var points: [RespiteChartPoint] = []
        for hour in 0 ..< 24 {
            guard let bucketDate = calendar.date(bySettingHour: hour, minute: 59, second: 0, of: now) else { continue }
            points.append(RespiteChartPoint(date: bucketDate, interruptions: total, estimatedMinutesSaved: cumulativeMinutes))
        }
        return points
    }

    private func dailyChartPoints(inclusiveDayCount: Int, now: Date) -> [RespiteChartPoint] {
        lock.lock()
        defer { lock.unlock() }
        let map = loadAggregatesUnsafe()
        guard let startDay = calendar.date(byAdding: .day, value: -(inclusiveDayCount - 1), to: calendar.startOfDay(for: now)) else {
            return []
        }
        var cumulativeInterruptions = 0
        var cumulativeMinutes = 0
        var points: [RespiteChartPoint] = []
        for offset in 0 ..< inclusiveDayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            let key = Self.dayKey(for: day, calendar: calendar)
            let agg = map[key] ?? RespiteDayAggregate()
            cumulativeInterruptions += agg.shieldInteractions
            cumulativeMinutes += estimatedMinutes(for: agg)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: day)?.addingTimeInterval(-1) ?? day
            points.append(RespiteChartPoint(date: endOfDay, interruptions: cumulativeInterruptions, estimatedMinutesSaved: cumulativeMinutes))
        }
        return points
    }

    private func estimatedMinutes(for aggregate: RespiteDayAggregate) -> Int {
        aggregate.shieldInteractions * RespiteStatsEstimates.minutesPerShieldInteraction
            + aggregate.regulationSessions * RespiteStatsEstimates.minutesPerRegulationSession
            + aggregate.tikTokIntentPasses * RespiteStatsEstimates.minutesPerTikTokIntentPass
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0
        let m = c.month ?? 0
        let d = c.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
