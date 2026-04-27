import WidgetKit
import SwiftUI

private enum WidgetDefaults {
    static let appGroupID = "group.com.stormforge.Respite-3-0"
    static let studyFocusMinutesKey = "study.progress.focusMinutes"
    static let sessionHistoryKey = "study.progress.sessionHistory"
    static let streakGoalKey = "regulation.streakGoalMinutes"
    static let colorIntensityKey = "dev.ui.colorIntensity"

    static func clampedIntensity(from defaults: UserDefaults) -> Double {
        let raw = defaults.object(forKey: colorIntensityKey) as? Double ?? 0.85
        return min(1.40, max(0.35, raw))
    }

    static func progressTint(intensity: Double) -> Color {
        let normalized = (intensity - 0.35) / (1.40 - 0.35)
        let safe = min(1.0, max(0.0, normalized))
        return Color(
            red: 0.30 + (0.12 * safe),
            green: 0.64 + (0.18 * safe),
            blue: 0.50 + (0.20 * safe)
        )
    }
}

private struct WidgetSessionSummary: Codable {
    let endedAt: Date
    let endedManually: Bool
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FocusWidgetEntry {
        FocusWidgetEntry(
            date: .now,
            configuration: ConfigurationAppIntent(),
            todayFocusMinutes: 32,
            streakGoalMinutes: 45,
            manualEndsToday: 1,
            quote: "One clear block now protects tomorrow.",
            colorIntensity: 0.85
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> FocusWidgetEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<FocusWidgetEntry> {
        let current = makeEntry(configuration: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: .now) ?? .now.addingTimeInterval(300)
        return Timeline(entries: [current], policy: .after(next))
    }

    private func makeEntry(configuration: ConfigurationAppIntent) -> FocusWidgetEntry {
        let defaults = UserDefaults(suiteName: WidgetDefaults.appGroupID) ?? .standard
        let focusMinutes = defaults.integer(forKey: WidgetDefaults.studyFocusMinutesKey)

        let goalRaw = defaults.integer(forKey: WidgetDefaults.streakGoalKey)
        let streakGoal = goalRaw > 0 ? goalRaw : 30

        let manualEnds = loadTodayManualEnds(defaults: defaults)
        return FocusWidgetEntry(
            date: .now,
            configuration: configuration,
            todayFocusMinutes: focusMinutes,
            streakGoalMinutes: streakGoal,
            manualEndsToday: manualEnds,
            quote: quoteForToday(),
            colorIntensity: WidgetDefaults.clampedIntensity(from: defaults)
        )
    }

    private func loadTodayManualEnds(defaults: UserDefaults) -> Int {
        guard
            let data = defaults.data(forKey: WidgetDefaults.sessionHistoryKey),
            let decoded = try? JSONDecoder().decode([WidgetSessionSummary].self, from: data)
        else {
            return 0
        }

        return decoded.filter { summary in
            Calendar.current.isDateInToday(summary.endedAt) && summary.endedManually
        }.count
    }

    private func quoteForToday() -> String {
        let quotes = [
            "One clear block now protects tomorrow.",
            "Less switching, more progress.",
            "Your consistency compounds quietly.",
            "Protect your attention first."
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return quotes[day % quotes.count]
    }
}

struct FocusWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let todayFocusMinutes: Int
    let streakGoalMinutes: Int
    let manualEndsToday: Int
    let quote: String
    let colorIntensity: Double

    var progress: Double {
        min(1.0, Double(todayFocusMinutes) / Double(max(1, streakGoalMinutes)))
    }

    var progressTint: Color {
        WidgetDefaults.progressTint(intensity: colorIntensity)
    }
}

struct StudyLiveWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Study momentum")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(entry.todayFocusMinutes)m")
                    .font(.title2.weight(.bold))
                Text("of \(entry.streakGoalMinutes)m")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: entry.progress)
                .tint(entry.progressTint)

            Text(entry.progress >= 1 ? "Goal achieved today" : "\(Int(entry.progress * 100))% to daily goal")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if entry.manualEndsToday > 0 {
                Text("\(entry.manualEndsToday) manual end\(entry.manualEndsToday == 1 ? "" : "s") today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Text(entry.quote)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

struct StudyLiveWidget: Widget {
    let kind: String = "StudyLiveWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            StudyLiveWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Study Momentum")
        .description("Shows today focus progress, manual-end pressure, and a short cue.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    StudyLiveWidget()
} timeline: {
    FocusWidgetEntry(
        date: .now,
        configuration: ConfigurationAppIntent(),
        todayFocusMinutes: 28,
        streakGoalMinutes: 40,
        manualEndsToday: 1,
        quote: "Less switching, more progress.",
        colorIntensity: 0.85
    )
}
