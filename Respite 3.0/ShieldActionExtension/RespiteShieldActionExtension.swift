import Foundation
import ManagedSettings
import UIKit

// MARK: - Stats (must stay in sync with `RespiteStatsStore` + `RespiteStatsUserDefaultsKey` in the main app)

private enum RespiteStatsShieldKeys {
    static let suite = "group.com.stormforge.Respite-3-0"
    static let dailyAggregatesJSON = "respite.stats.dailyAggregates"
    static let todayHourlyJSON = "respite.stats.todayHourly"
}

private struct RespiteDayAggregateShield: Codable {
    var shieldInteractions: Int
    var regulationSessions: Int
    var tikTokIntentPasses: Int
}

private struct RespiteTodayHourlyShield: Codable {
    var dayKey: String
    var shieldCounts: [Int]
}

private enum RespiteStatsShieldRecorder {
    nonisolated static func recordShieldInteraction() {
        let suite = RespiteStatsShieldKeys.suite
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        let calendar = Calendar.current
        let now = Date()
        let dayKey = dayKeyString(for: now, calendar: calendar)
        let hour = calendar.component(.hour, from: now)

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        var aggregates: [String: RespiteDayAggregateShield] = [:]
        if let data = defaults.data(forKey: RespiteStatsShieldKeys.dailyAggregatesJSON),
           let decoded = try? decoder.decode([String: RespiteDayAggregateShield].self, from: data)
        {
            aggregates = decoded
        }
        var day = aggregates[dayKey] ?? RespiteDayAggregateShield(shieldInteractions: 0, regulationSessions: 0, tikTokIntentPasses: 0)
        day.shieldInteractions += 1
        aggregates[dayKey] = day
        if let aggData = try? encoder.encode(aggregates) {
            defaults.set(aggData, forKey: RespiteStatsShieldKeys.dailyAggregatesJSON)
        }

        var hourly: RespiteTodayHourlyShield
        if let hData = defaults.data(forKey: RespiteStatsShieldKeys.todayHourlyJSON),
           let decoded = try? decoder.decode(RespiteTodayHourlyShield.self, from: hData),
           decoded.shieldCounts.count == 24
        {
            hourly = decoded
        } else {
            hourly = RespiteTodayHourlyShield(dayKey: "", shieldCounts: Array(repeating: 0, count: 24))
        }
        if hourly.dayKey != dayKey {
            hourly = RespiteTodayHourlyShield(dayKey: dayKey, shieldCounts: Array(repeating: 0, count: 24))
        }
        hourly.shieldCounts[hour] += 1
        if let hOut = try? encoder.encode(hourly) {
            defaults.set(hOut, forKey: RespiteStatsShieldKeys.todayHourlyJSON)
        }
    }

    nonisolated private static func dayKeyString(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0
        let m = c.month ?? 0
        let d = c.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

final class RespiteShieldActionExtension: ShieldActionDelegate {
    nonisolated override init() {
        super.init()
    }

    nonisolated override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let path: String
        switch action {
        case .primaryButtonPressed:
            path = "puzzle"
        case .secondaryButtonPressed:
            path = "breathwork"
        @unknown default:
            completionHandler(.close)
            return
        }

        guard let url = URL(string: "regulate://\(path)") else {
            completionHandler(.close)
            return
        }

        RespiteStatsShieldRecorder.recordShieldInteraction()

        openURL(url) {
            completionHandler(.close)
        }
    }

    /// `UIApplication.shared` is unavailable to Shield Action extensions; use the shared application handle.
    nonisolated private func openURL(_ url: URL, completion: @escaping () -> Void) {
        guard
            let app = UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication
        else {
            completion()
            return
        }
        app.open(url, options: [:], completionHandler: { _ in
            completion()
        })
    }
}
