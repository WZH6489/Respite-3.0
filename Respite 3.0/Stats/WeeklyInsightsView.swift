import SwiftUI

enum WeeklyInsightsMode {
    case recovery
    case focusQuality
}

struct WeeklyInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let mode: WeeklyInsightsMode
    private let snapshot = RecoveryInsightsStore.currentSnapshot()
    private let weeklyHistory = DailyProgressStore.recentHistory(days: 7)
    private let recentSessions = StudyProgressStore.recentSessions(limit: 200)

    init(mode: WeeklyInsightsMode = .recovery) {
        self.mode = mode
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    scoreCard
                    scoreExplanationCard
                    trendCard
                    consistencyCard
                    if mode == .recovery {
                        relapseWindowCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(RespiteDynamicBackground().ignoresSafeArea())
            .navigationTitle(mode == .recovery ? "Weekly insights" : "Focus quality insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(mode == .recovery ? "Recovery score" : "Focus quality")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(scoreLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(trackColor))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(headlineScore)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("/ 100")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(trackColor)
                    Capsule()
                        .fill(RespiteTheme.duskBlue.opacity(0.95))
                        .frame(width: proxy.size.width * CGFloat(Double(headlineScore) / 100.0))
                }
            }
            .frame(height: 10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .recovery ? "Time saved (last 7 days)" : "Focus quality (last 7 days)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            let points = trendPoints
            let maxValue = max(1, points.map(\.value).max() ?? 1)

            VStack(spacing: 8) {
                ForEach(points, id: \.date) { point in
                    HStack(spacing: 10) {
                        Text(shortWeekday(point.date))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, alignment: .leading)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(trackColor)
                                Capsule()
                                    .fill(RespiteTheme.duskBlue.opacity(0.9))
                                    .frame(width: proxy.size.width * CGFloat(Double(point.value) / Double(maxValue)))
                            }
                        }
                        .frame(height: 8)

                        Text(point.label)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                    .frame(height: 14)
                }
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var scoreExplanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .recovery ? "How recovery score works" : "How focus quality works")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(mode == .recovery
                 ? "Recovery score is a 0-100 signal of attention stability. It combines time saved, week-over-week trend, consistency across days, manual focus exits, and reflection coverage."
                 : "Focus quality is a 0-100 signal of how strong your sessions are. It combines completion quality, manual ends, goal clarity, and post-session reflection coverage.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(mode == .recovery
                 ? "Higher means your focus habits are getting more reliable."
                 : "Higher means your study sessions are more complete, intentional, and consistent.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode == .recovery ? "Behavior quality" : "Session quality")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if mode == .recovery {
                qualityRow(title: "Consistency", value: percent(snapshot.consistencyRate))
                qualityRow(title: "Manual end rate", value: percent(snapshot.manualEndRate))
                qualityRow(title: "Reflection coverage", value: percent(snapshot.reflectionDaysRate))
                qualityRow(title: "Adaptive recommendation", value: snapshot.recommendedIntervention == .breathwork ? "Breathwork" : "Puzzle")
            } else {
                qualityRow(title: "Manual end rate", value: percent(focusManualEndRate))
                qualityRow(title: "Goal clarity", value: percent(goalClarityRate))
                qualityRow(title: "Review coverage", value: percent(reviewCoverageRate))
                qualityRow(title: "Sessions tracked", value: "\(focusWeekSessions.count)")
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var relapseWindowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Anti-relapse windows")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(RecoveryInsightsStore.antiRelapseEnabled() ? "Enabled" : "Disabled")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(RecoveryInsightsStore.antiRelapseEnabled() ? RespiteTheme.pine : .secondary)
            }

            if snapshot.riskWindows.isEmpty {
                Text("No high-risk windows found yet.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snapshot.riskWindows) { window in
                        Text("• \(window.title): \(window.incidents) manual exits")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private func qualityRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    private var trackColor: Color {
        (colorScheme == .dark ? Color.white : Color.black).opacity(0.14)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((min(1.0, max(0.0, value)) * 100).rounded()))%"
    }

    private func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        return formatter.string(from: date)
    }

    private var focusWeekSessions: [StudyProgressStore.FocusSessionSummary] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return recentSessions.filter { $0.endedAt >= cutoff }
    }

    private var focusQualityScore: Int {
        guard !focusWeekSessions.isEmpty else { return 0 }
        let total = focusWeekSessions.reduce(0) { partial, session in
            partial + FocusInsightsStore.qualityScore(for: session)
        }
        return Int((Double(total) / Double(focusWeekSessions.count)).rounded())
    }

    private var focusManualEndRate: Double {
        guard !focusWeekSessions.isEmpty else { return 0 }
        let manual = focusWeekSessions.filter(\.endedManually).count
        return Double(manual) / Double(focusWeekSessions.count)
    }

    private var goalClarityRate: Double {
        guard !focusWeekSessions.isEmpty else { return 0 }
        let withGoal = focusWeekSessions.filter { !$0.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        return Double(withGoal) / Double(focusWeekSessions.count)
    }

    private var reviewCoverageRate: Double {
        guard !focusWeekSessions.isEmpty else { return 0 }
        let withReview = focusWeekSessions.filter { FocusInsightsStore.review(for: $0.id) != nil }.count
        return Double(withReview) / Double(focusWeekSessions.count)
    }

    private var headlineScore: Int {
        mode == .recovery ? snapshot.score : focusQualityScore
    }

    private var scoreLabel: String {
        if mode == .recovery {
            return snapshot.scoreLabel
        }
        switch focusQualityScore {
        case 85...: return "Excellent"
        case 70...: return "Strong"
        case 50...: return "Building"
        default: return "Needs support"
        }
    }

    private var trendPoints: [(date: Date, value: Int, label: String)] {
        if mode == .recovery {
            return weeklyHistory.map { point in
                (date: point.date, value: point.minutes, label: "\(point.minutes)m")
            }
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dates: [Date] = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.reversed()

        return dates.map { date in
            let daySessions = focusWeekSessions.filter { calendar.isDate($0.endedAt, inSameDayAs: date) }
            guard !daySessions.isEmpty else {
                return (date: date, value: 0, label: "0")
            }
            let sum = daySessions.reduce(0) { $0 + FocusInsightsStore.qualityScore(for: $1) }
            let avg = Int((Double(sum) / Double(daySessions.count)).rounded())
            return (date: date, value: avg, label: "\(avg)")
        }
    }
}
