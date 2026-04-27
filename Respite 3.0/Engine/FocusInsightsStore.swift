import Foundation

struct FocusSessionReview: Codable {
    let sessionID: UUID
    let createdAt: Date
    let whatWorked: String
    let distraction: String
    let nextCommitment: String
}

struct FocusPlannerRecommendation {
    let focusMinutes: Int
    let breakMinutes: Int
    let protocolKey: String
    let rationale: String
}

enum FocusInsightsStore {
    private static let reviewMapKey = "study.reviews.map"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: RegulationAppGroup.id) ?? .standard
    }

    static func saveReview(for sessionID: UUID, whatWorked: String, distraction: String, nextCommitment: String) {
        let review = FocusSessionReview(
            sessionID: sessionID,
            createdAt: .now,
            whatWorked: whatWorked.trimmingCharacters(in: .whitespacesAndNewlines),
            distraction: distraction.trimmingCharacters(in: .whitespacesAndNewlines),
            nextCommitment: nextCommitment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard review.isMeaningful else { return }
        var map = reviewMap()
        map[sessionID.uuidString] = review
        saveReviewMap(map)
    }

    static func review(for sessionID: UUID) -> FocusSessionReview? {
        reviewMap()[sessionID.uuidString]
    }

    static func qualityScore(for summary: StudyProgressStore.FocusSessionSummary) -> Int {
        let completion = Double(summary.completedMinutes) / Double(max(1, summary.plannedMinutes))
        var score = Int((completion * 72.0).rounded())

        if summary.endedManually {
            score -= 18
        } else {
            score += 10
        }

        if !summary.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 8
        }

        if let review = review(for: summary.id), review.isMeaningful {
            score += 10
        }

        return min(100, max(0, score))
    }

    static func averageQuality(days: Int = 7) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -max(1, days), to: .now) ?? .now
        let sessions = StudyProgressStore.recentSessions(limit: 200).filter { $0.endedAt >= cutoff }
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { partial, session in
            partial + qualityScore(for: session)
        }
        return Int((Double(total) / Double(sessions.count)).rounded())
    }

    static func plannerRecommendation() -> FocusPlannerRecommendation {
        let sessions = StudyProgressStore.recentSessions(limit: 30)
        guard !sessions.isEmpty else {
            return FocusPlannerRecommendation(
                focusMinutes: 25,
                breakMinutes: 5,
                protocolKey: "steady",
                rationale: "Start with a steady baseline, then adapt from your first week."
            )
        }

        let avgCompletion = sessions.reduce(0.0) { partial, item in
            partial + Double(item.completedMinutes) / Double(max(1, item.plannedMinutes))
        } / Double(sessions.count)

        let manualRate = Double(sessions.filter(\.endedManually).count) / Double(max(1, sessions.count))
        let avgPlanned = sessions.reduce(0) { $0 + $1.plannedMinutes } / max(1, sessions.count)

        if avgCompletion < 0.6 || manualRate > 0.45 {
            return FocusPlannerRecommendation(
                focusMinutes: 20,
                breakMinutes: 5,
                protocolKey: "recovery",
                rationale: "Shorter blocks improve consistency while you rebuild momentum."
            )
        }

        if avgCompletion > 0.85 && manualRate < 0.2 {
            let upgradedFocus = min(60, max(35, avgPlanned + 5))
            return FocusPlannerRecommendation(
                focusMinutes: upgradedFocus,
                breakMinutes: 10,
                protocolKey: "deep",
                rationale: "You finish most sessions. You are ready for deeper blocks."
            )
        }

        return FocusPlannerRecommendation(
            focusMinutes: max(25, min(45, avgPlanned)),
            breakMinutes: 8,
            protocolKey: "steady",
            rationale: "Balanced plan based on your recent completion pattern."
        )
    }

    private static func reviewMap() -> [String: FocusSessionReview] {
        guard let data = defaults.data(forKey: reviewMapKey),
              let map = try? JSONDecoder().decode([String: FocusSessionReview].self, from: data)
        else {
            return [:]
        }
        return map
    }

    private static func saveReviewMap(_ map: [String: FocusSessionReview]) {
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: reviewMapKey)
        }
    }
}

private extension FocusSessionReview {
    var isMeaningful: Bool {
        !whatWorked.isEmpty || !distraction.isEmpty || !nextCommitment.isEmpty
    }
}
