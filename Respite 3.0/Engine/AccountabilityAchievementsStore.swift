import Foundation

enum AchievementBadge: String, CaseIterable, Identifiable {
    case firstFocusBlock
    case streakStarter
    case weekProtector
    case reflectionBuilder
    case deepWorkChampion
    case hundredMinutesDay
    case sevenDayReflectionStreak
    case noManualEndsDay
    case consistencyKeeper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstFocusBlock: return "First Focus Block"
        case .streakStarter: return "Streak Starter"
        case .weekProtector: return "Week Protector"
        case .reflectionBuilder: return "Reflection Builder"
        case .deepWorkChampion: return "Deep Work Champion"
        case .hundredMinutesDay: return "Century Day"
        case .sevenDayReflectionStreak: return "Reflection Week"
        case .noManualEndsDay: return "Clean Finish"
        case .consistencyKeeper: return "Consistency Keeper"
        }
    }

    var subtitle: String {
        switch self {
        case .firstFocusBlock:
            return "Complete your first focus session"
        case .streakStarter:
            return "Hit your streak goal for 3 straight days"
        case .weekProtector:
            return "Save at least 120 minutes in 7 days"
        case .reflectionBuilder:
            return "Write reflections on 4 different days"
        case .deepWorkChampion:
            return "Complete 10 full focus sessions"
        case .hundredMinutesDay:
            return "Save 100+ minutes in a single day"
        case .sevenDayReflectionStreak:
            return "Write reflections for 7 days in a row"
        case .noManualEndsDay:
            return "Finish 3 sessions in one day without manual end"
        case .consistencyKeeper:
            return "Reach 70%+ quality score over the last 7 days"
        }
    }

    var icon: String {
        switch self {
        case .firstFocusBlock: return "flag.fill"
        case .streakStarter: return "flame.fill"
        case .weekProtector: return "shield.lefthalf.filled"
        case .reflectionBuilder: return "book.fill"
        case .deepWorkChampion: return "brain.head.profile"
        case .hundredMinutesDay: return "clock.badge.checkmark"
        case .sevenDayReflectionStreak: return "calendar.badge.checkmark"
        case .noManualEndsDay: return "checkmark.seal.fill"
        case .consistencyKeeper: return "chart.line.uptrend.xyaxis.circle.fill"
        }
    }
}

struct AchievementSnapshot {
    let unlocked: [AchievementBadge]
    let nextMilestone: String
}

enum AchievementsStore {
    static func snapshot(streakGoalMinutes: Int) -> AchievementSnapshot {
        let badges = AchievementBadge.allCases.filter { isUnlocked($0, streakGoalMinutes: streakGoalMinutes) }
        return AchievementSnapshot(
            unlocked: badges,
            nextMilestone: nextMilestoneDescription(streakGoalMinutes: streakGoalMinutes)
        )
    }

    private static func isUnlocked(_ badge: AchievementBadge, streakGoalMinutes: Int) -> Bool {
        switch badge {
        case .firstFocusBlock:
            return !StudyProgressStore.recentSessions(limit: 1).isEmpty
        case .streakStarter:
            return DailyProgressStore.currentStreak(goalMinutes: max(1, streakGoalMinutes)) >= 3
        case .weekProtector:
            return DailyProgressStore.recentHistory(days: 7).map(\.minutes).reduce(0, +) >= 120
        case .reflectionBuilder:
            let recent = ReflectionStore.allEntries()
            let uniqueDays = Set(recent.map { Calendar.current.startOfDay(for: $0.createdAt) })
            return uniqueDays.count >= 4
        case .deepWorkChampion:
            let completed = StudyProgressStore.recentSessions(limit: 200).filter { !$0.endedManually }
            return completed.count >= 10
        case .hundredMinutesDay:
            return DailyProgressStore.minutesSavedToday() >= 100
        case .sevenDayReflectionStreak:
            return reflectionStreakDays() >= 7
        case .noManualEndsDay:
            let todaySessions = StudyProgressStore.recentSessions(limit: 50).filter {
                Calendar.current.isDateInToday($0.endedAt)
            }
            let completedToday = todaySessions.filter { !$0.endedManually }
            return completedToday.count >= 3 && completedToday.count == todaySessions.count
        case .consistencyKeeper:
            return FocusInsightsStore.averageQuality(days: 7) >= 70
        }
    }

    private static func reflectionStreakDays() -> Int {
        let entries = ReflectionStore.allEntries()
        let byDay = Set(entries.map { Calendar.current.startOfDay(for: $0.createdAt) })
        var streak = 0
        var cursor = Calendar.current.startOfDay(for: .now)
        while byDay.contains(cursor) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private static func nextMilestoneDescription(streakGoalMinutes: Int) -> String {
        let streak = DailyProgressStore.currentStreak(goalMinutes: max(1, streakGoalMinutes))
        if streak < 3 {
            return "\(max(0, 3 - streak)) more day(s) to unlock Streak Starter"
        }

        let weekTotal = DailyProgressStore.recentHistory(days: 7).map(\.minutes).reduce(0, +)
        if weekTotal < 120 {
            return "\(max(0, 120 - weekTotal))m more this week to unlock Week Protector"
        }

        let completed = StudyProgressStore.recentSessions(limit: 200).filter { !$0.endedManually }.count
        if completed < 10 {
            return "\(max(0, 10 - completed)) more completed session(s) to unlock Deep Work Champion"
        }

        return "All core milestones unlocked"
    }
}
