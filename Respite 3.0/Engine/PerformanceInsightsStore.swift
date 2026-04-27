import Foundation

enum FocusPlanPreset: String, CaseIterable, Identifiable {
    case balanced
    case deepWork
    case gentleReset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: return "Balanced"
        case .deepWork: return "Deep Work"
        case .gentleReset: return "Gentle Reset"
        }
    }

    var summary: String {
        switch self {
        case .balanced:
            return "Steady daily limits with moderate grace and streak goals."
        case .deepWork:
            return "Longer focus blocks, tighter limits, higher streak target."
        case .gentleReset:
            return "Softer guardrails for recovery days and restart weeks."
        }
    }

    var recommendedSettings: (pauseAfterMinutes: Int, graceMinutes: Int, streakGoalMinutes: Int, idleMinutes: Int) {
        switch self {
        case .balanced:
            return (pauseAfterMinutes: 15, graceMinutes: 5, streakGoalMinutes: 30, idleMinutes: 30)
        case .deepWork:
            return (pauseAfterMinutes: 10, graceMinutes: 3, streakGoalMinutes: 45, idleMinutes: 20)
        case .gentleReset:
            return (pauseAfterMinutes: 20, graceMinutes: 8, streakGoalMinutes: 20, idleMinutes: 40)
        }
    }
}

struct RecoveryRiskWindow: Identifiable {
    let id = UUID()
    let hour: Int
    let incidents: Int

    var title: String {
        let period = hour >= 12 ? "PM" : "AM"
        let normalizedHour = hour % 12 == 0 ? 12 : hour % 12
        return "\(normalizedHour)\(period)"
    }
}

struct RecoveryInsightsSnapshot {
    let score: Int
    let weeklyAverageMinutes: Int
    let weeklyTrendMinutes: Int
    let consistencyRate: Double
    let manualEndRate: Double
    let reflectionDaysRate: Double
    let recommendedIntervention: RegulationChallenge
    let riskWindows: [RecoveryRiskWindow]

    var scoreLabel: String {
        switch score {
        case 85...100: return "Strong"
        case 70...84: return "Stable"
        case 50...69: return "Building"
        default: return "Recovery mode"
        }
    }
}

enum RecoveryInsightsStore {
    private static let selectedPlanKey = "insights.focusPlan.selected"
    private static let antiRelapseEnabledKey = "insights.antiRelapse.enabled"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
    }

    static func selectedPlan() -> FocusPlanPreset {
        guard
            let raw = defaults.string(forKey: selectedPlanKey),
            let plan = FocusPlanPreset(rawValue: raw)
        else {
            return .balanced
        }
        return plan
    }

    static func setSelectedPlan(_ plan: FocusPlanPreset) {
        defaults.set(plan.rawValue, forKey: selectedPlanKey)
    }

    static func antiRelapseEnabled() -> Bool {
        if defaults.object(forKey: antiRelapseEnabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: antiRelapseEnabledKey)
    }

    static func setAntiRelapseEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: antiRelapseEnabledKey)
    }

    static func applyPlan(_ plan: FocusPlanPreset, settings: RegulationSettingsStore) {
        let values = plan.recommendedSettings
        settings.pauseThresholdMinutes = values.pauseAfterMinutes
        settings.gracePeriodMinutes = values.graceMinutes
        settings.streakGoalMinutes = values.streakGoalMinutes
        settings.tiktokIdleMinutesAfterExit = values.idleMinutes
        setSelectedPlan(plan)
    }

    static func currentSnapshot(now: Date = .now) -> RecoveryInsightsSnapshot {
        let weeklyAverage = Int(DailyProgressStore.averageDailyMinutes(days: 7).rounded())
        let trend = DailyProgressStore.weeklyTrendDeltaMinutes()

        let history = DailyProgressStore.recentHistory(days: 7)
        let activeDays = history.filter { $0.minutes > 0 }.count
        let consistencyRate = history.isEmpty ? 0 : Double(activeDays) / Double(history.count)

        let sessions = StudyProgressStore.recentSessions(limit: 60)
        let manualEnded = sessions.filter(\.endedManually).count
        let manualEndRate = sessions.isEmpty ? 0 : Double(manualEnded) / Double(sessions.count)

        let reflectionDaysRate = recentReflectionDaysRate(now: now)
        let recommendation = recommendedIntervention(manualEndRate: manualEndRate, reflectionRate: reflectionDaysRate, trend: trend)
        let windows = antiRelapseEnabled() ? topRiskWindows(from: sessions) : []

        let score = computeScore(
            weeklyAverage: weeklyAverage,
            trend: trend,
            consistencyRate: consistencyRate,
            manualEndRate: manualEndRate,
            reflectionDaysRate: reflectionDaysRate
        )

        return RecoveryInsightsSnapshot(
            score: score,
            weeklyAverageMinutes: weeklyAverage,
            weeklyTrendMinutes: trend,
            consistencyRate: consistencyRate,
            manualEndRate: manualEndRate,
            reflectionDaysRate: reflectionDaysRate,
            recommendedIntervention: recommendation,
            riskWindows: windows
        )
    }

    static func isHighRiskHour(_ hour: Int, now: Date = .now) -> Bool {
        let windows = topRiskWindows(from: StudyProgressStore.recentSessions(limit: 120))
        let currentHour = (0...23).contains(hour) ? hour : Calendar.current.component(.hour, from: now)
        return windows.contains(where: { $0.hour == currentHour })
    }

    static func effectiveGraceMinutes(base: Int, now: Date = .now) -> Int {
        guard antiRelapseEnabled() else { return base }
        let hour = Calendar.current.component(.hour, from: now)
        guard isHighRiskHour(hour, now: now) else { return base }
        let tightened = Int((Double(base) * 0.6).rounded())
        return max(1, min(base, tightened))
    }

    private static func recentReflectionDaysRate(now: Date) -> Double {
        let calendar = Calendar.current
        let entries = ReflectionStore.allEntries()
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let uniqueDays = Set(entries.filter { $0.createdAt >= cutoff }.map { calendar.startOfDay(for: $0.createdAt) })
        return min(1.0, Double(uniqueDays.count) / 7.0)
    }

    private static func recommendedIntervention(manualEndRate: Double, reflectionRate: Double, trend: Int) -> RegulationChallenge {
        if manualEndRate >= 0.45 { return .breathwork }
        if trend < 0 || reflectionRate < 0.2 { return .puzzle }
        return manualEndRate > 0.25 ? .breathwork : .puzzle
    }

    private static func topRiskWindows(from sessions: [StudyProgressStore.FocusSessionSummary]) -> [RecoveryRiskWindow] {
        guard !sessions.isEmpty else { return [] }
        var bucket: [Int: Int] = [:]
        for session in sessions where session.endedManually {
            let hour = Calendar.current.component(.hour, from: session.endedAt)
            bucket[hour, default: 0] += 1
        }
        return bucket
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(3)
            .map { RecoveryRiskWindow(hour: $0.key, incidents: $0.value) }
    }

    private static func computeScore(
        weeklyAverage: Int,
        trend: Int,
        consistencyRate: Double,
        manualEndRate: Double,
        reflectionDaysRate: Double
    ) -> Int {
        var score = 50
        score += min(20, max(0, weeklyAverage / 2))
        score += min(10, max(-10, trend))
        score += Int((consistencyRate - 0.5) * 30.0)
        score -= Int(manualEndRate * 20.0)
        score += Int(reflectionDaysRate * 10.0)
        return min(100, max(0, score))
    }
}
